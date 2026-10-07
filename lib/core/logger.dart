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
    _lines.add('$time [$level][$tag] $message');
    if (_lines.length > 300) {
      _lines.removeRange(0, _lines.length - 300);
    }
    if (kDebugMode) {
      debugPrint('[$level][$tag] $message');
    }
  }
}
