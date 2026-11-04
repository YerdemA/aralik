import 'package:aralik/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dayLabel shows the Turkish date', () {
    expect(dayLabel(DateTime(2026, 11, 1)), '1 Kasım');
    expect(dayLabel(DateTime(2027, 1, 31)), '31 Ocak');
  });

  test('dayLabelWithWeekday adds the Turkish weekday', () {
    expect(dayLabelWithWeekday(DateTime(2026, 11, 4)), '4 Kasım Çarşamba');
    expect(dayLabelWithWeekday(DateTime(2026, 11, 8)), '8 Kasım Pazar');
    expect(dayLabelWithWeekday(DateTime(2026, 11, 9)), '9 Kasım Pazartesi');
  });
}
