import 'package:aralik/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dayLabel shows the Turkish date and the puzzle number', () {
    expect(dayLabel(DateTime(2026, 11, 1), 1), '1 Kasım · #1');
    expect(dayLabel(DateTime(2027, 1, 31), 92), '31 Ocak · #92');
  });

  test('dayLabel drops the number during the closed test', () {
    expect(dayLabel(DateTime(2026, 10, 30), -1), '30 Ekim');
    expect(dayLabel(DateTime(2026, 10, 31), 0), '31 Ekim');
  });
}
