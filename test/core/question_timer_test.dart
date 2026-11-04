import 'package:aralik/core/question_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 4, 9);

  group('timeLeft', () {
    test('counts down from the limit', () {
      expect(timeLeft(startedAt: start, now: start), dailyTimeLimit);
      expect(
        timeLeft(startedAt: start, now: start.add(const Duration(seconds: 4))),
        dailyTimeLimit - const Duration(seconds: 4),
      );
    });

    test('stops at zero', () {
      expect(
        timeLeft(startedAt: start, now: start.add(dailyTimeLimit)),
        Duration.zero,
      );
      expect(
        timeLeft(startedAt: start, now: start.add(const Duration(hours: 3))),
        Duration.zero,
      );
    });

    test('a clock set back never gives more than the limit', () {
      expect(
        timeLeft(
          startedAt: start,
          now: start.subtract(const Duration(minutes: 5)),
        ),
        dailyTimeLimit,
      );
    });

    test('uses the given limit', () {
      expect(
        timeLeft(
          startedAt: start,
          now: start.add(const Duration(seconds: 3)),
          limit: const Duration(seconds: 10),
        ),
        const Duration(seconds: 7),
      );
    });
  });

  test('secondsShown rounds up so 0 appears only when time is up', () {
    expect(secondsShown(const Duration(milliseconds: 14200)), 15);
    expect(secondsShown(const Duration(seconds: 15)), 15);
    expect(secondsShown(const Duration(milliseconds: 1)), 1);
    expect(secondsShown(Duration.zero), 0);
  });

  test('the daily limit is 10–15 seconds and warns before the end', () {
    expect(dailyTimeLimit.inSeconds, inInclusiveRange(10, 15));
    expect(timeWarning, lessThan(dailyTimeLimit));
  });
}
