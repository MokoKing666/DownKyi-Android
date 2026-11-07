import 'package:downkyi/bili/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 链接识别测试。
///
/// 这是整个解析链路的入口：识别错一个类型，后面就会拿错误的参数去请求接口，
/// 或者把「合集」当成「收藏夹」去解析。文档要求覆盖
/// BV / av / b23 / ep / ss / 合集 / 收藏夹 / UP主 全部形态。
void main() {
  group('视频', () {
    test('标准 BV 链接', () {
      final link = parseLink('https://www.bilibili.com/video/BV1xx411c7mD');
      expect(link.kind, LinkKind.video);
      expect(link.id, 'BV1xx411c7mD');
      expect(link.isSupported, isTrue);
    });

    test('裸 BV 号', () {
      expect(parseLink('BV1xx411c7mD').kind, LinkKind.video);
      expect(parseLink('BV1xx411c7mD').id, 'BV1xx411c7mD');
    });

    test('带分 P 的链接会带出页码', () {
      final link = parseLink('https://www.bilibili.com/video/BV1xx411c7mD?p=3');
      expect(link.kind, LinkKind.video);
      expect(link.page, 3);
    });

    test('p 参数在其它参数之前也能识别', () {
      expect(
          parseLink('https://www.bilibili.com/video/BV1xx411c7mD?p=12&t=5')
              .page,
          12);
    });

    test('av 号', () {
      final link = parseLink('https://www.bilibili.com/video/av170001');
      expect(link.kind, LinkKind.video);
      expect(link.id, 'av170001');
    });

    test('av 号大小写不敏感', () {
      expect(
          parseLink('https://www.bilibili.com/video/AV170001').id, 'av170001');
    });
  });

  group('短链', () {
    test('b23.tv', () {
      final link = parseLink('https://b23.tv/abc123');
      expect(link.kind, LinkKind.shortLink);
      expect(link.id, 'abc123');
    });

    test('bili2233.cn', () {
      final link = parseLink('https://bili2233.cn/xyz789');
      expect(link.kind, LinkKind.shortLink);
      expect(link.id, 'xyz789');
    });

    test('短链优先于内部其它形态判定', () {
      // 短链文本里若偶然出现可被其它正则命中的片段，也必须判为短链——
      // 因为只有跟随跳转才知道真实目标。
      final link = parseLink('https://b23.tv/av123');
      expect(link.kind, LinkKind.shortLink);
      expect(link.id, 'av123');
    });
  });

  group('番剧 / 课程', () {
    test('ep 单集', () {
      final link = parseLink('https://www.bilibili.com/bangumi/play/ep123456');
      expect(link.kind, LinkKind.bangumiEp);
      expect(link.id, '123456');
    });

    test('ss 整季', () {
      final link = parseLink('https://www.bilibili.com/bangumi/play/ss12345');
      expect(link.kind, LinkKind.bangumiSeason);
      expect(link.id, '12345');
    });

    test('课程 ep 归到 cheese', () {
      final link = parseLink('https://www.bilibili.com/cheese/play/ep123');
      expect(link.kind, LinkKind.cheese);
      expect(link.id, '123');
    });

    test('课程 ss 归到 cheese', () {
      final link = parseLink('https://www.bilibili.com/cheese/play/ss456');
      expect(link.kind, LinkKind.cheese);
      expect(link.id, '456');
    });

    test('pugv 域名也算课程', () {
      expect(parseLink('https://www.bilibili.com/pugv/play/ep789').kind,
          LinkKind.cheese);
    });
  });

  group('收藏夹', () {
    test('favlist?fid=', () {
      final link = parseLink('https://space.bilibili.com/123/favlist?fid=456');
      expect(link.kind, LinkKind.favorites);
      expect(link.id, '456');
    });

    test('media_id', () {
      expect(
        parseLink(
                'https://www.bilibili.com/medialist/detail/ml123?media_id=789')
            .id,
        '789',
      );
    });

    test('fav_id', () {
      expect(parseLink('https://x/?fav_id=321').id, '321');
    });

    test('纯数字视为收藏夹 id', () {
      final link = parseLink('12345');
      expect(link.kind, LinkKind.favorites);
      expect(link.id, '12345');
    });

    test('太短的纯数字不算收藏夹', () {
      expect(parseLink('123').kind, LinkKind.unknown);
    });
  });

  group('UP 主与合集', () {
    test('空间主页', () {
      final link = parseLink('https://space.bilibili.com/123456');
      expect(link.kind, LinkKind.space);
      expect(link.id, '123456');
    });

    test('空间主页带查询参数', () {
      expect(
          parseLink('https://space.bilibili.com/123456?spm_id_from=333').kind,
          LinkKind.space);
    });

    test('合集使用 mid:seasonId 作为 id', () {
      final link =
          parseLink('https://space.bilibili.com/123/lists/456?type=season');
      expect(link.kind, LinkKind.season);
      expect(link.id, '123:456');
    });

    test('合集判定优先于空间主页', () {
      // 合集链接里也含 space.bilibili.com/<mid>，
      // 若判定顺序反过来会被当成 UP 主主页，从而漏掉这个合集。
      expect(parseLink('https://space.bilibili.com/123/lists/456').kind,
          LinkKind.season);
    });
  });

  group('未识别', () {
    test('空串', () {
      expect(parseLink('').kind, LinkKind.unknown);
      expect(parseLink('   ').kind, LinkKind.unknown);
    });

    test('普通文本', () {
      final link = parseLink('随便一段文字');
      expect(link.kind, LinkKind.unknown);
      expect(link.isSupported, isFalse);
      expect(link.describe, '未识别的链接');
    });

    test('其它站点链接', () {
      expect(parseLink('https://www.youtube.com/watch?v=abc').kind,
          LinkKind.unknown);
    });
  });

  group('describe', () {
    test('各类型都有可读描述', () {
      expect(parseLink('BV1xx411c7mD').describe, contains('视频'));
      expect(parseLink('https://b23.tv/a1').describe, contains('短链'));
      expect(parseLink('https://www.bilibili.com/bangumi/play/ep1').describe,
          contains('ep1'));
      expect(parseLink('https://www.bilibili.com/bangumi/play/ss2').describe,
          contains('ss2'));
    });
  });
}
