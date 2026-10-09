import 'dart:async';

import '../core/logger.dart';
import '../data/download_task.dart';
import 'download_manager.dart';

/// 前台服务的运行时长预算。
///
/// Android 15 起，`dataSync` 类型的前台服务有**累计运行时间上限**
/// （24 小时滚动窗口内约 6 小时，实际额度由系统按应用活跃度分配）。
/// 超额后系统会直接停掉服务并杀掉进程——对「晚上挂机下 4K」这种场景是致命的：
/// 用户第二天早上发现只下了一半，而且没有任何解释。
///
/// 这里做的是**优雅降级**：接近上限时主动暂停并写明原因，而不是等系统在
/// 随机时刻把进程干掉。任务本身是断点续传的，暂停后下次接着下，不丢数据。
///
/// 之所以把它做成不依赖任何平台 API 的纯逻辑类，是因为这是本项改动里
/// 少数**不需要真机就能验证**的部分。
class ForegroundBudget {
  ForegroundBudget({
    this.limit = const Duration(hours: 6),
    this.warnRatio = 0.8,
    this.window = const Duration(hours: 24),
  });

  /// 系统给的累计额度
  final Duration limit;

  /// 到多少比例开始提醒
  final double warnRatio;

  /// 系统的统计窗口（滚动）
  final Duration window;

  Duration _used = Duration.zero;
  DateTime? _windowStart;
  DateTime? _lastActiveAt;

  Duration get used => _used;

  Duration get remaining {
    final left = limit - _used;
    return left.isNegative ? Duration.zero : left;
  }

  /// 已用比例，0~1
  double get ratio {
    if (limit.inMilliseconds <= 0) return 0;
    final value = _used.inMilliseconds / limit.inMilliseconds;
    if (value < 0) return 0;
    return value > 1 ? 1 : value;
  }

  bool get warned => ratio >= warnRatio;

  bool get exhausted => _used >= limit;

  /// 累加一段「服务在跑」的时长。
  ///
  /// [delta] 由调用方按两次 tick 的间隔给出；这里只负责累计与开窗。
  void consume(Duration delta, {DateTime? now}) {
    if (delta <= Duration.zero) return;
    final at = now ?? DateTime.now();
    _windowStart ??= at;
    _lastActiveAt = at;

    // 超出统计窗口就重新开窗（系统是按 24 小时滚动计算的）
    if (at.difference(_windowStart!) >= window) {
      _used = Duration.zero;
      _windowStart = at;
    }
    _used += delta;
  }

  /// 空闲时的处理：停了一段时间就认为额度已滚动，可以考虑重新开窗。
  void idleReset({DateTime? now, Duration idleFor = const Duration(hours: 1)}) {
    final at = now ?? DateTime.now();
    final last = _lastActiveAt;
    if (last == null) return;
    if (at.difference(last) >= idleFor) {
      _used = Duration.zero;
      _windowStart = null;
    }
  }

  void reset() {
    _used = Duration.zero;
    _windowStart = null;
    _lastActiveAt = null;
  }
}

/// 下载会话守护。
///
/// 把两件与「有没有某个页面活着」无关的事从 UI 里拿出来：
///
/// 1. **进程被杀后的恢复**。数据库里会残留 `status = running / merging` 的父任务，
///    但其实没有任何下载在跑。不处理的话 UI 会一直显示「下载中」却永远不动
///    （进度条卡住、按钮点了没反应），用户只能删掉重建。
///    启动时统一重新入队即可——分片文件还在，会从断点续传。
///
/// 2. **前台服务时长预算**。见 [ForegroundBudget]。
class DownloadSession {
  DownloadSession._();

  static final DownloadSession instance = DownloadSession._();

  /// 检查间隔。用 30 秒是为了让累计误差相对 6 小时额度可以忽略
  static const Duration tickInterval = Duration(seconds: 30);

  final ForegroundBudget budget = ForegroundBudget();

  DownloadManager? _manager;
  Timer? _timer;
  DateTime? _lastTick;

  bool _pausedByBudget = false;
  String? _pausedReason;

  /// 是否因为时长预算用尽而自动暂停
  bool get pausedByBudget => _pausedByBudget;

  /// 自动暂停的原因，供 UI 直接展示
  String? get pausedReason => _pausedReason;

  /// 把数据库里「看起来在下载、实际没在下载」的任务恢复起来。
  ///
  /// 按引擎区分处理：
  ///
  /// - **内置引擎**：重新入队，**保留分片**（断点续传）。
  ///   旧实现调 `retry()` 会把分片状态清空从头重下——那是对「恢复」的误解，
  ///   大文件被系统回收一次就前功尽弃。
  /// - **Aria2 引擎**：远端任务可能跑得好好的，本地重启与它无关。
  ///   用持久化的 gid 询问远端真实状态后再决定接管 / 收尾 / 标失败，
  ///   见 DownloadManager.recoverAria2Tasks。
  ///
  /// 返回恢复的内置任务数（aria2 的接管数由 manager 自己记日志）。
  /// 必须在任何下载开始之前调用。
  Future<int> recoverInterrupted(DownloadManager manager) async {
    var recovered = 0;
    for (final task in manager.tasks) {
      if (task.status != TaskStatus.running &&
          task.status != TaskStatus.merging) {
        continue;
      }
      if (task.engine.isNotEmpty && task.engine != 'builtin') continue;
      try {
        // 续传语义：不清分片、不清进度，重新入队即可——
        // SegmentDownloader 会按分片签名从断点继续。
        task.status = TaskStatus.queued;
        task.speed = 0;
        await manager.requeue(task);
        recovered++;
      } catch (error) {
        AppLog.e('Session', '恢复任务 ${task.id} 失败', error);
      }
    }

    // aria2 任务单独走「问远端」的恢复路径
    await manager.recoverAria2Tasks();

    if (recovered > 0) {
      AppLog.d('Session', '已恢复 $recovered 个被中断的内置任务（断点续传）');
    }
    return recovered;
  }

  void start(DownloadManager manager) {
    _manager = manager;
    _lastTick = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _manager = null;
    _lastTick = null;
  }

  /// 用户手动恢复下载时清掉预算暂停状态
  void clearBudgetPause() {
    _pausedByBudget = false;
    _pausedReason = null;
  }

  void _onTick() {
    final manager = _manager;
    if (manager == null) return;

    final now = DateTime.now();
    final last = _lastTick;
    _lastTick = now;
    final delta = last == null ? Duration.zero : now.difference(last);

    final active = manager.tasks.where((task) => task.isActive).length;
    if (active == 0) {
      budget.idleReset(now: now);
      return;
    }

    budget.consume(delta, now: now);

    if (budget.exhausted && !_pausedByBudget) {
      _pausedByBudget = true;
      _pausedReason = 'Android 对后台前台服务的累计运行时长有限制，'
          '本次额度已用尽（约 ${budget.limit.inHours} 小时），已自动暂停。'
          '稍后重新开始即可，已下载的分片会保留。';
      AppLog.e('Session', '前台服务时长额度用尽，已暂停全部任务');
      manager.pauseAll();
      return;
    }

    if (budget.warned && !_pausedByBudget) {
      AppLog.d(
        'Session',
        '前台服务时长已用 ${budget.used.inMinutes} 分钟 / '
            '限额 ${budget.limit.inMinutes} 分钟',
      );
    }
  }
}
