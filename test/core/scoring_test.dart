import 'dart:math' as math;

import 'package:aralik/core/answer_scale.dart';
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

double _normalCdf(double z) {
  // Abramowitz–Stegun 7.1.26, |error| < 1.5e-7.
  final t = 1 / (1 + 0.3275911 * z.abs() / math.sqrt2);
  final poly =
      t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  final erf = 1 - poly * math.exp(-z * z / 2);
  return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

/// Coverage of the symmetric interval that maximises expected points when
/// the player's log2 error is Normal(0, sigma).
double bestCoverage(double sigma) {
  double expected(double h) {
    const n = 801;
    final step = 16 * sigma / (n - 1);
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      final x = -8 * sigma + i * step;
      final pdf =
          math.exp(-x * x / (2 * sigma * sigma)) /
          (sigma * math.sqrt(2 * math.pi));
      final points = scoreFor(
        kind: QuestionKind.magnitude,
        low: 1000 * math.pow(2, -h),
        high: 1000 * math.pow(2, h),
        answer: 1000 * math.pow(2, x),
      );
      total += points * pdf * step;
    }
    return total;
  }

  var bestH = 0.0;
  var best = double.negativeInfinity;
  for (var i = 1; i <= 300; i++) {
    final h = i / 100;
    final e = expected(h);
    if (e > best) {
      best = e;
      bestH = h;
    }
  }
  return 2 * _normalCdf(bestH / sigma) - 1;
}

/// Coverage of the best-paying interval when the player's error is
/// Normal(0, σ) in the question's axis units (years, log2 or linear units),
/// σ a fifth of the widest half width [unitsPerHalf].
double bestScaledCoverage(
  double unitsPerHalf,
  num Function(double) at,
  QuestionKind kind,
  AnswerScale scale,
  num answer,
) {
  final sigma = unitsPerHalf / 5;
  double expected(double h) {
    const n = 401;
    final step = 16 * sigma / (n - 1);
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      final x = -8 * sigma + i * step;
      final pdf =
          math.exp(-x * x / (2 * sigma * sigma)) /
          (sigma * math.sqrt(2 * math.pi));
      total +=
          scoreFor(
            kind: kind,
            low: at(-h),
            high: at(h),
            answer: at(x),
            scale: scale,
          ) *
          pdf *
          step;
    }
    return total;
  }

  var bestH = 0.0;
  var best = double.negativeInfinity;
  for (var i = 1; i <= 200; i++) {
    final h = unitsPerHalf * i / 200;
    final e = expected(h);
    if (e > best) {
      best = e;
      bestH = h;
    }
  }
  return 2 * _normalCdf(bestH / sigma) - 1;
}

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
    test('a hit scores 100 − 10·log2(high/low)', () {
      expect(magnitude(5137, 5137, 5137), 100); // exact point
      expect(magnitude(4500, 5500, 5137), 97);
      expect(magnitude(4000, 8000, 5137), 90); // ×2
      expect(magnitude(2000, 8000, 5137), 80); // ×4
      expect(magnitude(1000, 8000, 5137), 70); // ×8
      expect(magnitude(500, 50000, 5137), 34); // slider at full width
    });

    test('a near miss still earns points', () {
      expect(magnitude(4500, 5000, 5137), 91); // 2,7% too low
      expect(magnitude(5200, 6000, 5137), 94); // 1,2% too high
    });

    test('a far miss costs points, floored at −50', () {
      expect(magnitude(100, 200, 5137), minPointsPerQuestion);
    });

    test('is scale independent', () {
      expect(magnitude(40, 80, 50), magnitude(4e6, 8e6, 5e6));
    });
  });

  group('year score', () {
    test('a hit scores 100 − (high−low)', () {
      expect(year(1923, 1923, 1923), 100);
      expect(year(1920, 1925, 1923), 95);
      expect(year(1913, 1933, 1923), 80);
      expect(year(1900, 1950, 1923), 50);
    });

    test('misses cost 20 per year outside', () {
      expect(year(1920, 1922, 1923), 78);
      expect(year(1925, 1930, 1923), 55);
      expect(year(1800, 1810, 1923), minPointsPerQuestion);
    });
  });

  test('intervalScore is width plus 20× the distance outside', () {
    expect(
      intervalScore(kind: QuestionKind.year, low: 10, high: 20, answer: 25),
      closeTo(10 + 20 * 5, 1e-9),
    );
    expect(
      intervalScore(
        kind: QuestionKind.magnitude,
        low: 100,
        high: 400,
        answer: 800,
      ),
      closeTo(2 + 20 * 1, 1e-9),
    );
  });

  test('an honest 90% interval is the best strategy', () {
    // Uncertainty from ±20% to about ×2,8 (log2 sigma 0,3 … 1,5).
    for (final sigma in [0.3, 0.6, 1.0]) {
      expect(
        bestCoverage(sigma),
        inInclusiveRange(0.86, 0.93),
        reason: '$sigma',
      );
    }
    expect(bestCoverage(1.5), inInclusiveRange(0.82, 0.93));
  });

  test('five perfect answers make the daily maximum', () {
    expect(5 * magnitude(7, 7, 7), maxDailyPoints);
  });

  group('ResultTier', () {
    test('hits split at 70 points, misses are always ⬛', () {
      expect(ResultTier.of(points: 100, hit: true).emoji, '🟩');
      expect(ResultTier.of(points: 70, hit: true).emoji, '🟩');
      expect(ResultTier.of(points: 69, hit: true).emoji, '🟨');
      expect(ResultTier.of(points: 91, hit: false).emoji, '⬛');
      expect(ResultTier.of(points: -40, hit: false).emoji, '⬛');
    });

    test('totalPoints adds results', () {
      expect(
        totalPoints([(points: 90, hit: true), (points: -20, hit: false)]),
        70,
      );
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

  group('scaled rule (answer_scale.dart)', () {
    test('a hit at the widest slider scores 30 on every question', () {
      for (final (kind, category, answer) in [
        (QuestionKind.year, QuestionCategory.turkey, 1923),
        (QuestionKind.year, QuestionCategory.ottoman, 1453),
        (QuestionKind.year, QuestionCategory.history, 1100),
        (QuestionKind.year, QuestionCategory.history, -3000),
        (QuestionKind.magnitude, QuestionCategory.geography, 5137),
        (QuestionKind.magnitude, QuestionCategory.sports, 40000),
        (QuestionKind.magnitude, QuestionCategory.animals, 12),
      ]) {
        final scale = scaleFor(kind, category, answer);
        final (low, high) = kind == QuestionKind.year
            ? (answer - scale.maxYearHalf, answer + scale.maxYearHalf)
            : (answer / scale.maxFactor, answer * scale.maxFactor);
        expect(
          scoreFor(
            kind: kind,
            low: low,
            high: high,
            answer: answer,
            scale: scale,
          ),
          pointsAtWidest,
          reason: '$category $answer',
        );
      }
    });

    test('older events get wider sliders', () {
      int half(int year) => scaleFor(
        QuestionKind.year,
        QuestionCategory.history,
        year,
      ).maxYearHalf;
      expect(half(2020), minYearHalfWidth);
      expect(half(1923), 50);
      expect(half(1453), 160);
      expect(half(1100), 250);
      expect(half(-3000), maxYearHalfWidthScaled);
      expect(half(2100), minYearHalfWidth); // never below the minimum
    });

    test('an honest 90% interval stays the best play on every scale', () {
      // The player's error is Normal(0, σ) in the question's axis units
      // (years or log2); σ is a fifth of the widest half width.

      final ottoman = scaleFor(
        QuestionKind.year,
        QuestionCategory.ottoman,
        1453,
      );
      expect(
        bestScaledCoverage(
          ottoman.maxYearHalf.toDouble(),
          (x) => 1453 + x,
          QuestionKind.year,
          ottoman,
          1453,
        ),
        closeTo(0.89, 0.02),
      );
      final sports = scaleFor(
        QuestionKind.magnitude,
        QuestionCategory.sports,
        40000,
      );
      final log2Factor = math.log(sports.maxFactor) / math.ln2;
      expect(
        bestScaledCoverage(
          log2Factor,
          (x) => 40000 * math.pow(2, x),
          QuestionKind.magnitude,
          sports,
          40000,
        ),
        closeTo(0.89, 0.02),
      );
    });

    test("rule v3: the bank's own scale, linear or narrower", () {
      Question q(num answer, String unit, QuestionScale? scale) => Question(
        id: 'q',
        text: 't',
        answer: answer,
        unit: unit,
        kind: QuestionKind.magnitude,
        category: QuestionCategory.geography,
        source: 's',
        dataYear: 2024,
        scale: scale,
      );
      final age = q(29.8, 'yaş', const QuestionScale.linear(6));
      expect(refinedScaleOf(age), (
        maxFactor: 0,
        maxYearHalf: 0,
        linearHalf: 6,
      ));
      // The scaled rule ignores it: geography ×10.
      expect(scaleOf(age).maxFactor, 10);
      expect(scaleUnder(ScoreRule.first, age), isNull);
      expect(isLinearUnder(ScoreRule.refined, age), isTrue);
      expect(isLinearUnder(ScoreRule.scaled, age), isFalse);

      final kcal = q(155, 'kcal', const QuestionScale.log(3));
      expect(refinedScaleOf(kcal).maxFactor, 3);
      // Percentages keep their own rule.
      final pct = q(40, '%', const QuestionScale.linear(6));
      expect(refinedScaleOf(pct), scaleOf(pct));
      expect(refinedScaleOf(q(5, 'km', null)), scaleOf(q(5, 'km', null)));

      // Widest hit 30 points; ±2 years 77; ×2 on a ×3 scale 56 (70 at ×5).
      final s = refinedScaleOf(age);
      int pts(num low, num high, num answer, AnswerScale scale) => scoreFor(
        kind: QuestionKind.magnitude,
        low: low,
        high: high,
        answer: answer,
        scale: scale,
      );
      expect(pts(24, 36, 30, s), pointsAtWidest);
      expect(pts(28, 32, 30, s), 77);
      final k = refinedScaleOf(kcal);
      expect(pts(155 / 3, 155 * 3, 155, k), pointsAtWidest);
      expect(pts(155 / 2, 155 * 2, 155, k), 56);
    });

    test('rule v3 keeps the honest 90% interval the best play', () {
      const linear = (maxFactor: 0.0, maxYearHalf: 0, linearHalf: 6);
      expect(
        bestScaledCoverage(
          6,
          (x) => 30 + x,
          QuestionKind.magnitude,
          linear,
          30,
        ),
        closeTo(0.89, 0.02),
      );
      const narrow = (maxFactor: 3.0, maxYearHalf: 0, linearHalf: 0);
      expect(
        bestScaledCoverage(
          math.log(3) / math.ln2,
          (x) => 155 * math.pow(2, x),
          QuestionKind.magnitude,
          narrow,
          155,
        ),
        closeTo(0.89, 0.02),
      );
    });

    test('the switch days decide the rule of a day', () {
      expect(ruleOn(10), ScoreRule.first);
      expect(ruleOn(10, v2Day: 6), ScoreRule.scaled);
      expect(ruleOn(10, v2Day: 6, v3Day: 11), ScoreRule.scaled);
      expect(ruleOn(11, v2Day: 6, v3Day: 11), ScoreRule.refined);
    });

    test('the switch day decides the rule of a day', () {
      expect(scaledOn(10, null), isFalse);
      expect(scaledOn(9, 10), isFalse);
      expect(scaledOn(10, 10), isTrue);
      expect(scaledOn(11, 10), isTrue);
    });

    test('percentages are scored linearly, widest hit 30', () {
      final pct = scaleFor(
        QuestionKind.magnitude,
        QuestionCategory.geography,
        42,
        unit: '%',
      );
      expect(pct.linearHalf, 20);
      int score(int low, int high, num answer) => scoreFor(
        kind: QuestionKind.magnitude,
        low: low,
        high: high,
        answer: answer,
        scale: pct,
      );
      expect(score(22, 62, 42), pointsAtWidest);
      expect(score(42, 42, 42), 100);
      // Same width scores the same at 5% and at 50%.
      expect(score(1, 11, 6), score(45, 55, 50));
    });
  });

  group('math mode', () {
    int score(num low, num high, num answer) => scoreFor(
      kind: QuestionKind.magnitude,
      low: low,
      high: high,
      answer: answer,
      scale: (maxFactor: mathMaxFactor, maxYearHalf: 0, linearHalf: 0),
      floor: mathMinPoints,
    );

    test('the widest hit (÷2 … ×2) still scores 30', () {
      expect(score(500, 2000, 1000), pointsAtWidest);
    });

    test('a close guess scores high, a 10% miss scores nothing', () {
      // ±10% around the answer: ~90.
      expect(score(900, 1100, 1000), inInclusiveRange(88, 92));
      // The whole interval 10% too high: no minus, just 0.
      expect(score(1100, 1300, 1000), 0);
      // A far miss: still 0, never below.
      expect(score(100000, 200000, 1000), 0);
    });

    test('a percentage opens ±10 points, scored linearly', () {
      final pct = scoreFor(
        kind: QuestionKind.magnitude,
        low: 40,
        high: 60,
        answer: 50,
        scale: (maxFactor: 0, maxYearHalf: 0, linearHalf: mathMaxPercentHalf),
        floor: mathMinPoints,
      );
      expect(pct, pointsAtWidest);
    });
  });
}
