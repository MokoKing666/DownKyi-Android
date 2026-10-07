/// 数据模型：全部手写 fromJson，避免引入代码生成工具。
library;

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<dynamic> asList(dynamic value) => value is List ? value : const <dynamic>[];

/// HTTP url 补全协议
String normalizeUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
  return url;
}

class VideoPageInfo {
  const VideoPageInfo({
    required this.cid,
    required this.page,
    required this.part,
    required this.durationMs,
  });

  final int cid;
  final int page;
  final String part;
  final int durationMs;

  factory VideoPageInfo.fromJson(Map<String, dynamic> json) {
    return VideoPageInfo(
      cid: asInt(json['cid']),
      page: asInt(json['page'], 1),
      part: asString(json['part'], 'P${asInt(json['page'], 1)}'),
      durationMs: asInt(json['duration']) * 1000,
    );
  }
}

class VideoDetail {
  const VideoDetail({
    required this.bvid,
    required this.aid,
    required this.cid,
    required this.title,
    required this.cover,
    required this.ownerName,
    required this.ownerMid,
    required this.durationMs,
    this.desc = '',
    this.tname = '',
    this.view = 0,
    this.danmakuCount = 0,
    this.pages = const <VideoPageInfo>[],
    this.btype = 'video',
    this.epId,
  });

  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String cover;
  final String desc;
  final String tname;
  final String ownerName;
  final int ownerMid;
  final int durationMs;
  final int view;
  final int danmakuCount;
  final List<VideoPageInfo> pages;
  final String btype;
  final int? epId;

  /// 普通视频（/x/web-interface/view）
  factory VideoDetail.fromView(Map<String, dynamic> data) {
    final owner = asMap(data['owner']);
    final stat = asMap(data['stat']);
    final pages = asList(data['pages'])
        .map((item) => VideoPageInfo.fromJson(asMap(item)))
        .toList(growable: false);
    return VideoDetail(
      bvid: asString(data['bvid']),
      aid: asInt(data['aid']),
      cid: asInt(data['cid']),
      title: asString(data['title'], '未命名视频'),
      cover: normalizeUrl(asString(data['pic'])),
      desc: asString(data['desc']),
      tname: asString(data['tname']),
      ownerName: asString(owner['name'], '未知 UP 主'),
      ownerMid: asInt(owner['mid']),
      durationMs: asInt(data['duration']) * 1000,
      view: asInt(stat['view']),
      danmakuCount: asInt(stat['danmaku']),
      pages: pages.isEmpty
          ? <VideoPageInfo>[
              VideoPageInfo(
                cid: asInt(data['cid']),
                page: 1,
                part: asString(data['title'], 'P1'),
                durationMs: asInt(data['duration']) * 1000,
              ),
            ]
          : pages,
    );
  }

  /// 番剧 / 课程单集
  factory VideoDetail.fromEpisode(
    Map<String, dynamic> season,
    Map<String, dynamic> episode, {
    required String btype,
  }) {
    final title = asString(season['title'], '未命名');
    final epTitle = asString(episode['long_title'] ?? episode['title'], '');
    final fullTitle = epTitle.isEmpty ? title : '$title · $epTitle';
    final durationSeconds = asInt(episode['duration']);
    return VideoDetail(
      bvid: asString(episode['bvid']),
      aid: asInt(episode['aid']),
      cid: asInt(episode['cid']),
      title: fullTitle,
      cover: normalizeUrl(asString(episode['cover'] ?? season['cover'])),
      ownerName: season['up_name'] == null ? btype == 'cheese' ? '课程' : '番剧' : asString(season['up_name']),
      ownerMid: asInt(asMap(season['up_info'])['mid']),
      durationMs: durationSeconds * 1000,
      btype: btype,
      epId: asInt(episode['id']),
      pages: <VideoPageInfo>[
        VideoPageInfo(
          cid: asInt(episode['cid']),
          page: 1,
          part: fullTitle,
          durationMs: durationSeconds * 1000,
        ),
      ],
    );
  }

  VideoDetail copyWith({int? cid, String? title}) {
    return VideoDetail(
      bvid: bvid,
      aid: aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      cover: cover,
      desc: desc,
      tname: tname,
      ownerName: ownerName,
      ownerMid: ownerMid,
      durationMs: durationMs,
      view: view,
      danmakuCount: danmakuCount,
      pages: pages,
      btype: btype,
      epId: epId,
    );
  }
}

/// 单条 DASH 流（视频或音频）
class DashStream {
  const DashStream({
    required this.id,
    required this.url,
    required this.bandwidth,
    required this.mimeType,
    required this.codecs,
    this.backupUrls = const <String>[],
    this.width = 0,
    this.height = 0,
    this.frameRate = '',
    this.isVideo = true,
  });

  final int id;
  final String url;
  final List<String> backupUrls;
  final int bandwidth;
  final String mimeType;
  final String codecs;
  final int width;
  final int height;
  final String frameRate;
  final bool isVideo;

  factory DashStream.fromJson(Map<String, dynamic> json, {required bool isVideo}) {
    final base = asString(json['baseUrl'] ?? json['base_url']);
    final backups = asList(json['backupUrl'] ?? json['backup_url'])
        .map((item) => normalizeUrl(item.toString()))
        .toList(growable: false);
    return DashStream(
      id: asInt(json['id']),
      url: normalizeUrl(base),
      backupUrls: backups,
      bandwidth: asInt(json['bandwidth']),
      mimeType: asString(json['mimeType'] ?? json['mime_type'], isVideo ? 'video/mp4' : 'audio/mp4'),
      codecs: asString(json['codecs']),
      width: asInt(json['width']),
      height: asInt(json['height']),
      frameRate: asString(json['frameRate'] ?? json['frame_rate']),
      isVideo: isVideo,
    );
  }

  /// 编码族：avc / hevc / av1
  String get codecFamily {
    final value = codecs.toLowerCase();
    if (value.startsWith('hev') || value.startsWith('hvc')) return 'hevc';
    if (value.startsWith('av01')) return 'av1';
    return 'avc';
  }

  String get qualityLabel => asString(codecs, '未知');
}

class DashInfo {
  const DashInfo({
    required this.durationMs,
    required this.videos,
    required this.audios,
    this.flac,
    this.dolby,
    this.supportFormats = const <int, String>{},
  });

  final int durationMs;
  final List<DashStream> videos;
  final List<DashStream> audios;
  final DashStream? flac;
  final DashStream? dolby;
  final Map<int, String> supportFormats;

  bool get hasVideo => videos.isNotEmpty;
  bool get hasAudio => audios.isNotEmpty || flac != null || dolby != null;

  /// 所有可用清晰度（倒序：从高到低）
  List<int> get qualityList {
    final set = <int>{...videos.map((item) => item.id), ...supportFormats.keys};
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<DashStream> videosOf(int quality) {
    return videos.where((item) => item.id == quality).toList(growable: false);
  }

  /// 选一条视频流：优先指定编码，其次码率最高
  DashStream? pickVideo(int quality, String? preferCodec) {
    var candidates = videosOf(quality);
    if (candidates.isEmpty) {
      final available = qualityList;
      if (available.isEmpty) candidates = videos;
      if (available.isEmpty) return null;
      var fallbackQuality = available.first;
      for (final q in available) {
        if (videosOf(q).isNotEmpty) {
          fallbackQuality = q;
          break;
        }
      }
      candidates = videosOf(fallbackQuality);
      if (candidates.isEmpty) return null;
    }
    if (preferCodec != null && preferCodec.isNotEmpty) {
      final matched = candidates.where((item) => item.codecFamily == preferCodec).toList();
      if (matched.isNotEmpty) candidates = matched;
    }
    candidates = List<DashStream>.from(candidates)
      ..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return candidates.first;
  }

  /// 选音频：优先无损 / 杜比，其次码率最高
  DashStream? pickAudio(int? preferId) {
    final all = <DashStream>[
      if (flac != null) flac!,
      if (dolby != null) dolby!,
      ...audios,
    ];
    if (all.isEmpty) return null;
    if (preferId != null) {
      final matched = all.where((item) => item.id == preferId).toList();
      if (matched.isNotEmpty) return matched.first;
    }
    final sorted = List<DashStream>.from(all)
      ..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return sorted.first;
  }
}

/// 批量列表里的单个条目
class MediaItem {
  const MediaItem({
    required this.bvid,
    required this.cid,
    required this.aid,
    required this.title,
    required this.cover,
    this.durationMs = 0,
    this.ownerName = '',
    this.btype = 'video',
    this.epId,
    this.selected = true,
  });

  final String bvid;
  final int cid;
  final int aid;
  final String title;
  final String cover;
  final int durationMs;
  final String ownerName;
  final String btype;
  final int? epId;
  final bool selected;

  MediaItem copyWith({bool? selected}) => MediaItem(
        bvid: bvid,
        cid: cid,
        aid: aid,
        title: title,
        cover: cover,
        durationMs: durationMs,
        ownerName: ownerName,
        btype: btype,
        epId: epId,
        selected: selected ?? this.selected,
      );

  /// 从列表接口的多种形态里取 cid。
  ///
  /// B 站各列表接口对 cid 的放置位置并不统一：
  /// - 历史 / 稍后再看 / 番剧：顶层 `cid`
  /// - 收藏夹：`ugc.first_cid`
  /// - 部分接口：`pages[0].cid`
  /// UP 主投稿（`arc/search`）与合集（`seasons_archives_list`）干脆不返回 cid，
  /// 需要在下载前补一次详情查询（见 `DownloadManager._ensureCid`）。
  static int resolveCid(Map<String, dynamic> json) {
    final direct = asInt(json['cid']);
    if (direct > 0) return direct;
    final firstCid = asInt(asMap(json['ugc'])['first_cid']);
    if (firstCid > 0) return firstCid;
    final pages = asList(json['pages']);
    if (pages.isNotEmpty) {
      final pageCid = asInt(asMap(pages.first)['cid']);
      if (pageCid > 0) return pageCid;
    }
    return 0;
  }

  factory MediaItem.fromJson(Map<String, dynamic> json, {String btype = 'video'}) {
    final owner = asMap(json['owner'] ?? json['upper']);
    final durationRaw = asInt(json['duration']);
    // 普通视频接口返回秒，部分接口返回毫秒
    final durationMs = durationRaw > 0 && durationRaw < 100000 ? durationRaw * 1000 : durationRaw;
    return MediaItem(
      bvid: asString(json['bvid']),
      cid: resolveCid(json),
      aid: asInt(json['aid'] ?? json['id']),
      title: asString(json['title'], '未命名'),
      cover: normalizeUrl(asString(json['cover'] ?? json['pic'])),
      durationMs: durationMs,
      ownerName: asString(owner['name'] ?? json['author'] ?? json['upper_name']),
      btype: btype,
      epId: json['ep_id'] == null ? null : asInt(json['ep_id']),
    );
  }
}

/// 批量解析结果（收藏夹 / 合集 / 历史 / 稍后再看 / 番剧整季）
class BatchResult {
  const BatchResult({
    required this.title,
    required this.items,
    this.cover = '',
    this.btype = 'video',
    this.mid,
    this.seasonId,
    this.mediaId,
    this.hasMore = false,
    this.page = 1,
  });

  final String title;
  final List<MediaItem> items;
  final String cover;
  final String btype;
  final int? mid;
  final int? seasonId;
  final int? mediaId;
  final bool hasMore;
  final int page;

  BatchResult copyWith({List<MediaItem>? items, bool? hasMore, int? page}) => BatchResult(
        title: title,
        items: items ?? this.items,
        cover: cover,
        btype: btype,
        mid: mid,
        seasonId: seasonId,
        mediaId: mediaId,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
      );
}

/// 解析入口的统一返回
class ParseOutcome {
  const ParseOutcome({this.video, this.batch});

  final VideoDetail? video;
  final BatchResult? batch;

  bool get isVideo => video != null;
  bool get isBatch => batch != null;
}

class NavInfo {
  const NavInfo({
    required this.isLogin,
    this.uname = '',
    this.face = '',
    this.mid = 0,
    this.level = 0,
    this.vipLabel = '',
    this.coins = 0,
  });

  final bool isLogin;
  final String uname;
  final String face;
  final int mid;
  final int level;
  final String vipLabel;
  final int coins;

  factory NavInfo.fromJson(Map<String, dynamic> data) {
    final levelInfo = asMap(data['level_info']);
    final vip = asMap(data['vip']);
    return NavInfo(
      isLogin: data['isLogin'] == true,
      uname: asString(data['uname']),
      face: normalizeUrl(asString(data['face'])),
      mid: asInt(data['mid']),
      level: asInt(levelInfo['current_level']),
      vipLabel: vip['label'] == null ? '' : asString(asMap(vip['label'])['text']),
      coins: asInt(data['money']),
    );
  }
}

class QrLogin {
  const QrLogin({required this.url, required this.key});
  final String url;
  final String key;
}

class QrPollResult {
  const QrPollResult({required this.code, required this.message, this.cookie});
  final int code;
  final String message;
  final String? cookie;

  /// 0 = 成功，86101 = 未扫码，86090 = 已扫码待确认，86038 = 已过期
  bool get success => code == 0;
  bool get expired => code == 86038;
  bool get scanned => code == 86090;
}

class SubtitleItem {
  const SubtitleItem({
    required this.lan,
    required this.lanDoc,
    required this.url,
    this.isAi = false,
  });

  final String lan;
  final String lanDoc;
  final String url;
  final bool isAi;

  factory SubtitleItem.fromJson(Map<String, dynamic> json) => SubtitleItem(
        lan: asString(json['lan']),
        lanDoc: asString(json['lan_doc']),
        url: normalizeUrl(asString(json['subtitle_url'])),
        isAi: asInt(json['ai_status']) != 0,
      );
}

/// 弹幕
class DanmakuItem {
  const DanmakuItem({
    required this.progressMs,
    required this.mode,
    required this.fontSize,
    required this.color,
    required this.content,
  });

  final int progressMs;
  final int mode; // 1-3 滚动，4 底部，5 顶部
  final int fontSize;
  final int color;
  final String content;
}
