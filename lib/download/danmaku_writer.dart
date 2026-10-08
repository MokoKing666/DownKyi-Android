import 'package:flutter/foundation.dart';

import '../bili/models.dart';

/// 弹幕 ASS 的样式参数（评审第 22 项）。
///
/// 这些值此前全部写死在代码里：字号 40、8 秒滚完、铺满画面 3/4 高度、完全不透明。
/// 但「看清弹幕」和「看清画面」天然矛盾——手机上 40 号字在 1080P 里偏小，
/// 而铺满整屏在 4K 片源里根本没法看。所以做成可调参数，并落到设置里。
@immutable
class DanmakuStyle {
  const DanmakuStyle({
    this.fontScale = 1.0,
    this.opacity = 1.0,
    this.scrollDurationMs = 8000,
    this.staticDurationMs = 4000,
    this.laneRatio = 0.75,
    this.fontName = '黑体',
    this.fontSizeOverride,
    this.outline = 1.0,
    this.shadow = 0.0,
    this.enableScroll = true,
    this.enableTop = true,
    this.enableBottom = true,
  });

  /// 字号缩放（相对基准字号）
  final double fontScale;

  /// 不透明度，1 = 完全不透明
  final double opacity;

  /// 滚动弹幕穿过屏幕的时长，越大越慢
  final int scrollDurationMs;

  /// 顶部/底部弹幕停留时长
  final int staticDurationMs;

  /// 弹幕最多铺满画面高度的比例
  final double laneRatio;

  final String fontName;

  /// 直接指定字号（优先于 [fontScale]）
  final int? fontSizeOverride;

  /// 描边粗细
  final double outline;

  /// 阴影
  final double shadow;

  final bool enableScroll;
  final bool enableTop;
  final bool enableBottom;

  int get fontSize =>
      fontSizeOverride ?? (DanmakuWriter.baseFontSize * fontScale).round();

  /// ASS 的透明度是「反过来的 alpha」：00 = 不透明，FF = 全透明
  int get alphaByte =>
      (((1 - opacity.clamp(0.0, 1.0)) * 255).round()).clamp(0, 255);

  String get alphaHex =>
      alphaByte.toRadixString(16).padLeft(2, '0').toUpperCase();

  /// 给界面用的可读摘要
  String get summary {
    final parts = <String>[
      '字号 ${fontSize}',
      '不透明度 ${(opacity * 100).round()}%',
      '滚动 ${(scrollDurationMs / 1000).toStringAsFixed(1)} 秒',
      '占屏 ${(laneRatio * 100).round()}%',
    ];
    return parts.join(' · ');
  }

  DanmakuStyle copyWith({
    double? fontScale,
    double? opacity,
    int? scrollDurationMs,
    double? laneRatio,
    double? outline,
    double? shadow,
    bool? enableScroll,
    bool? enableTop,
    bool? enableBottom,
  }) =>
      DanmakuStyle(
        fontScale: fontScale ?? this.fontScale,
        opacity: opacity ?? this.opacity,
        scrollDurationMs: scrollDurationMs ?? this.scrollDurationMs,
        staticDurationMs: staticDurationMs,
        laneRatio: laneRatio ?? this.laneRatio,
        fontName: fontName,
        fontSizeOverride: fontSizeOverride,
        outline: outline ?? this.outline,
        shadow: shadow ?? this.shadow,
        enableScroll: enableScroll ?? this.enableScroll,
        enableTop: enableTop ?? this.enableTop,
        enableBottom: enableBottom ?? this.enableBottom,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'fontScale': fontScale,
        'opacity': opacity,
        'scrollDurationMs': scrollDurationMs,
        'laneRatio': laneRatio,
        'outline': outline,
        'shadow': shadow,
        'enableScroll': enableScroll,
        'enableTop': enableTop,
        'enableBottom': enableBottom,
      };

  static DanmakuStyle fromJson(Map<String, Object?> json) => DanmakuStyle(
        fontScale: _double(json['fontScale'], 1.0),
        opacity: _double(json['opacity'], 1.0),
        scrollDurationMs: _int(json['scrollDurationMs'], 8000),
        laneRatio: _double(json['laneRatio'], 0.75),
        outline: _double(json['outline'], 1.0),
        shadow: _double(json['shadow'], 0.0),
        enableScroll: json['enableScroll'] != false,
        enableTop: json['enableTop'] != false,
        enableBottom: json['enableBottom'] != false,
      );

  static double _double(Object? raw, double fallback) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? fallback;
    return fallback;
  }

  static int _int(Object? raw, int fallback) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }
}

/// 弹幕转换：protobuf 弹幕 -> XML / ASS / TXT。
///
/// ASS 采用「滚动弹幕用 \move、顶部底部用 \pos」的方案，字色随弹幕自带颜色，
/// 是 DownKyi 里 Danmaku2Ass 的精简版实现。
class DanmakuWriter {
  const DanmakuWriter._();

  static const int playResX = 1920;
  static const int playResY = 1080;

  /// 基准字号（1.0 倍缩放时的大小）
  static const int baseFontSize = 40;

  /// 兼容旧调用点
  static const int fontSize = baseFontSize;

  static String toXml(List<DanmakuItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<i>');
    buffer.writeln('  <chatserver>chat.bilibili.com</chatserver>');
    buffer.writeln('  <chatid>0</chatid>');
    buffer.writeln('  <mission>0</mission>');
    buffer.writeln('  <maxlimit>${items.length}</maxlimit>');
    buffer.writeln('  <source>k-v</source>');
    for (final item in items) {
      final seconds = (item.progressMs / 1000).toStringAsFixed(2);
      buffer.writeln(
        '  <d p="$seconds,${item.mode},${item.fontSize},${item.color},0,0,0,0">'
        '${_escapeXml(item.content)}</d>',
      );
    }
    buffer.writeln('</i>');
    return buffer.toString();
  }

  static String toText(List<DanmakuItem> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.writeln('[${_formatClock(item.progressMs)}] ${item.content}');
    }
    return buffer.toString();
  }

  static String toAss(
    List<DanmakuItem> items, {
    String title = '弹幕',
    DanmakuStyle style = const DanmakuStyle(),
  }) {
    final size = style.fontSize;
    final laneHeight = size + 8;
    final maxLane =
        ((playResY * style.laneRatio) / laneHeight).floor().clamp(1, 200);

    final buffer = StringBuffer();
    buffer.writeln('[Script Info]');
    buffer.writeln('Title: $title');
    buffer.writeln('ScriptType: v4.00+');
    buffer.writeln('Collisions: Normal');
    buffer.writeln('PlayResX: $playResX');
    buffer.writeln('PlayResY: $playResY');
    buffer.writeln('WrapStyle: 2');
    buffer.writeln('ScaledBorderAndShadow: yes');
    buffer.writeln('Timer: 100.0000');
    buffer.writeln();
    buffer.writeln('[V4+ Styles]');
    buffer.writeln(
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, '
      'BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, '
      'BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    );
    // PrimaryColour / OutlineColour 都带上 alpha，透明度设置才真正生效
    buffer.writeln(
      'Style: Danmaku,${style.fontName},$size,'
      '&H${style.alphaHex}FFFFFF,&H${style.alphaHex}FFFFFF,'
      '&H00000000,&H00000000,'
      '0,0,0,0,100,100,0,0,1,${style.outline},${style.shadow},7,0,0,0,1',
    );
    buffer.writeln();
    buffer.writeln('[Events]');
    buffer.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    final scrollLanes = List<int>.filled(maxLane, 0);
    final topLanes = List<int>.filled(maxLane, 0);
    final bottomLanes = List<int>.filled(maxLane, 0);

    for (final item in items) {
      final content = _escapeAss(item.content);
      if (content.isEmpty) continue;
      final start = item.progressMs;
      final color = _colorTag(item.color);

      if (item.mode == 5 && style.enableTop) {
        final lane = _pickLane(topLanes, start);
        topLanes[lane] = start + style.staticDurationMs;
        final y = lane * laneHeight + laneHeight ~/ 2;
        buffer.writeln(_dialogue(
          start,
          start + style.staticDurationMs,
          '{\\an8\\pos(${playResX ~/ 2},$y)$color}$content',
        ));
      } else if (item.mode == 4 && style.enableBottom) {
        final lane = _pickLane(bottomLanes, start);
        bottomLanes[lane] = start + style.staticDurationMs;
        final y = playResY - lane * laneHeight - laneHeight ~/ 2;
        buffer.writeln(_dialogue(
          start,
          start + style.staticDurationMs,
          '{\\an2\\pos(${playResX ~/ 2},$y)$color}$content',
        ));
      } else if (style.enableScroll) {
        final lane = _pickLane(scrollLanes, start);
        scrollLanes[lane] = start + style.scrollDurationMs;
        final y = lane * laneHeight + laneHeight ~/ 2;
        final width = _textWidth(content, size);
        buffer.writeln(_dialogue(
          start,
          start + style.scrollDurationMs,
          '{\\move($playResX,$y,${-width.toInt()},$y,0,${style.scrollDurationMs})$color}$content',
        ));
      }
    }
    return buffer.toString();
  }

  static String _dialogue(int startMs, int endMs, String text) {
    return 'Dialogue: 0,${_formatAssTime(startMs)},${_formatAssTime(endMs)},Danmaku,,0,0,0,,$text';
  }

  /// 选择最早空闲的轨道
  static int _pickLane(List<int> lanes, int startMs) {
    var best = 0;
    for (var index = 0; index < lanes.length; index++) {
      if (lanes[index] <= startMs) return index;
      if (lanes[index] < lanes[best]) best = index;
    }
    return best;
  }

  /// ASS 颜色为 &HAABBGGRR
  static String _colorTag(int rgb) {
    if (rgb == 0xFFFFFF) return '';
    final red = (rgb >> 16) & 0xFF;
    final green = (rgb >> 8) & 0xFF;
    final blue = rgb & 0xFF;
    String hex(int value) =>
        value.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '\\c&H${hex(blue)}${hex(green)}${hex(red)}&';
  }

  static double _textWidth(String text, int size) {
    var units = 0.0;
    for (final rune in text.runes) {
      units += rune > 0x2E80 ? 1.0 : 0.55;
    }
    return units * size;
  }

  static String _escapeAss(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('{', '（')
      .replaceAll('}', '）')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .trim();

  static String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _formatAssTime(int milliseconds) {
    final value = milliseconds < 0 ? 0 : milliseconds;
    final centisecond = (value % 1000) ~/ 10;
    final totalSeconds = value ~/ 1000;
    final second = totalSeconds % 60;
    final minute = (totalSeconds ~/ 60) % 60;
    final hour = totalSeconds ~/ 3600;
    return '$hour:${_two(minute)}:${_two(second)}.${_two(centisecond)}';
  }

  static String _formatClock(int milliseconds) {
    final value = milliseconds < 0 ? 0 : milliseconds;
    final totalSeconds = value ~/ 1000;
    return '${_two(totalSeconds ~/ 3600)}:${_two((totalSeconds ~/ 60) % 60)}:${_two(totalSeconds % 60)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
