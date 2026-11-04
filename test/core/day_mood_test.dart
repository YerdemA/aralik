import 'package:aralik/core/day_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('five bands from the daily total', () {
    expect(DayMood.of(500), DayMood.legend);
    expect(DayMood.of(450), DayMood.legend);
    expect(DayMood.of(449), DayMood.great);
    expect(DayMood.of(350), DayMood.great);
    expect(DayMood.of(349), DayMood.proud);
    expect(DayMood.of(200), DayMood.proud);
    expect(DayMood.of(199), DayMood.unsure);
    expect(DayMood.of(0), DayMood.unsure);
    expect(DayMood.of(-1), DayMood.down);
    expect(DayMood.of(-250), DayMood.down);
  });

  test('bands are in order, best first', () {
    final mins = [for (final m in DayMood.values) m.minTotal];
    expect(mins.last, isNull);
    for (var i = 1; i < mins.length - 1; i++) {
      expect(mins[i]!, lessThan(mins[i - 1]!));
    }
  });
}
