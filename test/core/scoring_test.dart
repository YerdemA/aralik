import 'package:aralik/core/scoring.dart';
import 'package:aralik/data/question.dart';
import 'package:flutter_test/flutter_test.dart';

int magnitude(num low, num high, num answer) => scoreFor(
  kind: QuestionKind.magnitude,
  low: low,
  high: high,
  answer: answer,
);

int year(num low, num high, num answer) =>
    scoreFor(kind: QuestionKind.year, low: low, high: high, answer: answer);

void main() {
  group('isHit', () {
    test('is inclusive on both ends', () {
      expect(isHit(10, 20, 10), isTrue);
      expect(isHit(10, 20, 20), isTrue);
      expect(isHit(10, 20, 15), isTrue);
      expect(isHit(10, 20, 9.99), isFalse);
      expect(isHit(10, 20, 20.01), isFalse);
    });
  });

  group('magnitude score', () {
    test('is 0 on a miss', () {
      expect(magnitude(4500, 5000, 5137), 0);
      expect(magnitude(5200, 6000, 5137), 0);
    });

    test('follows 100 − 25·log2(high/low)', () {
      expect(magnitude(5137, 5137, 5137), 100); // exact point
      expect(magnitude(4000, 8000, 5137), 75); // ×2
      expect(magnitude(2000, 8000, 5137), 50); // ×4
      expect(magnitude(1000, 8000, 5137), 25); // ×8
      // 4.500 – 5.500 m: log2(1.222) = 0.2895 → 92.76 → 93
      expect(magnitude(4500, 5500, 5137), 93);
    });

    test('never drops below 10 on a hit', () {
      expect(magnitude(500, 8000, 5137), 10); // ×16 → 0
      expect(magnitude(1, 1000000, 5137), 10);
      expect(magnitude(0, 10000, 5137), 10);
    });

    test('is scale independent', () {
      expect(magnitude(40, 80, 50), magnitude(4e6, 8e6, 5e6));
    });
  });

  group('year score', () {
    test('is 0 on a miss', () {
      expect(year(1920, 1922, 1923), 0);
    });

    test('follows 100 − 4·(high−low)', () {
      expect(year(1923, 1923, 1923), 100);
      expect(year(1920, 1925, 1923), 80);
      expect(year(1913, 1933, 1923), 20);
    });

    test('never drops below 10 on a hit', () {
      expect(year(1900, 1950, 1923), 10);
    });
  });

  test('five perfect answers make the daily maximum', () {
    expect(5 * magnitude(7, 7, 7), maxDailyPoints);
  });

  group('ResultTier', () {
    test('maps points to share squares', () {
      expect(ResultTier.fromPoints(100).emoji, '🟩');
      expect(ResultTier.fromPoints(70).emoji, '🟩');
      expect(ResultTier.fromPoints(69).emoji, '🟨');
      expect(ResultTier.fromPoints(10).emoji, '🟨');
      expect(ResultTier.fromPoints(0).emoji, '⬛');
    });
  });

  group('calibration', () {
    test('rate is null without answers', () {
      expect(calibrationRate(0, 0), isNull);
      expect(calibrationRate(9, 10), 0.9);
    });

    test('needs enough answers for feedback', () {
      expect(calibrationFeedback(5, 5), CalibrationFeedback.notEnoughData);
    });

    test('flags narrow, good and wide intervals', () {
      expect(calibrationFeedback(62, 100), CalibrationFeedback.tooNarrow);
      expect(calibrationFeedback(79, 100), CalibrationFeedback.tooNarrow);
      expect(calibrationFeedback(80, 100), CalibrationFeedback.good);
      expect(calibrationFeedback(90, 100), CalibrationFeedback.good);
      expect(calibrationFeedback(95, 100), CalibrationFeedback.good);
      expect(calibrationFeedback(96, 100), CalibrationFeedback.tooWide);
      expect(calibrationFeedback(10, 10), CalibrationFeedback.tooWide);
    });
  });
}
