/// 各类格式化工具。
library;

String formatDuration(int milliseconds) {
  if (milliseconds <= 0) return '00:00';
  final total = milliseconds ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
}

String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 B/s';
  return '${formatBytes(bytesPerSecond)}/s';
}

String formatEta(int seconds) {
  if (seconds <= 0) return '--';
  if (seconds < 60) return '$seconds 秒';
  if (seconds < 3600) return '${seconds ~/ 60} 分 ${seconds % 60} 秒';
  return '${seconds ~/ 3600} 时 ${(seconds % 3600) ~/ 60} 分';
}

String formatCount(int count) {
  if (count >= 100000000) return '${(count / 100000000).toStringAsFixed(1)} 亿';
  if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)} 万';
  return count.toString();
}

String formatDate(int secondsSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

/// 去掉文件名里的非法字符，避免在 Android 上写文件失败。
String sanitizeFileName(String raw, {int maxLength = 80}) {
  var name = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Windows/Android 都忌讳结尾的点和空格
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'video';
  if (name.length > maxLength) {
    name = name.substring(0, maxLength).trim();
  }
  return name;
}
