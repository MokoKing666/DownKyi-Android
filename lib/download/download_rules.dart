import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../bili/models.dart';
import '../core/constants.dart';
import '../core/formatter.dart';
import '../core/logger.dart';
import '../data/download_task.dart';

/// 任务跑在哪里（评审第 20 项）。
///
/// 「统一任务界面」的前提是先能说清每条任务的位置——本机、还是 NAS / 电脑上的 aria2。
/// 这里刻意**不新增数据库列**：aria2 的任务一定有 `aria2Gid`，
/// 而「aria2 是不是跑在本机」由 RPC 地址就能判断，加一列反而要和
/// `task_dao` 的版本迁移、`toMap/fromMap` 三处同步维护，收益不成比例。
enum TaskSource {
  /// 内置引擎，本机下载
  local,

  /// 本机跑的 aria2
  aria2Local,

  /// NAS / 电脑上的 aria2
  aria2Remote,
  ;

  String get label => switch (this) {
        TaskSource.local => '本机',
        TaskSource.aria2Local => '本机 Aria2',
        TaskSource.aria2Remote => '远程 Aria2',
      };

  bool get isRemote => this == TaskSource.aria2Remote;
}

class TaskSources {
  TaskSources._();

  /// 判断某条任务跑在哪里。
  /// 判错的后果只是标签不准（不影响任何功能），所以这里用最朴素的方式判断。
  static TaskSource of(DownloadTask task, String aria2RpcUrl) {
    final gid = task.aria2Gid;
    if (gid == null || gid.isEmpty) return TaskSource.local;
    return isLoopback(aria2RpcUrl)
        ? TaskSource.aria2Local
        : TaskSource.aria2Remote;
  }

  /// RPC 地址是不是指向本机
  static bool isLoopback(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    final value = host.toLowerCase();
    if (value.isEmpty) return false;
    return value == 'localhost' ||
        value == '::1' ||
        value.startsWith('127.') ||
        // 0.0.0.0 作为连接目标是「本机所有地址」，多数协议栈会落到 loopback
        value == '0.0.0.0';
  }
}

/// 下载偏好模式（评审第 15 项「智能下载」）。
///
/// 目标是把「4K 到底该配 AVC 还是 AV1」这种问题从用户面前拿走：
/// 用户只需要说「我要画质」还是「我要能播」。
enum PreferenceMode {
  /// 画质优先：能拿多高拿多高
  bestQuality,

  /// 兼容性优先：宁可低一档也要 H.264，老电视/投影/剪辑软件都能吃
  compatibility,

  /// 体积优先：同画质下挑体积最小的编码，实在太大才降档
  smallSize,

  /// 速度优先：最小体积最快下完，容忍降画质
  fastSpeed,
  ;

  String get label => switch (this) {
        PreferenceMode.bestQuality => '画质优先',
        PreferenceMode.compatibility => '兼容性优先',
        PreferenceMode.smallSize => '体积优先',
        PreferenceMode.fastSpeed => '速度优先',
      };

  String get description => switch (this) {
        PreferenceMode.bestQuality => '能拿多高拿多高（8K / 4K / HDR 都优先）',
        PreferenceMode.compatibility => '优先 H.264，老设备与剪辑软件通吃',
        PreferenceMode.smallSize => '尽量不降画质，选体积更小的编码',
        PreferenceMode.fastSpeed => '最快下完，可接受降画质',
      };

  static PreferenceMode fromName(String? name) =>
      PreferenceMode.values.firstWhere(
        (value) => value.name == name,
        orElse: () => PreferenceMode.bestQuality,
      );

  /// 是否允许为了体积/速度牺牲清晰度
  bool get allowsQualityDrop =>
      this == PreferenceMode.fastSpeed || this == PreferenceMode.smallSize;
}

/// 清晰度优先级：从高到低。与 [BiliConst.qualityNames] 的档位一致。
const List<int> kQualityPriority = <int>[
  127, // 8K
  126, // 杜比视界
  125, // HDR
  120, // 4K
  116, // 1080P60
  112, // 1080P+
  80, // 1080P
  74, // 720P60
  64, // 720P
  32, // 480P
  16, // 360P
  6, // 240P
];

/// 体积优先时认为「可以接受」的最低档位。再低就没有下载意义了。
const int kAcceptableQuality = 64; // 720P

/// 智能选档。
///
/// 纯函数，不碰网络也不碰磁盘——这是评审第 15 项里少数**不需要真机就能验证**的部分，
/// 所以刻意把决策逻辑全部集中在这里。
class SmartPicker {
  SmartPicker._();

  /// 画质优先时的编码顺序：HEVC 在同等画质下比 AVC 更省，兼容性又远好于 AV1
  static const List<String> _qualityCodecOrder = <String>['hevc', 'av1', 'avc'];

  /// 兼容性优先：H.264 是唯一能保证「什么设备都能播」的
  static const List<String> _compatCodecOrder = <String>['avc', 'hevc', 'av1'];

  /// 体积 / 速度优先：AV1 > HEVC > AVC
  static const List<String> _sizeCodecOrder = <String>['av1', 'hevc', 'avc'];

  static List<String> codecOrder(PreferenceMode mode) => switch (mode) {
        PreferenceMode.compatibility => _compatCodecOrder,
        PreferenceMode.smallSize || PreferenceMode.fastSpeed => _sizeCodecOrder,
        PreferenceMode.bestQuality => _qualityCodecOrder,
      };

  /// 该清晰度下实际存在的编码（按偏好排序）
  static List<String> codecsOf(
      DashInfo dash, int quality, PreferenceMode mode) {
    final present = <String>{
      for (final stream in dash.videosOf(quality)) stream.codecFamily,
    };
    final order = codecOrder(mode);
    return <String>[
      ...order.where(present.contains),
      ...present.where((value) => !order.contains(value)),
    ];
  }

  /// 选编码。返回 null 表示该清晰度没有可用视频流。
  static String? pickCodec(DashInfo dash, int quality, PreferenceMode mode) {
    final codecs = codecsOf(dash, quality, mode);
    return codecs.isEmpty ? null : codecs.first;
  }

  /// 选清晰度。
  ///
  /// [vipOnly] 是可选的过滤：不传就按「服务端已经按账号权限过滤过」处理
  /// （playurl 返回的 qualityList 本身就是这个账号能拿到的档位）。
  static int pickQuality(
    DashInfo dash,
    PreferenceMode mode, {
    bool Function(int quality)? vipOnly,
  }) {
    final available = kQualityPriority
        .where((quality) => dash.videosOf(quality).isNotEmpty)
        .where((quality) => vipOnly?.call(quality) ?? true)
        .toList();
    if (available.isEmpty) {
      // 兜底：拿服务端给的第一个可用档位
      final list = dash.qualityList;
      return list.isEmpty ? 80 : list.first;
    }

    switch (mode) {
      case PreferenceMode.bestQuality:
        return available.first;

      case PreferenceMode.compatibility:
        // 从上往下找第一个「有 AVC」的档位。找不到就说明最高档只有 HEVC/AV1，
        // 这时候退回最高档（总比什么都不下好），并让调用方提示用户。
        for (final quality in available) {
          if (dash.videosOf(quality).any((s) => s.codecFamily == 'avc')) {
            return quality;
          }
        }
        return available.first;

      case PreferenceMode.smallSize:
        // 不轻易降画质：在「可接受档位」以上挑总体积最小的那一档，
        // 且优先该档里体积最小的编码。
        final acceptable =
            available.where((q) => q >= kAcceptableQuality).toList();
        final pool = acceptable.isEmpty ? available : acceptable;
        var best = pool.first;
        var bestBytes = _bytesOf(dash, best, mode);
        for (final quality in pool) {
          final bytes = _bytesOf(dash, quality, mode);
          if (bytes > 0 && (bestBytes == 0 || bytes < bestBytes)) {
            best = quality;
            bestBytes = bytes;
          }
        }
        return best;

      case PreferenceMode.fastSpeed:
        // 直接挑体积最小的档位，允许降到最低
        var best = available.last;
        var bestBytes = _bytesOf(dash, best, mode);
        for (final quality in available) {
          final bytes = _bytesOf(dash, quality, mode);
          if (bytes > 0 && (bestBytes == 0 || bytes < bestBytes)) {
            best = quality;
            bestBytes = bytes;
          }
        }
        return best;
    }
  }

  /// 选音轨。体积/速度优先时挑最低码率，其余挑最高。
  static int? pickAudioId(DashInfo dash, PreferenceMode mode) {
    final audios = <DashStream>[...dash.audios];
    if (dash.flac != null) audios.add(dash.flac!);
    if (audios.isEmpty) return null;
    audios.sort((a, b) => a.bandwidth.compareTo(b.bandwidth));
    final wantSmallest =
        mode == PreferenceMode.fastSpeed || mode == PreferenceMode.smallSize;
    return wantSmallest ? audios.first.id : audios.last.id;
  }

  /// 该档位下最省体积的流
  static int _bytesOf(DashInfo dash, int quality, PreferenceMode mode) {
    final streams = dash.videosOf(quality);
    if (streams.isEmpty) return 0;
    final codec = pickCodec(dash, quality, mode);
    final picked = dash.pickVideo(quality, codec);
    return picked?.bandwidth ?? streams.first.bandwidth;
  }
}

/// 体积预估（评审第 16 项）。
///
/// DASH 是按需取流，播放地址里没有「文件总长」这种字段，所以只能按
/// 「码率 × 时长」估。B 站返回的 `bandwidth` 是实测平均码率，通常误差在 5% 以内——
/// 对「1.8 GB 还是 850 MB」这种比较完全够用，别拿去当精确的磁盘占用。
class MediaEstimator {
  MediaEstimator._();

  /// bits/s × 毫秒 ÷ 8000 = 字节
  static int bytesOfStream(DashStream? stream, int durationMs) {
    if (stream == null || stream.bandwidth <= 0 || durationMs <= 0) return 0;
    return stream.bandwidth * durationMs ~/ 8000;
  }

  /// 某个清晰度 + 编码下的纯视频体积
  static int videoBytes(
    DashInfo dash,
    int quality,
    String? codec,
    int durationMs,
  ) =>
      bytesOfStream(dash.pickVideo(quality, codec), durationMs);

  /// 音轨体积
  static int audioBytes(DashInfo dash, int? audioId, int durationMs) =>
      bytesOfStream(dash.pickAudio(audioId), durationMs);

  /// 视频 + 音频
  static int totalBytes(
    DashInfo dash, {
    required int quality,
    String? codec,
    int? audioId,
  }) =>
      videoBytes(dash, quality, codec, dash.durationMs) +
      audioBytes(dash, audioId, dash.durationMs);

  /// 给界面用的文案，例如「1080P 高清 · AVC · 约 1.8 GB」
  static String describe(
    DashInfo dash, {
    required int quality,
    String? codec,
    int? audioId,
    bool withAudio = true,
  }) {
    final video = videoBytes(dash, quality, codec, dash.durationMs);
    if (video <= 0) return '体积未知';
    final total =
        withAudio ? video + audioBytes(dash, audioId, dash.durationMs) : video;
    return '约 ${formatBytes(total)}';
  }

  /// 一份可直接铺在选项面板上的清单
  static List<({int quality, String codec, int bytes, String label})> list(
    DashInfo dash,
    PreferenceMode mode, {
    int? audioId,
  }) {
    final rows = <({int quality, String codec, int bytes, String label})>[];
    for (final quality in kQualityPriority) {
      for (final codec in SmartPicker.codecsOf(dash, quality, mode)) {
        final video = videoBytes(dash, quality, codec, dash.durationMs);
        if (video <= 0) continue;
        final total = video + audioBytes(dash, audioId, dash.durationMs);
        rows.add((
          quality: quality,
          codec: codec,
          bytes: total,
          label: '${BiliConst.qualityNames[quality] ?? quality} · '
              '${BiliConst.codecNames.entries.firstWhere((e) => _codecKey(e.key) == codec, orElse: () => const MapEntry(7, 'AVC')).value}',
        ));
      }
    }
    return rows;
  }

  static String _codecKey(int id) => switch (id) {
        12 => 'hevc',
        13 => 'av1',
        _ => 'avc',
      };
}

/// 下载规则模板（评审第 18 项）。
///
/// 存在的理由很实际：用户对「某类内容」的偏好是稳定的——
/// 追更的番剧想存 HEVC + 中文字幕，随手下的教程只要 720P。
/// 每次都从头调一遍清晰度/编码/音轨/字幕，是纯粹的重复劳动。
class DownloadRule {
  DownloadRule({
    required this.id,
    required this.name,
    this.mode = PreferenceMode.bestQuality,
    this.quality,
    this.codec,
    this.audioId,
    this.flags = DownloadFlags.video |
        DownloadFlags.audio |
        DownloadFlags.cover |
        DownloadFlags.danmaku,
    this.danmakuFormat = DanmakuFormat.ass,
    this.subtitleLanguages = const <String>['zh-Hans'],
    this.fileNameTemplate = '{title}',
    this.applyTemplate = false,
  });

  final String id;
  String name;

  /// 智能模式。显式给了 quality/codec 时以显式值为准。
  PreferenceMode mode;

  int? quality;
  String? codec;
  int? audioId;

  int flags;
  DanmakuFormat danmakuFormat;

  /// 要下载哪些语言的字幕（BCP-47，如 zh-Hans / en-US / ja）
  List<String> subtitleLanguages;

  String fileNameTemplate;
  bool applyTemplate;

  bool get wantVideo => flags & DownloadFlags.video != 0;
  bool get wantAudio => flags & DownloadFlags.audio != 0;
  bool get wantCover => flags & DownloadFlags.cover != 0;
  bool get wantDanmaku => flags & DownloadFlags.danmaku != 0;
  bool get wantSubtitle => flags & DownloadFlags.subtitle != 0;

  DownloadRule copyWith({String? name}) => DownloadRule(
        id: id,
        name: name ?? this.name,
        mode: mode,
        quality: quality,
        codec: codec,
        audioId: audioId,
        flags: flags,
        danmakuFormat: danmakuFormat,
        subtitleLanguages: <String>[...subtitleLanguages],
        fileNameTemplate: fileNameTemplate,
        applyTemplate: applyTemplate,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'mode': mode.name,
        'quality': quality,
        'codec': codec,
        'audioId': audioId,
        'flags': flags,
        'danmaku': danmakuFormat.name,
        'subs': subtitleLanguages,
        'template': fileNameTemplate,
        'applyTemplate': applyTemplate,
      };

  static DownloadRule fromJson(Map<String, Object?> json) => DownloadRule(
        id: asString(
            json['id'], DateTime.now().microsecondsSinceEpoch.toString()),
        name: asString(json['name'], '未命名规则'),
        mode: PreferenceMode.fromName(asString(json['mode'])),
        quality: json['quality'] == null ? null : asInt(json['quality']),
        codec: json['codec'] == null ? null : asString(json['codec']),
        audioId: json['audioId'] == null ? null : asInt(json['audioId']),
        flags: asInt(json['flags'], DownloadFlags.video | DownloadFlags.audio),
        danmakuFormat: DanmakuFormat.values.firstWhere(
          (value) => value.name == asString(json['danmaku']),
          orElse: () => DanmakuFormat.ass,
        ),
        subtitleLanguages: (json['subs'] as List?)
                ?.map((item) => '$item')
                .toList(growable: false) ??
            const <String>['zh-Hans'],
        fileNameTemplate: asString(json['template'], '{title}'),
        applyTemplate: json['applyTemplate'] == true,
      );

  /// 内置两套常用规则。用户的第一次下载就有可用模板，不用从空白开始配。
  static List<DownloadRule> defaults() => <DownloadRule>[
        DownloadRule(
          id: 'builtin_archive',
          name: '高画质归档',
          mode: PreferenceMode.bestQuality,
          flags: DownloadFlags.video |
              DownloadFlags.audio |
              DownloadFlags.cover |
              DownloadFlags.danmaku |
              DownloadFlags.subtitle,
          subtitleLanguages: const <String>['zh-Hans'],
          fileNameTemplate: '{owner}/{title} [{bvid}]',
          applyTemplate: true,
        ),
        DownloadRule(
          id: 'builtin_compat',
          name: '兼容优先',
          mode: PreferenceMode.compatibility,
          flags: DownloadFlags.video | DownloadFlags.audio,
          danmakuFormat: DanmakuFormat.xml,
          subtitleLanguages: const <String>['zh-Hans'],
        ),
      ];
}

/// 规则的持久化（SharedPreferences，JSON 数组）。
class RuleStore {
  RuleStore._();

  static const String _key = 'download_rules';
  static const String defaultRuleId = 'builtin_archive';

  static List<DownloadRule> _rules = DownloadRule.defaults();
  static String _activeId = defaultRuleId;

  static List<DownloadRule> get rules => List.unmodifiable(_rules);

  static String get activeId => _activeId;

  static DownloadRule? get active {
    for (final rule in _rules) {
      if (rule.id == _activeId) return rule;
    }
    return _rules.isEmpty ? null : _rules.first;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          _rules = decoded
              .whereType<Map>()
              .map(
                  (item) => DownloadRule.fromJson(item.cast<String, Object?>()))
              .toList();
        }
      } catch (error) {
        // 规则坏了不该让 App 起不来，退回内置默认
        AppLog.e('Rule', '下载规则解析失败，已回退内置默认', error);
        _rules = DownloadRule.defaults();
      }
    }
    _activeId = prefs.getString('${_key}_active') ?? defaultRuleId;
    if (active == null && _rules.isNotEmpty) _activeId = _rules.first.id;
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_rules.map((rule) => rule.toJson()).toList()),
    );
    await prefs.setString('${_key}_active', _activeId);
  }

  static Future<void> upsert(DownloadRule rule) async {
    final index = _rules.indexWhere((item) => item.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
    } else {
      _rules.add(rule);
    }
    await save();
  }

  static Future<void> remove(String id) async {
    _rules.removeWhere((rule) => rule.id == id);
    if (_activeId == id && _rules.isNotEmpty) _activeId = _rules.first.id;
    await save();
  }

  static Future<void> setActive(String id) async {
    _activeId = id;
    await save();
  }
}

/// 订阅追更的筛选规则（评审第 19 项）。
///
/// 追更是**无人值守**的：没有筛选的话，UP 主发一条 15 秒的转发、一个抽奖动态、
/// 一期 5 小时直播回放，都会在半夜自动占满存储。所以这里把「要不要」的判断
/// 做成纯函数，先测清楚再接进订阅检查里。
class SubscriptionRule {
  const SubscriptionRule({
    this.includeKeywords = const <String>[],
    this.excludeKeywords = const <String>[],
    this.minDurationMs = 0,
    this.maxDurationMs = 0,
    this.minQuality,
    this.codec,
    this.maxPerCheck = 0,
  });

  /// 标题必须全部包含这些词（都命中才算通过）
  final List<String> includeKeywords;

  /// 标题包含任意一个就跳过
  final List<String> excludeKeywords;

  /// 时长下限，0 表示不限
  final int minDurationMs;

  /// 时长上限，0 表示不限
  final int maxDurationMs;

  /// 最低清晰度偏好，null 表示用全局设置
  final int? minQuality;

  final String? codec;

  /// 单次检查最多自动下载几个，0 表示不限。
  /// 防止「第一次订阅一个停更很久的 UP」时一次性建几十个任务。
  final int maxPerCheck;

  bool get isEmpty =>
      includeKeywords.isEmpty &&
      excludeKeywords.isEmpty &&
      minDurationMs <= 0 &&
      maxDurationMs <= 0 &&
      maxPerCheck <= 0;

  /// 判断一个条目是否应该被采纳
  bool matches(MediaItem item) {
    final title = item.title.toLowerCase();

    for (final keyword in excludeKeywords) {
      final word = keyword.trim().toLowerCase();
      if (word.isNotEmpty && title.contains(word)) return false;
    }

    for (final keyword in includeKeywords) {
      final word = keyword.trim().toLowerCase();
      if (word.isNotEmpty && !title.contains(word)) return false;
    }

    if (minDurationMs > 0 && item.durationMs < minDurationMs) return false;
    if (maxDurationMs > 0 && item.durationMs > maxDurationMs) return false;

    return true;
  }

  /// 过滤并按上限截断
  List<MediaItem> apply(List<MediaItem> items) {
    final kept = items.where(matches).toList();
    if (maxPerCheck > 0 && kept.length > maxPerCheck) {
      return kept.sublist(0, maxPerCheck);
    }
    return kept;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'include': includeKeywords,
        'exclude': excludeKeywords,
        'minDuration': minDurationMs,
        'maxDuration': maxDurationMs,
        'minQuality': minQuality,
        'codec': codec,
        'maxPerCheck': maxPerCheck,
      };

  static SubscriptionRule fromJson(Map<String, Object?> json) =>
      SubscriptionRule(
        includeKeywords: _words(json['include']),
        excludeKeywords: _words(json['exclude']),
        minDurationMs: asInt(json['minDuration']),
        maxDurationMs: asInt(json['maxDuration']),
        minQuality:
            json['minQuality'] == null ? null : asInt(json['minQuality']),
        codec: json['codec'] == null ? null : asString(json['codec']),
        maxPerCheck: asInt(json['maxPerCheck']),
      );

  static List<String> _words(Object? raw) =>
      (raw as List?)
          ?.map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false) ??
      const <String>[];

  static SubscriptionRule parse(String? raw) {
    if (raw == null || raw.isEmpty) return const SubscriptionRule();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return SubscriptionRule.fromJson(decoded.cast<String, Object?>());
      }
    } catch (error) {
      AppLog.e('Rule', '订阅规则解析失败，已忽略', error);
    }
    return const SubscriptionRule();
  }

  String encode() => jsonEncode(toJson());
}
