import 'package:downkyi/core/constants.dart';
import 'package:downkyi/download/download_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务唯一标识测试。
///
/// 文档验收标准：以下任务必须能够同时存在——
///   4K AVC / 4K HEVC / 4K AV1 / 不同音质 / 不同字幕配置 / 不同弹幕配置
///
/// 旧实现只用 bvid+cid+quality+flags，于是「同清晰度不同编码」被判成同一个任务，
/// 用户下完 HEVC 再想下 AVC 会被直接跳过（提示「任务已存在」）。
void main() {
  String key({
    String bvid = 'BV1xx411c7mD',
    int cid = 100,
    int? epId,
    int quality = 120,
    String codec = 'avc',
    int? audioId = 30280,
    int flags = 7,
    DanmakuFormat? danmaku,
    String subtitle = 'zh',
  }) =>
      DownloadManager.buildTaskKey(
        bvid: bvid,
        cid: cid,
        epId: epId,
        quality: quality,
        codec: codec,
        audioId: audioId,
        flags: flags,
        danmakuFormat: danmaku ?? DanmakuFormat.values.first,
        subtitleLanguage: subtitle,
      );

  group('格式', () {
    test('固定 32 位小写十六进制', () {
      final value = key();
      expect(value.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(value), isTrue);
    });

    test('同参数多次调用结果一致', () {
      expect(key(), key());
    });
  });

  group('文档验收标准：这些必须互不相同', () {
    test('同清晰度下的三种编码（AVC / HEVC / AV1）', () {
      final avc = key(codec: 'avc');
      final hevc = key(codec: 'hevc');
      final av1 = key(codec: 'av1');
      expect(<String>{avc, hevc, av1}.length, 3,
          reason: '4K AVC/HEVC/AV1 必须能同时存在');
    });

    test('不同音轨', () {
      final a = key(audioId: 30280);
      final b = key(audioId: 30232);
      expect(a, isNot(b));
    });

    test('未指定音轨 与 指定音轨 不同', () {
      expect(key(audioId: null), isNot(key(audioId: 30280)));
    });

    test('不同弹幕格式', () {
      final keys = <String>{
        for (final format in DanmakuFormat.values) key(danmaku: format),
      };
      expect(keys.length, DanmakuFormat.values.length, reason: '不同弹幕配置应能同时存在');
    });

    test('不同字幕语言', () {
      expect(key(subtitle: 'zh'), isNot(key(subtitle: 'en')));
    });

    test('不同清晰度', () {
      expect(key(quality: 120), isNot(key(quality: 80)));
    });

    test('不同下载内容组合（flags）', () {
      expect(key(flags: 7), isNot(key(flags: 3)));
    });

    test('不同 cid（同一稿件的不同分 P）', () {
      expect(key(cid: 100), isNot(key(cid: 101)));
    });
  });

  group('番剧', () {
    test('没有 bvid 时用 epid 区分', () {
      final ep1 = key(bvid: '', epId: 111);
      final ep2 = key(bvid: '', epId: 222);
      expect(ep1, isNot(ep2));
    });

    test('番剧条目与稿件条目不会撞车', () {
      expect(
          key(bvid: '', epId: 100), isNot(key(bvid: 'BV1xx411c7mD', cid: 100)));
    });

    test('epId 为 null 时也稳定', () {
      expect(key(bvid: '', epId: null), key(bvid: '', epId: null));
    });
  });

  group('组合唯一性', () {
    test('编码 × 音轨 × 弹幕 的组合全部不重复', () {
      final seen = <String>{};
      var total = 0;
      for (final codec in <String>['avc', 'hevc', 'av1']) {
        for (final audio in <int?>[null, 30280, 30232]) {
          for (final danmaku in DanmakuFormat.values) {
            seen.add(key(codec: codec, audioId: audio, danmaku: danmaku));
            total++;
          }
        }
      }
      expect(total, greaterThan(0));
      expect(seen.length, total, reason: '任一维度变化都应产生新任务');
    });
  });
}
