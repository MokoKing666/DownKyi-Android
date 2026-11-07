import 'package:flutter/foundation.dart';

/// 轻量日志：保留最近 300 条，便于在「设置 - 运行日志」里排查问题。
class AppLog {
  AppLog._();

  static final List<String> _lines = <String>[];

  static List<String> get lines => List.unmodifiable(_lines);

  static void d(String tag, Object? message) {
    _append('D', tag, message);
  }

  static void e(String tag, Object? message, [Object? error]) {
    _append('E', tag, error == null ? message : '$message | $error');
  }

  static void clear() => _lines.clear();

  static void _append(String level, String tag, Object? message) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final text = redact('$message');
    _lines.add('$time [$level][$tag] $text');
    if (_lines.length > 300) {
      _lines.removeRange(0, _lines.length - 300);
    }
    if (kDebugMode) {
      debugPrint('[$level][$tag] $text');
    }
  }

  /// 会在日志里出现即视为泄露的字段名
  static const List<String> sensitiveNames = <String>[
    'SESSDATA',
    'bili_jct',
    'DedeUserID',
    'buvid3',
    'aria2Secret',
    'rpc-secret',
    'access_token',
    'refresh_token',
    'csrf',
  ];

  /// 日志脱敏。
  ///
  /// 「设置 - 运行日志」是给用户排查问题用的，而用户遇到问题时的第一反应
  /// 就是把日志贴进 issue。Cookie 一旦泄露就等于账号被拿走——
  /// `SESSDATA` 可以直接调用任意已登录接口，不需要密码、不需要二次验证。
  ///
  /// 所以任何写进日志的内容都要先过这一道：命中敏感字段名时，
  /// 值只保留前 4 位（够用来比对「换没换过」），其余替换成 `****`。
  static String redact(String input) {
    var result = input;
    for (final name in sensitiveNames) {
      result = result.replaceAllMapped(
        RegExp(
          '($name["\']?\\s*[:=]\\s*"?)([^;,"\\s&]{4})[^;,"\\s&]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}${match.group(2)}****',
      );
    }
    return result;
  }
}
