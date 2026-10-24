import 'package:aralik/core/interval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('magnitudeInterval', () {
    test('is a single point at zero width', () {
      expect(magnitudeInterval(5137, 0), (low: 5137, high: 5137));
    });

    test('spans guess÷10 … guess×10 at full width', () {
      expect(magnitudeInterval(5000, 1), (low: 500, high: 50000));
    });

    test('rounds outwards to nice steps', () {
      // ×1,1 around 5.000 → 4.545 … 5.500 → step 50
      final t = 0.0413926851582; // log10(1.1)
      expect(magnitudeInterval(5000, t), (low: 4500, high: 5500));
    });

    test('always contains the guess', () {
      for (final guess in [1, 7, 62, 999, 5137, 85372377]) {
        for (var i = 0; i <= 20; i++) {
          final b = magnitudeInterval(guess, i / 20);
          expect(b.low, lessThanOrEqualTo(guess), reason: '$guess @ $i');
          expect(b.high, greaterThanOrEqualTo(guess), reason: '$guess @ $i');
          expect(b.low, greaterThanOrEqualTo(1));
        }
      }
    });

    test('grows monotonically with the slider', () {
      var previous = magnitudeInterval(5137, 0);
      for (var i = 1; i <= 100; i++) {
        final b = magnitudeInterval(5137, i / 100);
        expect(b.low, lessThanOrEqualTo(previous.low));
        expect(b.high, greaterThanOrEqualTo(previous.high));
        previous = b;
      }
    });

    test('clamps the slider position', () {
      expect(magnitudeInterval(100, -1), magnitudeInterval(100, 0));
      expect(magnitudeInterval(100, 2), magnitudeInterval(100, 1));
    });
  });

  group('yearInterval', () {
    test('uses a quadratic half width', () {
      expect(yearInterval(1923, 0), (low: 1923, high: 1923));
      expect(yearInterval(1923, 0.5), (low: 1910, high: 1936)); // 12,5 → 13
      expect(yearInterval(1923, 1), (low: 1873, high: 1973));
    });
  });
}
