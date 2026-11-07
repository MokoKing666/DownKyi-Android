/// 任务启动节流（参考 BBDownT 的 `--delay-per-video`）。
///
/// 解决的问题：批量加入 10 个任务时，`_pump()` 会在同一瞬间把
/// 「解析 playurl → 探测 → 建分片」全部打出去。B 站对这种突发请求
/// 会触发风控（-412 / 403），表现为「批量下载时总有几个任务失败」。
///
/// 这里只控制**启动间隔**，不限制并发数（并发数由 `concurrentTasks` 管）。
/// 默认间隔为 0，即完全保持现状——这是一个只在需要时才打开的工具。
class StartThrottle {
  StartThrottle({this.intervalSeconds = 0});

  /// 两次任务启动之间的最小间隔（秒）。0 表示不限。
  int intervalSeconds;

  int? _lastMs;

  /// 当前时刻能否启动新任务；能则记录这次启动时间并返回 true。
  bool tryAcquire(int nowMs) {
    if (intervalSeconds <= 0) {
      _lastMs = nowMs;
      return true;
    }
    final last = _lastMs;
    if (last == null || nowMs - last >= intervalSeconds * 1000) {
      _lastMs = nowMs;
      return true;
    }
    return false;
  }

  /// 距下次允许启动还剩多少毫秒；已经可以启动时返回 0。
  int remainingMs(int nowMs) {
    if (intervalSeconds <= 0) return 0;
    final last = _lastMs;
    if (last == null) return 0;
    final wait = intervalSeconds * 1000 - (nowMs - last);
    return wait > 0 ? wait : 0;
  }
}
