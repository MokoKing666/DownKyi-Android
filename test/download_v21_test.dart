import 'package:downkyi/bili/models.dart';
import 'package:downkyi/bili/subtitles.dart';
import 'package:downkyi/download/download_archive.dart';
import 'package:downkyi/download/ffmpeg_ops.dart';
import 'package:downkyi/download/start_throttle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v2.1.0 新增能力的测试（参考 BBDownT / BBDownAndroid 做的四项功能）。
///
/// 这四项的共同点：错了都不会抛异常——
/// 节流错了只是「批量下载还是被风控」、归档错了只是「又重复下载」、
/// AI 字幕策略错了只是「下了不想要的字幕」、元数据参数错了 FFmpeg 静默失败。
/// 所以只能靠测试把行为钉住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StartThrottle 任务启动间隔（防风控）', () {
    test('间隔为 0：完全不限（默认，保持旧行为）', () {
      final throttle = StartThrottle(intervalSeconds: 0);
      expect(throttle.tryAcquire(0), isTrue);
      expect(throttle.tryAcquire(1), isTrue);
      expect(throttle.tryAcquire(2), isTrue);
      expect(throttle.remainingMs(3), 0);
    });

    test('第一次启动永远立刻放行', () {
      final throttle = StartThrottle(intervalSeconds: 5);
      expect(throttle.tryAcquire(100000), isTrue);
    });

    test('间隔内拒绝启动，并报告剩余等待时间', () {
      final throttle = StartThrottle(intervalSeconds: 5);
      expect(throttle.tryAcquire(10000), isTrue);
      expect(throttle.tryAcquire(12000), isFalse);
      expect(throttle.remainingMs(12000), 3000);
      expect(throttle.remainingMs(14999), 1);
    });

    test('间隔到点后放行', () {
      final throttle = StartThrottle(intervalSeconds: 5);
      expect(throttle.tryAcquire(10000), isTrue);
      expect(throttle.tryAcquire(15000), isTrue);
      // 放行后重新计间隔
      expect(throttle.tryAcquire(16000), isFalse);
    });

    test('被拒绝时不应推进上次启动时间', () {
      // 否则连续被拒会让等待时间无限后移
      final throttle = StartThrottle(intervalSeconds: 5);
      expect(throttle.tryAcquire(10000), isTrue);
      expect(throttle.tryAcquire(12000), isFalse);
      expect(throttle.tryAcquire(13000), isFalse);
      expect(throttle.tryAcquire(15000), isTrue); // 仍按 10000 算
    });

    test('运行中把间隔调大 / 调小都按新值生效', () {
      final throttle = StartThrottle(intervalSeconds: 5);
      expect(throttle.tryAcquire(10000), isTrue);
      throttle.intervalSeconds = 60;
      expect(throttle.tryAcquire(20000), isFalse);
      throttle.intervalSeconds = 1;
      expect(throttle.tryAcquire(20000), isTrue);
    });
  });

  group('DownloadArchive 下载归档', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('mediaKey 稳定且区分媒体身份', () {
      final a = DownloadArchive.mediaKey(
          bvid: 'BV1xx',
          cid: 1,
          epId: null,
          quality: 80,
          codec: 'avc',
          audioId: null);
      final b = DownloadArchive.mediaKey(
          bvid: 'BV1xx',
          cid: 1,
          epId: null,
          quality: 80,
          codec: 'avc',
          audioId: null);
      expect(a, b);
      // 清晰度、编码、分P、音轨任何一个不同都不是同一个文件
      final c = DownloadArchive.mediaKey(
          bvid: 'BV1xx',
          cid: 1,
          epId: null,
          quality: 112,
          codec: 'avc',
          audioId: null);
      expect(a, isNot(c));
      final d = DownloadArchive.mediaKey(
          bvid: 'BV1xx',
          cid: 1,
          epId: null,
          quality: 80,
          codec: 'hevc',
          audioId: null);
      expect(a, isNot(d));
      final e = DownloadArchive.mediaKey(
          bvid: 'BV1xx',
          cid: 2,
          epId: null,
          quality: 80,
          codec: 'avc',
          audioId: null);
      expect(a, isNot(e));
      // epId 为空与为 0 视为一致（都归一成 0）
      final f = DownloadArchive.mediaKey(
          bvid: 'BV1xx',
          cid: 1,
          epId: 0,
          quality: 80,
          codec: 'avc',
          audioId: null);
      expect(a, f);
    });

    test('add 之后 contains 命中；未添加的不命中', () async {
      final archive = DownloadArchive.instance;
      expect(await archive.contains('k1'), isFalse);
      await archive.add('k1');
      expect(await archive.contains('k1'), isTrue);
      expect(await archive.contains('k2'), isFalse);
      expect(await archive.length, 1);
    });

    test('重复添加不产生重复条目', () async {
      final archive = DownloadArchive.instance;
      await archive.add('k1');
      await archive.add('k1');
      expect(await archive.length, 1);
    });

    test('clear 清空并返回条数', () async {
      final archive = DownloadArchive.instance;
      await archive.add('k1');
      await archive.add('k2');
      expect(await archive.clear(), 2);
      expect(await archive.length, 0);
      expect(await archive.contains('k1'), isFalse);
    });

    test('trim 超出上限时丢弃最旧的（FIFO）', () {
      final list = List<String>.generate(10, (i) => 'k$i');
      final trimmed = DownloadArchive.trim(list, 5);
      expect(trimmed, <String>['k5', 'k6', 'k7', 'k8', 'k9']);
    });

    test('trim 不超上限时原样返回副本', () {
      final list = <String>['a', 'b'];
      final trimmed = DownloadArchive.trim(list, 5);
      expect(trimmed, list);
      expect(identical(trimmed, list), isFalse);
    });

    test('归档容量满后新条目顶掉最旧条目', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'download_archive':
            List<String>.generate(DownloadArchive.maxEntries, (i) => 'old$i'),
      });
      final archive = DownloadArchive.instance;
      await archive.add('new');
      expect(await archive.contains('new'), isTrue);
      expect(await archive.contains('old0'), isFalse); // 最旧的被顶掉
      expect(await archive.length, DownloadArchive.maxEntries);
    });
  });

  group('AiSubtitleStrategy AI 字幕策略', () {
    SubtitleItem human(String lan) =>
        SubtitleItem(lan: lan, lanDoc: lan, url: 'https://s/$lan');
    SubtitleItem ai(String lan) =>
        SubtitleItem(lan: lan, lanDoc: lan, url: 'https://s/$lan', isAi: true);

    test('人工优先（默认）：同语言有人工就不用 AI', () {
      final chosen = SubtitleLanguage.select(
        <SubtitleItem>[ai('zh-CN'), human('zh-Hans')],
        <String>['zh-Hans'],
      );
      expect(chosen.single.isAi, isFalse);
    });

    test('人工优先：没有人工时仍用 AI 兜底', () {
      final chosen = SubtitleLanguage.select(
        <SubtitleItem>[ai('zh-CN')],
        <String>['zh-Hans'],
      );
      expect(chosen.single.isAi, isTrue);
    });

    test('不用 AI：某语言只有 AI 时视为没有', () {
      final chosen = SubtitleLanguage.select(
        <SubtitleItem>[ai('zh-CN'), human('en')],
        <String>['zh-Hans', 'en-US'],
        aiStrategy: AiSubtitleStrategy.excludeAi,
      );
      expect(chosen.length, 1);
      expect(chosen.single.lan, 'en');
    });

    test('只要 AI：人工字幕被排除', () {
      final chosen = SubtitleLanguage.select(
        <SubtitleItem>[ai('zh-CN'), human('zh-Hans')],
        <String>['zh-Hans'],
        aiStrategy: AiSubtitleStrategy.onlyAi,
      );
      expect(chosen.single.isAi, isTrue);
    });

    test('只要 AI：没有 AI 时返回空', () {
      final chosen = SubtitleLanguage.select(
        <SubtitleItem>[human('zh-Hans')],
        <String>['zh-Hans'],
        aiStrategy: AiSubtitleStrategy.onlyAi,
      );
      expect(chosen, isEmpty);
    });

    test('策略枚举的名称往返', () {
      for (final strategy in AiSubtitleStrategy.values) {
        expect(AiSubtitleStrategy.fromName(strategy.name), strategy);
      }
      expect(
          AiSubtitleStrategy.fromName('不存在'), AiSubtitleStrategy.preferHuman);
      expect(AiSubtitleStrategy.fromName(null), AiSubtitleStrategy.preferHuman);
    });
  });

  group('FfmpegOps.metadata 元数据注入', () {
    test('视频 + 封面：封面是第二条视频轨（v:1）', () {
      final args = FfmpegOps.metadata(
        input: 'in.mp4',
        output: 'out.mp4',
        title: '标题',
        artist: 'UP主',
        coverPath: 'cover.jpg',
        hasVideo: true,
      );
      expect(args.where((item) => item == '-i').length, 2);
      expect(args[args.indexOf('-map') + 1], '0');
      expect(args[args.lastIndexOf('-map') + 1], '1:0');
      expect(args[args.indexOf('-c') + 1], 'copy');
      expect(args[args.indexOf('-disposition:v:1')], '-disposition:v:1');
      expect(args[args.indexOf('-disposition:v:1') + 1], 'attached_pic');
      expect(args, contains('-disposition:v:1'));
      expect(args.contains('-disposition:v:0'), isFalse);
    });

    test('纯音频 + 封面：封面是第一条视频轨（v:0）', () {
      final args = FfmpegOps.metadata(
        input: 'in.m4a',
        output: 'out.m4a',
        coverPath: 'cover.jpg',
        hasVideo: false,
      );
      expect(args, contains('-disposition:v:0'));
      expect(args.contains('-disposition:v:1'), isFalse);
    });

    test('没有封面：单输入、无 disposition', () {
      final args = FfmpegOps.metadata(
        input: 'in.mp4',
        output: 'out.mp4',
        title: '标题',
      );
      expect(args.where((item) => item == '-i').length, 1);
      expect(args.contains('-disposition:v:1'), isFalse);
      expect(args.contains('-disposition:v:0'), isFalse);
    });

    test('空封面路径等同没有封面', () {
      final args = FfmpegOps.metadata(
        input: 'in.mp4',
        output: 'out.mp4',
        coverPath: '',
      );
      expect(args.where((item) => item == '-i').length, 1);
    });

    test('元数据键值与位置', () {
      final args = FfmpegOps.metadata(
        input: 'in.mp4',
        output: 'out.mp4',
        title: '我的视频',
        artist: '某UP主',
      );
      final indexes = <int>[
        for (var i = 0; i < args.length; i++)
          if (args[i] == '-metadata') i,
      ];
      expect(indexes.length, 2);
      expect(args[indexes[0] + 1], 'title=我的视频');
      expect(args[indexes[1] + 1], 'artist=某UP主');
      expect(args.last, 'out.mp4');
    });

    test('空标题 / 空 UP 主不产出 metadata 参数', () {
      final args = FfmpegOps.metadata(
        input: 'in.mp4',
        output: 'out.mp4',
        title: '',
        artist: '',
      );
      expect(args.contains('-metadata'), isFalse);
    });

    test('必须无损且 moov 前置', () {
      final args = FfmpegOps.metadata(input: 'a', output: 'b', title: 't');
      expect(args[args.indexOf('-c') + 1], 'copy');
      expect(args[args.indexOf('-movflags') + 1], '+faststart');
      expect(args.where((item) => item == '-c').length, 1);
    });
  });
}
