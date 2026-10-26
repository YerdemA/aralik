import 'dart:convert';

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

  group('Schedule', () {
    List<String> day(int n) => [for (var k = 0; k < 5; k++) 'q$n$k'];
    String json(List<List<String>> days) => jsonEncode({'days': days});
    final three = Schedule([day(0), day(1), day(2)]);

    test('parses schedule.json', () {
      final s = Schedule.parse(json([day(0), day(1)]));
      expect(s.length, 2);
      expect(s.idsFor(1), day(1));
      expect(s.ids, {...day(0), ...day(1)});
    });

    test('rejects malformed schedules', () {
      for (final bad in [
        '[]',
        '{"days": 3}',
        json([
          ['a', 'b', 'c', 'd'],
        ]),
        json([
          ['a', 'b', 'c', 'd', 'a'],
        ]),
        json([
          day(0),
          ['x', 'y', 'z', 'w', 'q00'],
        ]), // q00 already on day 0
        '{"days": [["a", "b", "c", "d", 5]]}',
      ]) {
        expect(() => Schedule.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('wraps around and counts closed-test days back from the end', () {
      expect(three.idsFor(0), day(0));
      expect(three.idsFor(3), day(0));
      expect(three.idsFor(4), day(1));
      expect(three.idsFor(-1), day(2));
      expect(Schedule(const []).idsFor(0), isEmpty);
    });

    test('upcomingIds covers the horizon from today', () {
      final ten = Schedule([for (var d = 0; d < 10; d++) day(d)]);
      expect(ten.upcomingIds(2, horizon: 3), {...day(2), ...day(3), ...day(4)});
      expect(ten.upcomingIds(9, horizon: 2), {...day(9), ...day(0)});
    });

    test('upcomingIds is the whole schedule when it is shorter', () {
      expect(three.upcomingIds(1, horizon: 60), three.ids);
    });

    test('extendsSchedule only allows appended days', () {
      final two = Schedule([day(0), day(1)]);
      expect(three.extendsSchedule(two), isTrue);
      expect(two.extendsSchedule(two), isTrue);
      expect(two.extendsSchedule(three), isFalse);
      expect(Schedule([day(1), day(0), day(2)]).extendsSchedule(two), isFalse);
      final changed = [...day(0)]..[4] = 'other';
      expect(Schedule([changed, day(1)]).extendsSchedule(two), isFalse);
    });
  });
}
