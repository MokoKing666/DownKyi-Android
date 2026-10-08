import 'dart:convert';

import 'package:crypto/crypto.dart';

/// B 站 WBI 签名。
///
/// 算法来自官方前端：把 img_key 与 sub_key 拼接后按固定表重排取前 32 位作为 mixinKey，
/// 请求参数加上 wts 并按 key 排序拼成 query，最后 `w_rid = md5(query + mixinKey)`。
class WbiSigner {
  static const List<int> _mixinKeyEncTab = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  String? _imgKey;
  String? _subKey;

  bool get ready => _mixinKey != null;

  /// 用 `/x/web-interface/nav` 返回的 wbi_img 刷新密钥
  void updateKeys(String? imgUrl, String? subUrl) {
    _imgKey = _fileName(imgUrl);
    _subKey = _fileName(subUrl);
  }

  void clear() {
    _imgKey = null;
    _subKey = null;
  }

  static String? _fileName(String? url) {
    if (url == null || url.isEmpty) return null;
    final name = url.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String? get _mixinKey {
    final img = _imgKey;
    final sub = _subKey;
    if (img == null || sub == null) return null;
    final raw = img + sub;
    if (raw.length < 64) return null;
    final buffer = StringBuffer();
    for (final index in _mixinKeyEncTab) {
      buffer.write(raw[index]);
    }
    final key = buffer.toString();
    return key.length >= 32 ? key.substring(0, 32) : key;
  }

  /// 返回带 wts / w_rid 的完整参数
  ///
  /// [wts] 只用于测试注入固定时间戳，正式调用留空取当前秒级时间。
  Map<String, String> sign(Map<String, String> params, {int? wts}) {
    final signed = Map<String, String>.from(params);
    signed['wts'] =
        (wts ?? DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final key = _mixinKey;
    if (key == null) return signed;

    final keys = signed.keys.toList()..sort();
    final query = keys.map((k) {
      final value = signed[k]!.replaceAll(RegExp(r"[!'()*]"), '');
      return '${Uri.encodeComponent(k)}=${Uri.encodeComponent(value)}';
    }).join('&');
    signed['w_rid'] = md5.convert(utf8.encode('$query$key')).toString();
    return signed;
  }
}
