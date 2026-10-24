import 'package:aralik/core/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNumber', () {
    test('groups thousands with dots', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(7), '7');
      expect(formatNumber(999), '999');
      expect(formatNumber(1000), '1.000');
      expect(formatNumber(5137), '5.137');
      expect(formatNumber(12345), '12.345');
      expect(formatNumber(123456), '123.456');
      expect(formatNumber(1234567), '1.234.567');
      expect(formatNumber(85372377), '85.372.377');
    });

    test('rounds to integer by default', () {
      expect(formatNumber(1234.4), '1.234');
      expect(formatNumber(1234.5), '1.235');
      expect(formatNumber(999.6), '1.000');
    });

    test('uses comma for decimals and trims trailing zeros', () {
      expect(formatNumber(3.5, maxDecimals: 1), '3,5');
      expect(formatNumber(3.0, maxDecimals: 2), '3');
      expect(formatNumber(3.10, maxDecimals: 2), '3,1');
      expect(formatNumber(1234.56, maxDecimals: 2), '1.234,56');
      expect(formatNumber(0.25, maxDecimals: 1), '0,3');
    });

    test('handles negatives', () {
      expect(formatNumber(-1234), '-1.234');
      expect(formatNumber(-3.5, maxDecimals: 1), '-3,5');
      expect(formatNumber(-0.2), '0');
    });
  });

  group('formatCompact', () {
    test('keeps values below a million exact', () {
      expect(formatCompact(5137), '5.137');
      expect(formatCompact(950000), '950.000');
    });

    test('uses milyon and milyar', () {
      expect(formatCompact(1000000), '1 milyon');
      expect(formatCompact(12500000), '12,5 milyon');
      expect(formatCompact(85372377), '85,4 milyon');
      expect(formatCompact(2300000000), '2,3 milyar');
      expect(formatCompact(-12500000), '-12,5 milyon');
    });

    test('promotes to the next scale after rounding', () {
      expect(formatCompact(999960000), '1 milyar');
    });
  });

  group('formatYear', () {
    test('has no thousands separator', () {
      expect(formatYear(1923), '1923');
      expect(formatYear(476), '476');
    });

    test('writes BCE years with MÖ', () {
      expect(formatYear(-330), 'MÖ 330');
    });
  });

  group('formatRange', () {
    test('formats magnitudes with a unit', () {
      expect(formatRange(4500, 5500, unit: 'm'), '4.500 – 5.500 m');
      expect(formatRange(800, 1200), '800 – 1.200');
    });

    test('writes a shared scale word once', () {
      expect(
        formatRange(80000000, 90000000, unit: 'kişi'),
        '80 – 90 milyon kişi',
      );
      expect(formatRange(500000, 2000000), '500.000 – 2 milyon');
      expect(formatRange(900000000, 1500000000), '900 milyon – 1,5 milyar');
    });

    test('formats years without separators', () {
      expect(formatRange(1915, 1925, isYear: true), '1915 – 1925');
      expect(formatRange(-50, 20, isYear: true), 'MÖ 50 – 20');
    });
  });
}
