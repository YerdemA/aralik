import 'package:aralik/core/daily.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayIndexFor', () {
    test('is 0 on the epoch, whatever the time of day', () {
      expect(dayIndexFor(DateTime(2026, 11, 1)), 0);
      expect(dayIndexFor(DateTime(2026, 11, 1, 23, 59, 59)), 0);
    });

    test('counts calendar days', () {
      expect(dayIndexFor(DateTime(2026, 11, 2, 0, 0, 1)), 1);
      expect(dayIndexFor(DateTime(2026, 12, 1)), 30);
      expect(dayIndexFor(DateTime(2027, 11, 1)), 365);
      expect(dayIndexFor(DateTime(2028, 11, 1)), 731); // 2028 is a leap year
    });

    test('is negative before the epoch', () {
      expect(dayIndexFor(DateTime(2026, 10, 31, 23, 59)), -1);
      expect(dayIndexFor(DateTime(2026, 10, 24)), -8);
    });

    test('uses the local calendar date of a UTC time', () {
      final utc = DateTime.utc(2026, 11, 5, 12);
      final local = utc.toLocal();
      expect(
        dayIndexFor(local),
        DateTime(
          local.year,
          local.month,
          local.day,
        ).difference(DateTime(2026, 11, 1)).inDays,
      );
    });
  });

  test('puzzleNumber starts at 1', () {
    expect(puzzleNumber(0), 1);
    expect(puzzleNumber(41), 42);
  });

  group('dailyIndices', () {
    test('takes five consecutive questions per day', () {
      expect(dailyIndices(0, 150), [0, 1, 2, 3, 4]);
      expect(dailyIndices(1, 150), [5, 6, 7, 8, 9]);
      expect(dailyIndices(29, 150), [145, 146, 147, 148, 149]);
    });

    test('wraps around when the bank runs out', () {
      expect(dailyIndices(30, 150), [0, 1, 2, 3, 4]);
      expect(dailyIndices(30, 154), [150, 151, 152, 153, 0]);
    });

    test('handles days before the epoch', () {
      expect(dailyIndices(-1, 150), [145, 146, 147, 148, 149]);
    });

    test('handles tiny banks', () {
      expect(dailyIndices(0, 0), isEmpty);
      expect(dailyIndices(1, 3), [2, 0, 1]);
    });
  });

  group('practiceIndices', () {
    test('is empty on day 0 and before', () {
      expect(practiceIndices(0, 150), isEmpty);
      expect(practiceIndices(-3, 150), isEmpty);
    });

    test('contains only past days', () {
      expect(practiceIndices(1, 150), [0, 1, 2, 3, 4]);
      expect(practiceIndices(3, 150), List.generate(15, (i) => i));
    });

    test('never contains today or future questions', () {
      for (var day = 1; day < 40; day++) {
        final pool = practiceIndices(day, 154).toSet();
        expect(pool.intersection(dailyIndices(day, 154).toSet()), isEmpty);
        if (5 * day < 154) {
          expect(pool.every((i) => i < 5 * day), isTrue);
        }
      }
    });

    test('after the bank wraps, everything but today is available', () {
      final pool = practiceIndices(31, 154);
      expect(pool, hasLength(149));
      expect(pool.toSet().length, pool.length);
    });
  });
}
