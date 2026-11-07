import 'package:downkyi/bili/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDurationMs', () {
    test('小整数按秒处理', () {
      expect(parseDurationMs(30), 30000);
    });

    test('大整数按毫秒处理', () {
      expect(parseDurationMs(125000), 125000);
    });

    test('数字字符串按秒处理', () {
      expect(parseDurationMs('45'), 45000);
    });

    test('冒号时长 mm:ss', () {
      expect(parseDurationMs('5:32'), (5 * 60 + 32) * 1000);
    });

    test('冒号时长 h:mm:ss', () {
      expect(parseDurationMs('1:02:03'), (3600 + 120 + 3) * 1000);
    });

    test('非法输入返回 0', () {
      expect(parseDurationMs(null), 0);
      expect(parseDurationMs(''), 0);
      expect(parseDurationMs('abc'), 0);
      expect(parseDurationMs('a:b:c'), 0);
    });
  });

  group('MediaItem 合集条目识别（对应桌面版 publication 识别）', () {
    test('带 meta 与 season_id 的条目是合集：标题/封面/集数取自 meta', () {
      final item = MediaItem.fromJson(<String, dynamic>{
        'bvid': 'BV1xx',
        'aid': 100,
        'title': '代表视频标题',
        'pic': '//video-cover',
        'duration': '1:30',
        'season_id': 99,
        'meta': <String, dynamic>{
          'title': '合集标题',
          'cover': '//collection-cover',
          'ep_count': 26,
          'mid': 42,
        },
      });

      expect(item.isCollection, isTrue);
      expect(item.seasonId, 99);
      expect(item.title, '合集标题');
      expect(item.cover, 'https://collection-cover');
      expect(item.epCount, 26);
    });

    test('普通视频条目不受影响，冒号时长正确解析', () {
      final item = MediaItem.fromJson(<String, dynamic>{
        'bvid': 'BV1yy',
        'aid': 200,
        'title': '普通视频',
        'pic': '//cover',
        'duration': '4:18',
        'author': '某UP',
      });

      expect(item.isCollection, isFalse);
      expect(item.seasonId, 0);
      expect(item.title, '普通视频');
      expect(item.durationMs, (4 * 60 + 18) * 1000);
      expect(item.ownerName, '某UP');
    });

    test('copyWith 保留合集信息', () {
      const item = MediaItem(
        bvid: 'BV1zz',
        cid: 0,
        aid: 300,
        title: '合集',
        cover: '',
        seasonId: 7,
        epCount: 12,
      );
      final copy = item.copyWith(selected: false);
      expect(copy.isCollection, isTrue);
      expect(copy.seasonId, 7);
      expect(copy.epCount, 12);
      expect(copy.selected, isFalse);
    });
  });
}
