import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:downkyi/core/wbi.dart';
import 'package:flutter_test/flutter_test.dart';

/// WBI 签名测试。
///
/// 为什么这份测试值得存在：WBI 那张 64 项重排表只要被误改一个数字，
/// 所有带 wbi 前缀的接口（搜索、合集、投稿、番剧季…）都会静默返回 -403，
/// 表现成「功能突然全挂了」，而且很难定位。
///
/// 这里刻意使用**外部来源**的期望值：官方文档给出的示例 img_key / sub_key 与
/// 据此算出的 mixinKey，而不是拿本实现的输出当基准自证。
void main() {
  // 官方文档示例密钥（来源：bilibili-API-collect）
  //   img_key   = 7cd084941338484aae1ad9425b84077c
  //   sub_key   = 4932caff0ff746eab6f01bf08b70ac45
  //   mixin_key = ea1db124af3c7062474693fa704f4ff8
  const imgUrl =
      'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png';
  const subUrl =
      'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png';
  const officialMixinKey = 'ea1db124af3c7062474693fa704f4ff8';

  /// 用官方 mixinKey 独立计算期望的 w_rid，
  /// 这样「排序 / 编码 / 非法字符过滤 / md5」这几步都被真实验证，
  /// 而不是在测试里重复一遍被测实现。
  String expectedRid(String query) =>
      md5.convert(utf8.encode('$query$officialMixinKey')).toString();

  WbiSigner readySigner() => WbiSigner()..updateKeys(imgUrl, subUrl);

  group('mixinKey 重排表', () {
    test('与官方测试向量一致', () {
      final signed =
          readySigner().sign(<String, String>{'foo': '114'}, wts: 1702204169);
      expect(signed['w_rid'], expectedRid('foo=114&wts=1702204169'));
    });

    test('换一组密钥后签名随之改变', () {
      final signed =
          readySigner().sign(<String, String>{'foo': '114'}, wts: 1702204169);
      final other = WbiSigner()
        ..updateKeys(
          'https://i0.hdslb.com/bfs/wbi/00000000000000000000000000000000.png',
          'https://i0.hdslb.com/bfs/wbi/11111111111111111111111111111111.png',
        );
      expect(
          other.sign(<String, String>{'foo': '114'}, wts: 1702204169)['w_rid'],
          isNot(signed['w_rid']));
    });
  });

  group('参数处理', () {
    test('参数顺序不影响结果（内部会排序）', () {
      final a = readySigner().sign(
        <String, String>{'foo': '114', 'bar': '514', 'zab': '1919810'},
        wts: 1702204169,
      );
      final b = readySigner().sign(
        <String, String>{'zab': '1919810', 'foo': '114', 'bar': '514'},
        wts: 1702204169,
      );
      expect(a['w_rid'], b['w_rid']);
      // 排序后应为 bar -> foo -> wts -> zab
      expect(a['w_rid'],
          expectedRid('bar=514&foo=114&wts=1702204169&zab=1919810'));
    });

    test('wts 参与签名', () {
      final s1 =
          readySigner().sign(<String, String>{'foo': '114'}, wts: 1702204169);
      final s2 =
          readySigner().sign(<String, String>{'foo': '114'}, wts: 1702204170);
      expect(s1['wts'], '1702204169');
      expect(s2['wts'], '1702204170');
      expect(s1['w_rid'], isNot(s2['w_rid']));
    });

    test('值里的 !\'()* 会被剔除（B 站前端的同名处理）', () {
      final dirty =
          readySigner().sign(<String, String>{'k': "a!'()*b"}, wts: 100);
      expect(dirty['w_rid'], expectedRid('k=ab&wts=100'));
    });

    test('中文与空格按 UTF-8 百分号编码', () {
      final signed = readySigner().sign(<String, String>{'k': '中文'}, wts: 100);
      expect(signed['w_rid'],
          expectedRid('k=${Uri.encodeComponent('中文')}&wts=100'));
    });

    test('空参数集合也能签出 wts 与 w_rid', () {
      final signed = readySigner().sign(<String, String>{}, wts: 100);
      expect(signed['wts'], '100');
      expect(signed['w_rid'], expectedRid('wts=100'));
    });

    test('不会修改调用方传入的 Map', () {
      final input = <String, String>{'foo': '114'};
      readySigner().sign(input, wts: 1);
      expect(input.containsKey('wts'), isFalse);
      expect(input.containsKey('w_rid'), isFalse);
    });
  });

  group('密钥未就绪', () {
    test('未 updateKeys 时只补 wts，不产出 w_rid', () {
      final signer = WbiSigner();
      expect(signer.ready, isFalse);
      final signed = signer.sign(<String, String>{'foo': '114'}, wts: 100);
      expect(signed['wts'], '100');
      expect(signed.containsKey('w_rid'), isFalse);
    });

    test('密钥长度不足时不产出 w_rid', () {
      final signer = WbiSigner()
        ..updateKeys('https://x/y/short.png', 'https://x/y/also.png');
      final signed = signer.sign(<String, String>{'foo': '114'}, wts: 100);
      expect(signed.containsKey('w_rid'), isFalse);
    });

    test('clear 之后回到未就绪', () {
      final signer = readySigner();
      expect(signer.ready, isTrue);
      signer.clear();
      expect(signer.ready, isFalse);
    });
  });

  group('密钥提取', () {
    test('从 URL 取文件名并去掉扩展名', () {
      // 去掉扩展名这点很关键：官方给的 wbi_img.img_url 是 .png 结尾，
      // 若把扩展名一起当密钥，签名会全部错误。
      final withExt = readySigner().sign(<String, String>{}, wts: 1);
      final noExt = WbiSigner()
        ..updateKeys(
          'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c',
          'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45',
        );
      expect(noExt.sign(<String, String>{}, wts: 1)['w_rid'], withExt['w_rid']);
    });
  });
}
