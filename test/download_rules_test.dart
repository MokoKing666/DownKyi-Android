import 'package:downkyi/bili/models.dart';
import 'package:downkyi/bili/subtitles.dart';
import 'package:downkyi/core/constants.dart';
import 'package:downkyi/download/danmaku_writer.dart';
import 'package:downkyi/download/download_rules.dart';
import 'package:downkyi/download/ffmpeg_ops.dart';
import 'package:flutter_test/flutter_test.dart';

/// 智能下载相关的纯逻辑测试（评审第 15 / 16 / 18 / 19 / 21 / 22 项）。
///
/// 这几项的共同点是「决策在客户端做」：选哪档、下哪些语言、要不要采纳这条更新。
/// 决策逻辑一旦错了，用户看到的不是报错，而是**下到了不该下的东西**——
/// 半夜自动下了一堆十几秒的转发、或者 8K 下完根本播不动。
/// 所以全部做成纯函数并在此钉住。
void main() {
  DashStream video(int quality, int bandwidth, String codecs) => DashStream(
        id: quality,
        url: 'https://x/$quality.m4s',
        bandwidth: bandwidth,
        mimeType: 'video/mp4',
        codecs: codecs,
        isVideo: true,
      );

  DashStream audio(int id, int bandwidth) => DashStream(
        id: id,
        url: 'https://x/a$id.m4s',
        bandwidth: bandwidth,
        mimeType: 'audio/mp4',
        codecs: 'mp4a.40.2',
        isVideo: false,
      );

  /// 1080P 有 AVC 与 HEVC，720P 只有 AVC，4K 只有 HEVC 与 AV1
  DashInfo buildDash() => DashInfo(
        durationMs: 60000,
        videos: <DashStream>[
          video(120, 12000000, 'hev1.1.6.L120'),
          video(120, 14000000, 'av01.0.08M.08'),
          video(80, 4000000, 'avc1.640028'),
          video(80, 2600000, 'hev1.1.6.L120'),
          video(64, 1800000, 'avc1.64001F'),
        ],
        audios: <DashStream>[
          audio(30216, 64000),
          audio(30280, 192000),
          audio(30232, 132000),
        ],
      );

  group('编码族识别', () {
    test('avc / hevc / av1', () {
      expect(video(80, 1, 'avc1.640028').codecFamily, 'avc');
      expect(video(80, 1, 'hev1.1.6.L120').codecFamily, 'hevc');
      expect(video(80, 1, 'hvc1.1.6.L120').codecFamily, 'hevc');
      expect(video(80, 1, 'av01.0.08M.08').codecFamily, 'av1');
    });
  });

  group('SmartPicker 选清晰度', () {
    test('画质优先：取最高档', () {
      expect(SmartPicker.pickQuality(buildDash(), PreferenceMode.bestQuality),
          120);
    });

    test('兼容性优先：取最高「有 AVC」的档位', () {
      // 4K 只有 HEVC/AV1，老设备播不了，所以退到 1080P（有 AVC）
      expect(SmartPicker.pickQuality(buildDash(), PreferenceMode.compatibility),
          80);
    });

    test('体积优先：不降到 720P 以下，且挑体积最小的那档', () {
      // 1080P HEVC 2.6Mbps 比 720P AVC 1.8Mbps 大 → 会选 720P
      // 但 1080P 里的 HEVC 2.6Mbps 才是「不降画质」的最优解；
      // 这里 80 档的最小码率 2.6M < 64 档的 1.8M 为假 → 应选 64
      final picked =
          SmartPicker.pickQuality(buildDash(), PreferenceMode.smallSize);
      expect(picked, 64);
    });

    test('速度优先：允许取到最低档', () {
      final picked =
          SmartPicker.pickQuality(buildDash(), PreferenceMode.fastSpeed);
      expect(picked, 64);
    });

    test('档位完全为空时回退到默认 1080P', () {
      const empty = DashInfo(
        durationMs: 0,
        videos: <DashStream>[],
        audios: <DashStream>[],
      );
      expect(SmartPicker.pickQuality(empty, PreferenceMode.bestQuality), 80);
    });

    test('vipOnly 过滤生效', () {
      final picked = SmartPicker.pickQuality(
        buildDash(),
        PreferenceMode.bestQuality,
        vipOnly: (quality) => quality != 120,
      );
      expect(picked, 80);
    });
  });

  group('SmartPicker 选编码', () {
    test('兼容性优先选 AVC', () {
      expect(
          SmartPicker.pickCodec(buildDash(), 80, PreferenceMode.compatibility),
          'avc');
    });

    test('画质优先选 HEVC', () {
      expect(
          SmartPicker.pickCodec(buildDash(), 120, PreferenceMode.bestQuality),
          'hevc');
    });

    test('体积优先选 AV1', () {
      expect(SmartPicker.pickCodec(buildDash(), 120, PreferenceMode.smallSize),
          'av1');
    });

    test('只列出该档位真实存在的编码', () {
      expect(
          SmartPicker.codecsOf(buildDash(), 80, PreferenceMode.bestQuality)
              .toSet(),
          <String>{'avc', 'hevc'});
      expect(SmartPicker.codecsOf(buildDash(), 64, PreferenceMode.bestQuality),
          <String>['avc']);
    });

    test('没有该档位时返回 null', () {
      expect(
          SmartPicker.pickCodec(buildDash(), 127, PreferenceMode.bestQuality),
          isNull);
    });
  });

  group('SmartPicker 选音轨', () {
    test('画质优先取最高码率', () {
      expect(SmartPicker.pickAudioId(buildDash(), PreferenceMode.bestQuality),
          30280);
    });

    test('速度优先取最低码率', () {
      expect(SmartPicker.pickAudioId(buildDash(), PreferenceMode.fastSpeed),
          30216);
    });

    test('没有音轨时返回 null', () {
      const noAudio = DashInfo(
          durationMs: 1, videos: <DashStream>[], audios: <DashStream>[]);
      expect(
          SmartPicker.pickAudioId(noAudio, PreferenceMode.bestQuality), isNull);
    });
  });

  group('MediaEstimator 体积预估（第 16 项）', () {
    test('比特率 × 时长换算成字节', () {
      // 2 Mbps 跑 60 秒 = 120 Mbit = 15 MB
      expect(
          MediaEstimator.bytesOfStream(audio(30280, 2000000), 60000), 15000000);
    });

    test('非法输入返回 0 而不是抛异常', () {
      expect(MediaEstimator.bytesOfStream(null, 60000), 0);
      expect(MediaEstimator.bytesOfStream(audio(1, 0), 60000), 0);
      expect(MediaEstimator.bytesOfStream(audio(1, 1000), 0), 0);
    });

    test('视频 + 音频合计', () {
      final dash = buildDash();
      final videoBytes =
          MediaEstimator.videoBytes(dash, 80, 'avc', dash.durationMs);
      final audioBytes =
          MediaEstimator.audioBytes(dash, 30280, dash.durationMs);
      expect(
        MediaEstimator.totalBytes(dash,
            quality: 80, codec: 'avc', audioId: 30280),
        videoBytes + audioBytes,
      );
    });

    test('描述文案带「约」和单位', () {
      final text =
          MediaEstimator.describe(buildDash(), quality: 80, codec: 'avc');
      expect(text, contains('约'));
      expect(text, anyOf(contains('MB'), contains('GB')));
    });

    test('清单只包含真实存在的组合', () {
      final rows = MediaEstimator.list(buildDash(), PreferenceMode.bestQuality);
      expect(rows, isNotEmpty);
      expect(rows.every((row) => row.bytes > 0), isTrue);
      // 1080P 有两种编码 → 至少出现两行
      expect(rows.where((row) => row.quality == 80).length, 2);
    });
  });

  group('SubscriptionRule 追更筛选（第 19 项）', () {
    MediaItem item(String title, int durationMs) => MediaItem(
          bvid: 'BV$title',
          cid: 1,
          aid: 1,
          title: title,
          cover: '',
          durationMs: durationMs,
          ownerName: 'UP',
        );

    test('空规则全部通过', () {
      const rule = SubscriptionRule();
      expect(rule.isEmpty, isTrue);
      expect(rule.matches(item('任意标题', 1000)), isTrue);
    });

    test('关键词包含：必须全部命中', () {
      const rule = SubscriptionRule(includeKeywords: <String>['Sony', '评测']);
      expect(rule.matches(item('Sony 新机评测', 1)), isTrue);
      expect(rule.matches(item('Sony 发布会', 1)), isFalse);
    });

    test('关键词排除：命中任意一个就跳过', () {
      const rule = SubscriptionRule(excludeKeywords: <String>['Shorts', '抽奖']);
      expect(rule.matches(item('每日 Shorts', 1)), isFalse);
      expect(rule.matches(item('双十一抽奖', 1)), isFalse);
      expect(rule.matches(item('正经视频', 1)), isTrue);
    });

    test('关键词大小写不敏感', () {
      const rule = SubscriptionRule(includeKeywords: <String>['sony']);
      expect(rule.matches(item('SONY 新品', 1)), isTrue);
    });

    test('时长下限过滤掉短视频（追更最实用的一个）', () {
      const rule = SubscriptionRule(minDurationMs: 180000);
      expect(rule.matches(item('15 秒转发', 15000)), isFalse);
      expect(rule.matches(item('正经长视频', 600000)), isTrue);
    });

    test('时长上限过滤掉超长直播回放', () {
      const rule = SubscriptionRule(maxDurationMs: 3600000);
      expect(rule.matches(item('5 小时回放', 5 * 3600000)), isFalse);
      expect(rule.matches(item('半小时视频', 1800000)), isTrue);
    });

    test('maxPerCheck 截断，避免半夜建几十个任务', () {
      const rule = SubscriptionRule(maxPerCheck: 2);
      final items = <MediaItem>[
        for (var i = 0; i < 5; i++) item('视频$i', 60000),
      ];
      expect(rule.apply(items).length, 2);
    });

    test('过滤与截断会叠加', () {
      const rule = SubscriptionRule(
        excludeKeywords: <String>['Shorts'],
        minDurationMs: 60000,
        maxPerCheck: 1,
      );
      final items = <MediaItem>[
        item('Shorts 一条', 600000),
        item('太短', 1000),
        item('合格 A', 600000),
        item('合格 B', 600000),
      ];
      final kept = rule.apply(items);
      expect(kept.length, 1);
      expect(kept.first.title, '合格 A');
    });

    test('JSON 往返不丢字段', () {
      const rule = SubscriptionRule(
        includeKeywords: <String>['Sony'],
        excludeKeywords: <String>['Shorts'],
        minDurationMs: 180000,
        maxDurationMs: 7200000,
        minQuality: 80,
        codec: 'hevc',
        maxPerCheck: 3,
      );
      final restored = SubscriptionRule.parse(rule.encode());
      expect(restored.includeKeywords, rule.includeKeywords);
      expect(restored.excludeKeywords, rule.excludeKeywords);
      expect(restored.minDurationMs, rule.minDurationMs);
      expect(restored.maxDurationMs, rule.maxDurationMs);
      expect(restored.minQuality, rule.minQuality);
      expect(restored.codec, rule.codec);
      expect(restored.maxPerCheck, rule.maxPerCheck);
    });

    test('坏数据不会崩，退回空规则', () {
      expect(SubscriptionRule.parse('{不是 json').isEmpty, isTrue);
      expect(SubscriptionRule.parse('').isEmpty, isTrue);
      expect(SubscriptionRule.parse(null).isEmpty, isTrue);
    });
  });

  group('DownloadRule 规则模板（第 18 项）', () {
    test('内置规则可直接用', () {
      final defaults = DownloadRule.defaults();
      expect(defaults, isNotEmpty);
      expect(defaults.first.name.isNotEmpty, isTrue);
      expect(defaults.first.wantVideo, isTrue);
    });

    test('flags 位派生正确', () {
      final rule = DownloadRule(
        id: 'r',
        name: 'n',
        flags: DownloadFlags.video | DownloadFlags.subtitle,
      );
      expect(rule.wantVideo, isTrue);
      expect(rule.wantSubtitle, isTrue);
      expect(rule.wantAudio, isFalse);
      expect(rule.wantDanmaku, isFalse);
    });

    test('JSON 往返不丢字段', () {
      final rule = DownloadRule(
        id: 'r1',
        name: '高画质',
        mode: PreferenceMode.smallSize,
        quality: 120,
        codec: 'av1',
        audioId: 30280,
        flags: DownloadFlags.video | DownloadFlags.subtitle,
        danmakuFormat: DanmakuFormat.xml,
        subtitleLanguages: const <String>['zh-Hans', 'en-US'],
        fileNameTemplate: '{owner}/{title}',
        applyTemplate: true,
      );
      final restored = DownloadRule.fromJson(rule.toJson());
      expect(restored.id, 'r1');
      expect(restored.mode, PreferenceMode.smallSize);
      expect(restored.quality, 120);
      expect(restored.codec, 'av1');
      expect(restored.audioId, 30280);
      expect(restored.danmakuFormat, DanmakuFormat.xml);
      expect(restored.subtitleLanguages, <String>['zh-Hans', 'en-US']);
      expect(restored.fileNameTemplate, '{owner}/{title}');
      expect(restored.applyTemplate, isTrue);
    });
  });

  group('SubtitleLanguage 多语言字幕（第 21 项）', () {
    SubtitleItem sub(String lan, {bool ai = false}) => SubtitleItem(
        lan: lan, lanDoc: lan, url: 'https://s/$lan.json', isAi: ai);

    test('归一化 B 站的多种写法', () {
      expect(SubtitleLanguage.normalize('zh-CN'), 'zh-Hans');
      expect(SubtitleLanguage.normalize('zh-Hans'), 'zh-Hans');
      expect(SubtitleLanguage.normalize('zh-Hant'), 'zh-Hant');
      expect(SubtitleLanguage.normalize('zh-TW'), 'zh-Hant');
      expect(SubtitleLanguage.normalize('zh-HK'), 'zh-Hant');
      expect(SubtitleLanguage.normalize('en-US'), 'en-US');
      expect(SubtitleLanguage.normalize('en'), 'en-US');
      expect(SubtitleLanguage.normalize('ja'), 'ja');
      expect(SubtitleLanguage.normalize('ai-zh'), 'ai-zh');
      expect(SubtitleLanguage.normalize(''), '');
    });

    test('按用户选的语言挑，顺序跟随用户', () {
      final available = <SubtitleItem>[sub('zh-CN'), sub('en-US'), sub('ja')];
      final picked =
          SubtitleLanguage.select(available, <String>['en-US', 'zh-Hans']);
      expect(picked.map((item) => item.lan), <String>['en-US', 'zh-CN']);
    });

    test('没有所选语言时返回空，而不是随便塞一条', () {
      final available = <SubtitleItem>[sub('ja')];
      expect(SubtitleLanguage.select(available, <String>['zh-Hans']), isEmpty);
    });

    test('AI 字幕与人工字幕并存时优先人工', () {
      final available = <SubtitleItem>[
        sub('zh-CN', ai: true),
        sub('zh-Hans', ai: false),
      ];
      final picked = SubtitleLanguage.select(available, <String>['zh-Hans']);
      expect(picked.length, 1);
      expect(picked.first.isAi, isFalse);
    });

    test('只要 AI 简体时不会被人工字幕顶替', () {
      final available = <SubtitleItem>[sub('zh-CN'), sub('ai-zh')];
      final picked = SubtitleLanguage.select(available, <String>['ai-zh']);
      expect(picked.map((item) => item.lan), <String>['ai-zh']);
    });

    test('可用语言去重且按固定顺序', () {
      final available = <SubtitleItem>[sub('ja'), sub('zh-CN'), sub('zh-Hans')];
      expect(SubtitleLanguage.availableCodes(available),
          <String>['zh-Hans', 'ja']);
    });

    test('文件后缀可直接拼进文件名', () {
      expect(SubtitleLanguage.fileSuffix('zh-Hans'), 'zh-Hans');
      expect(SubtitleLanguage.fileSuffix('en-US'), 'en-US');
    });
  });

  group('DanmakuStyle 弹幕样式（第 22 项）', () {
    test('字号按缩放计算', () {
      expect(const DanmakuStyle().fontSize, DanmakuWriter.baseFontSize);
      expect(const DanmakuStyle(fontScale: 1.5).fontSize,
          (DanmakuWriter.baseFontSize * 1.5).round());
    });

    test('显式字号优先于缩放', () {
      expect(
          const DanmakuStyle(fontScale: 2, fontSizeOverride: 30).fontSize, 30);
    });

    test('不透明度换算成 ASS 的 alpha 字节（00 = 不透明）', () {
      expect(const DanmakuStyle(opacity: 1).alphaByte, 0);
      expect(const DanmakuStyle(opacity: 0).alphaByte, 255);
      expect(const DanmakuStyle(opacity: 0.5).alphaByte, 128);
      expect(const DanmakuStyle(opacity: 1).alphaHex, '00');
    });

    test('越界的不透明度被夹住', () {
      expect(const DanmakuStyle(opacity: 2).alphaByte, 0);
      expect(const DanmakuStyle(opacity: -1).alphaByte, 255);
    });

    test('copyWith 只改指定项', () {
      const base =
          DanmakuStyle(fontScale: 1, opacity: 1, scrollDurationMs: 8000);
      final changed = base.copyWith(opacity: 0.5);
      expect(changed.opacity, 0.5);
      expect(changed.fontScale, 1);
      expect(changed.scrollDurationMs, 8000);
    });

    test('JSON 往返', () {
      const style = DanmakuStyle(
        fontScale: 1.2,
        opacity: 0.7,
        scrollDurationMs: 12000,
        laneRatio: 0.4,
        enableTop: false,
      );
      final restored = DanmakuStyle.fromJson(style.toJson());
      expect(restored.fontScale, 1.2);
      expect(restored.opacity, 0.7);
      expect(restored.scrollDurationMs, 12000);
      expect(restored.laneRatio, 0.4);
      expect(restored.enableTop, isFalse);
      expect(restored.enableScroll, isTrue);
    });

    test('摘要包含全部可调项', () {
      final summary = const DanmakuStyle().summary;
      expect(summary, contains('字号'));
      expect(summary, contains('不透明度'));
      expect(summary, contains('滚动'));
      expect(summary, contains('占屏'));
    });

    test('生成的 ASS 里带上了透明度与字号', () {
      final ass = DanmakuWriter.toAss(
        const <DanmakuItem>[
          DanmakuItem(
              progressMs: 1000,
              mode: 1,
              fontSize: 25,
              color: 0xFFFFFF,
              content: '你好'),
        ],
        style: const DanmakuStyle(opacity: 0.5, fontScale: 1.5),
      );
      expect(ass, contains('&H80FFFFFF'));
      expect(ass, contains('PlayResX: 1920'));
      expect(ass, contains('你好'));
    });

    test('关掉滚动后不再产出滚动弹幕', () {
      final ass = DanmakuWriter.toAss(
        const <DanmakuItem>[
          DanmakuItem(
              progressMs: 1000,
              mode: 1,
              fontSize: 25,
              color: 0xFFFFFF,
              content: '滚动'),
        ],
        style: const DanmakuStyle(enableScroll: false),
      );
      expect(ass.contains('滚动'), isFalse);
      expect(ass.contains('\\move'), isFalse);
    });
  });

  group('FfmpegOps 参数构造（第 23 项）', () {
    test('时间戳格式', () {
      expect(FfmpegOps.formatTimestamp(0), '00:00:00.000');
      expect(FfmpegOps.formatTimestamp(1500), '00:00:01.500');
      expect(FfmpegOps.formatTimestamp(3661000), '01:01:01.000');
      expect(FfmpegOps.formatTimestamp(-5), '00:00:00.000');
    });

    test('无损截取：-ss 必须在 -i 之前（否则会退化成先解码再丢弃）', () {
      final args = FfmpegOps.trim(
        input: 'in.mp4',
        output: 'out.mp4',
        startMs: 10000,
        endMs: 40000,
      );
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args, contains('-c'));
      expect(args[args.indexOf('-c') + 1], 'copy');
      // copy + 定位会产生负时间戳
      expect(args, contains('make_zero'));
      // 用时长而不是结束时间
      expect(args[args.indexOf('-t') + 1], '00:00:30.000');
      expect(args.last, 'out.mp4');
    });

    test('无损截取：起止颠倒时兜底给 1 秒，不生成 0 长度命令', () {
      final args = FfmpegOps.trim(
        input: 'in.mp4',
        output: 'out.mp4',
        startMs: 40000,
        endMs: 10000,
      );
      expect(args[args.indexOf('-ss') + 1], '00:00:40.000');
      expect(args[args.indexOf('-t') + 1], '00:00:01.000');
    });

    test('调整音量：只挂音频滤镜，视频直接复制', () {
      final args =
          FfmpegOps.volume(input: 'a.mp4', output: 'b.mp4', multiplier: 1.5);
      expect(args[args.indexOf('-filter:a') + 1], 'volume=1.50');
      expect(args[args.indexOf('-c:v') + 1], 'copy');
    });

    test('调整音量：非法倍数兜底为 1.0', () {
      final args =
          FfmpegOps.volume(input: 'a.mp4', output: 'b.mp4', multiplier: 0);
      expect(args[args.indexOf('-filter:a') + 1], 'volume=1.00');
    });

    test('调整帧率：音频不重编码', () {
      final args = FfmpegOps.fps(input: 'a.mp4', output: 'b.mp4', fps: 60);
      expect(args[args.indexOf('-vf') + 1], 'fps=60');
      expect(args[args.indexOf('-c:a') + 1], 'copy');
    });

    test('调整分辨率：高度用 -2 保证是偶数', () {
      // 用 -1 会算出奇数高度，H.264 直接编码失败
      final args =
          FfmpegOps.scale(input: 'a.mp4', output: 'b.mp4', width: 1280);
      expect(args[args.indexOf('-vf') + 1], 'scale=1280:-2');
    });

    test('提取音频：必须丢掉视频轨', () {
      expect(FfmpegOps.extractAudio(input: 'a.mp4', output: 'b.m4a'),
          contains('-vn'));
      expect(
        FfmpegOps.extractAudio(input: 'a.mp4', output: 'b.m4a', copy: true),
        contains('copy'),
      );
      final args = FfmpegOps.extractAudio(
          input: 'a.mp4', output: 'b.mp3', bitrateKbps: 320);
      expect(args[args.indexOf('-b:a') + 1], '320k');
    });

    test('提取字幕：映射第一条字幕轨并转 srt', () {
      final args = FfmpegOps.extractSubtitle(input: 'a.mkv', output: 'b.srt');
      expect(args[args.indexOf('-map') + 1], '0:s:0');
      expect(args[args.indexOf('-c:s') + 1], 'srt');
    });

    test('提取封面：只取一帧', () {
      final args =
          FfmpegOps.extractCover(input: 'a.mp4', output: 'c.jpg', atMs: 5000);
      expect(args, contains('-frames:v'));
      expect(args[args.indexOf('-ss') + 1], '00:00:05.000');
    });
  });

  group('FfmpegOps 无损重封装（修复画面卡顿用）', () {
    test('音视频双输入：显式 -map，避免多搬无关轨道', () {
      final args =
          FfmpegOps.remux(video: 'v.m4s', audio: 'a.m4s', output: 'out.mp4');
      expect(args.where((item) => item == '-i').length, 2);
      expect(args[args.indexOf('-i') + 1], 'v.m4s');
      expect(args.lastIndexOf('-i'), greaterThan(args.indexOf('-i')));
      expect(args[args.lastIndexOf('-i') + 1], 'a.m4s');
      // 必须是 0:v:0 —— **只取第一条视频轨**。
      // 杜比视界 Profile 7 是「基础层 + 增强层」两条独立视频轨，
      // 写成 0:v 会把两条都搬进成品：体积正好翻倍，而且系统播放器播不了。
      // 「能播」优先于「杜比标好看」。
      expect(args[args.indexOf('-map') + 1], '0:v:0');
      expect(args[args.indexOf('-map') + 1], isNot('0:v'));
      expect(args.lastIndexOf('-map'), greaterThan(args.indexOf('-map')));
      expect(args[args.lastIndexOf('-map') + 1], '1:a');
    });

    test('必须是无损：-c copy，不能出现任何编码器', () {
      final args =
          FfmpegOps.remux(video: 'v.m4s', audio: 'a.m4s', output: 'o.mp4');
      expect(args[args.indexOf('-c') + 1], 'copy');
      expect(args.where((item) => item == '-c').length, 1);
      for (final encoder in <String>['libx264', 'libx265', 'libvpx-vp9']) {
        expect(args.contains(encoder), isFalse);
      }
    });

    test('默认把 moov 前置，便于起播与拖动', () {
      final args = FfmpegOps.remux(video: 'v.m4s', output: 'o.mp4');
      expect(args[args.indexOf('-movflags') + 1], '+faststart');
    });

    test('可以关掉 faststart（大文件省一次尾部搬移）', () {
      final args =
          FfmpegOps.remux(video: 'v.m4s', output: 'o.mp4', fastStart: false);
      expect(args.contains('-movflags'), isFalse);
    });

    test('单输入：只有一个 -i、一条视频轨', () {
      final args = FfmpegOps.remux(video: 'a.m4s', output: 'o.m4a');
      expect(args.where((item) => item == '-i').length, 1);
      // 与双输入保持一致：只取第一条视频轨
      expect(args[args.indexOf('-map') + 1], '0:v:0');
      expect(args.where((item) => item == '-map').length, 1);
      expect(args[args.indexOf('-c') + 1], 'copy');
    });

    test('放开非官方标签，否则杜比视界的 dvh1/dvhe 写不出来', () {
      final args =
          FfmpegOps.remux(video: 'v.m4s', audio: 'a.m4s', output: 'o.mp4');
      expect(args[args.indexOf('-strict') + 1], 'unofficial');
      // 必须在输出路径之前，否则会被当成输入文件
      expect(args.indexOf('-strict'), lessThan(args.length - 1));
    });

    test('空音频路径等同单输入', () {
      final args = FfmpegOps.remux(video: 'v.m4s', audio: '', output: 'o.mp4');
      expect(args.where((item) => item == '-i').length, 1);
    });

    test('输出路径永远在最后', () {
      expect(FfmpegOps.remux(video: 'v', audio: 'a', output: 'r.mp4').last,
          'r.mp4');
      expect(FfmpegOps.remux(video: 'v', output: 'r.m4a').last, 'r.m4a');
    });
  });

  group('TaskSources 任务来源（第 20 项）', () {
    test('本机地址识别', () {
      expect(TaskSources.isLoopback('http://127.0.0.1:6800/jsonrpc'), isTrue);
      expect(TaskSources.isLoopback('http://127.1.2.3:6800/jsonrpc'), isTrue);
      expect(TaskSources.isLoopback('http://localhost:6800/jsonrpc'), isTrue);
      expect(TaskSources.isLoopback('http://[::1]:6800/jsonrpc'), isTrue);
    });

    test('远程地址不会被误判成本机', () {
      expect(
          TaskSources.isLoopback('http://192.168.1.10:6800/jsonrpc'), isFalse);
      expect(TaskSources.isLoopback('http://nas.local:6800/jsonrpc'), isFalse);
      expect(TaskSources.isLoopback(''), isFalse);
      expect(TaskSources.isLoopback('不是地址'), isFalse);
    });

    test('来源标签可读', () {
      expect(TaskSource.local.label, '本机');
      expect(TaskSource.aria2Remote.label, contains('远程'));
      expect(TaskSource.aria2Remote.isRemote, isTrue);
      expect(TaskSource.aria2Local.isRemote, isFalse);
    });
  });
}
