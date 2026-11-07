/// 下载限速器：按「每秒字节数」给内置下载器限速（对应桌面版的下载限速）。
///
/// 实现是「一秒窗口」的计数器：每消费一批字节就记账，超出本窗口配额时
/// 返回建议等待时长，调用方等完再取下一块。多线程分片共用同一个实例，
/// 于是限的是**整个任务**的总速度，而不是每个分片各限一份。
///
/// [bytesPerSecond] 为 0 表示不限速，[consume] 恒返回 [Duration.zero]。
/// 时钟可注入，便于单测精确断言而不依赖真实时间。
class SpeedLimiter {
  SpeedLimiter(this.bytesPerSecond, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final int bytesPerSecond;
  final DateTime Function() _now;

  int _windowStartMs = 0;
  int _windowUsed = 0;

  bool get enabled => bytesPerSecond > 0;

  /// 记账 [bytes] 字节，返回建议等待时长（超出当前秒的配额时 > 0）。
  Duration consume(int bytes) {
    if (bytesPerSecond <= 0 || bytes <= 0) return Duration.zero;
    final now = _now().millisecondsSinceEpoch;
    if (_windowStartMs == 0 || now - _windowStartMs >= 1000) {
      _windowStartMs = now;
      _windowUsed = 0;
    }
    _windowUsed += bytes;
    if (_windowUsed <= bytesPerSecond) return Duration.zero;
    return Duration(milliseconds: _windowStartMs + 1000 - now);
  }
}
