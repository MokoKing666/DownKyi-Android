import 'package:downkyi/download/speed_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeedLimiter', () {
    test('不限速（0）时恒不等待', () {
      final limiter = SpeedLimiter(0);
      expect(limiter.enabled, isFalse);
      expect(limiter.consume(1024 * 1024), Duration.zero);
    });

    test('配额内不等待，超出配额等到下一秒窗口', () {
      var now = DateTime.fromMillisecondsSinceEpoch(10000);
      final limiter = SpeedLimiter(
        1000,
        now: () => now,
      );

      // 窗口内吃满 1000 字节：不等待
      expect(limiter.consume(600), Duration.zero);
      expect(limiter.consume(400), Duration.zero);
      // 第 1100 字节超出配额：等到窗口结束（还剩 1000ms）
      expect(limiter.consume(100), const Duration(milliseconds: 1000));

      // 时间前进到下一个窗口：重新计数
      now = now.add(const Duration(milliseconds: 1000));
      expect(limiter.consume(1000), Duration.zero);
    });

    test('同一窗口内多次超额的等待时间单调收敛到窗口末尾', () {
      final now = DateTime.fromMillisecondsSinceEpoch(5000).add(
        const Duration(milliseconds: 400),
      );
      final limiter = SpeedLimiter(1000, now: () => now);

      expect(limiter.consume(1000), Duration.zero);
      // 时钟固定不动：窗口从首次记账时刻（5400ms）起算，
      // 超额后等到窗口末尾，即 1000ms
      expect(limiter.consume(1), const Duration(milliseconds: 1000));
      expect(limiter.consume(1), const Duration(milliseconds: 1000));
    });

    test('负数与零字节记账无副作用', () {
      final limiter = SpeedLimiter(1000);
      expect(limiter.consume(0), Duration.zero);
      expect(limiter.consume(-5), Duration.zero);
      expect(limiter.consume(500), Duration.zero);
    });
  });
}
