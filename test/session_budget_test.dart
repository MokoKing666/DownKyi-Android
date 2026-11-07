import 'package:downkyi/download/download_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// 前台服务时长预算测试。
///
/// 背景：Android 15 起 `dataSync` 前台服务有「24 小时滚动窗口内累计约 6 小时」的
/// 运行时上限，超额后系统直接停服务并杀进程。这里的逻辑负责在额度内主动收手，
/// 而不是等系统随机杀——对「晚上挂机下 4K」这种场景，差别就是
/// 「早上起来看到一条解释」和「早上起来发现只下了一半、毫无头绪」。
void main() {
  final base = DateTime(2026, 10, 8, 22);

  ForegroundBudget build() => ForegroundBudget(
        limit: const Duration(hours: 6),
        warnRatio: 0.8,
        window: const Duration(hours: 24),
      );

  group('累计与比例', () {
    test('初始状态为零', () {
      final budget = build();
      expect(budget.used, Duration.zero);
      expect(budget.ratio, 0);
      expect(budget.warned, isFalse);
      expect(budget.exhausted, isFalse);
      expect(budget.remaining, const Duration(hours: 6));
    });

    test('consume 会累加', () {
      final budget = build()
        ..consume(const Duration(hours: 1), now: base)
        ..consume(const Duration(hours: 2),
            now: base.add(const Duration(hours: 2)));
      expect(budget.used, const Duration(hours: 3));
      expect(budget.remaining, const Duration(hours: 3));
    });

    test('ratio 按限额折算且封顶为 1', () {
      final budget = build()..consume(const Duration(hours: 3), now: base);
      expect(budget.ratio, closeTo(0.5, 1e-9));

      budget.consume(const Duration(hours: 10),
          now: base.add(const Duration(hours: 4)));
      expect(budget.ratio, 1);
    });

    test('非正数增量被忽略（计时器抖动不该虚增额度消耗）', () {
      final budget = build()
        ..consume(Duration.zero, now: base)
        ..consume(const Duration(seconds: -5), now: base);
      expect(budget.used, Duration.zero);
    });

    test('限额为 0 时不除零', () {
      final budget = ForegroundBudget(limit: Duration.zero);
      budget.consume(const Duration(minutes: 1), now: base);
      expect(budget.ratio, 0);
      expect(budget.exhausted, isTrue);
    });
  });

  group('阈值', () {
    test('达到 80% 时进入提醒状态', () {
      final budget = build()
        ..consume(const Duration(hours: 4, minutes: 47), now: base);
      expect(budget.ratio, lessThan(0.8));
      expect(budget.warned, isFalse);

      budget.consume(const Duration(minutes: 2),
          now: base.add(const Duration(hours: 5)));
      expect(budget.warned, isTrue);
      expect(budget.exhausted, isFalse);
    });

    test('达到限额时判为用尽', () {
      final budget = build()..consume(const Duration(hours: 6), now: base);
      expect(budget.exhausted, isTrue);
      expect(budget.remaining, Duration.zero);
    });

    test('remaining 不会变成负数', () {
      final budget = build()..consume(const Duration(hours: 9), now: base);
      expect(budget.remaining, Duration.zero);
    });
  });

  group('窗口滚动', () {
    test('超过统计窗口后重新开窗', () {
      final budget = build()..consume(const Duration(hours: 5), now: base);
      expect(budget.used, const Duration(hours: 5));

      // 25 小时后再累加：系统按滚动窗口计算，旧的消耗已经滚出去了
      budget.consume(
        const Duration(minutes: 30),
        now: base.add(const Duration(hours: 25)),
      );
      expect(budget.used, const Duration(minutes: 30));
      expect(budget.exhausted, isFalse);
    });

    test('窗口内不会重置', () {
      final budget = build()..consume(const Duration(hours: 5), now: base);
      budget.consume(
        const Duration(minutes: 30),
        now: base.add(const Duration(hours: 23)),
      );
      expect(budget.used, const Duration(hours: 5, minutes: 30));
    });
  });

  group('空闲重置', () {
    test('空闲足够久后额度归零', () {
      final budget = build()..consume(const Duration(hours: 5), now: base);
      budget.idleReset(now: base.add(const Duration(hours: 2)));
      expect(budget.used, Duration.zero);
      expect(budget.exhausted, isFalse);
    });

    test('空闲不够久时不重置', () {
      final budget = build()..consume(const Duration(hours: 5), now: base);
      budget.idleReset(now: base.add(const Duration(minutes: 20)));
      expect(budget.used, const Duration(hours: 5));
    });

    test('从未活动过时 idleReset 是安全的空操作', () {
      final budget = build();
      budget.idleReset(now: base);
      expect(budget.used, Duration.zero);
    });
  });

  group('reset', () {
    test('手动重置清空全部状态', () {
      final budget = build()..consume(const Duration(hours: 6), now: base);
      expect(budget.exhausted, isTrue);
      budget.reset();
      expect(budget.used, Duration.zero);
      expect(budget.exhausted, isFalse);
      expect(budget.remaining, const Duration(hours: 6));
    });
  });
}
