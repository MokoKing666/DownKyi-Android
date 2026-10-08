import '../bili/models.dart';

/// 弹幕转换：protobuf 弹幕 -> XML / ASS / TXT。
///
/// ASS 采用「滚动弹幕用 \move、顶部底部用 \pos」的方案，字色随弹幕自带颜色，
/// 是 DownKyi 里 Danmaku2Ass 的精简版实现。
class DanmakuWriter {
  const DanmakuWriter._();

  static const int playResX = 1920;
  static const int playResY = 1080;
  static const int fontSize = 40;
  static const int _scrollDurationMs = 8000;
  static const int _staticDurationMs = 4000;
  static const int _laneHeight = fontSize + 8;
  static const int _maxLane = (playResY * 3 ~/ 4) ~/ _laneHeight;

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
    bool enableTop = true,
    bool enableBottom = true,
    bool enableScroll = true,
  }) {
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
    buffer.writeln(
      'Style: Danmaku,黑体,$fontSize,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,'
      '0,0,0,0,100,100,0,0,1,1,0,7,0,0,0,1',
    );
    buffer.writeln();
    buffer.writeln('[Events]');
    buffer.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    final scrollLanes = List<int>.filled(_maxLane, 0);
    final topLanes = List<int>.filled(_maxLane, 0);
    final bottomLanes = List<int>.filled(_maxLane, 0);

    for (final item in items) {
      final content = _escapeAss(item.content);
      if (content.isEmpty) continue;
      final start = item.progressMs;
      final color = _colorTag(item.color);

      if (item.mode == 5 && enableTop) {
        final lane = _pickLane(topLanes, start);
        topLanes[lane] = start + _staticDurationMs;
        final y = lane * _laneHeight + _laneHeight ~/ 2;
        buffer.writeln(_dialogue(
          start,
          start + _staticDurationMs,
          '{\\an8\\pos(${playResX ~/ 2},$y)$color}$content',
        ));
      } else if (item.mode == 4 && enableBottom) {
        final lane = _pickLane(bottomLanes, start);
        bottomLanes[lane] = start + _staticDurationMs;
        final y = playResY - lane * _laneHeight - _laneHeight ~/ 2;
        buffer.writeln(_dialogue(
          start,
          start + _staticDurationMs,
          '{\\an2\\pos(${playResX ~/ 2},$y)$color}$content',
        ));
      } else if (enableScroll) {
        final lane = _pickLane(scrollLanes, start);
        scrollLanes[lane] = start + _scrollDurationMs;
        final y = lane * _laneHeight + _laneHeight ~/ 2;
        final width = _textWidth(content, fontSize);
        buffer.writeln(_dialogue(
          start,
          start + _scrollDurationMs,
          '{\\move($playResX,$y,${-width.toInt()},$y,0,$_scrollDurationMs)$color}$content',
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
