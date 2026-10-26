import 'dart:math' as math;

import '../data/question.dart';

/// Scoring formulas (pure functions).

const int maxPointsPerQuestion = 100;
const int maxDailyPoints = 500;

/// A far miss costs points. The floor is low on purpose: a floor at 0
/// would make far misses free and reward deliberately narrow intervals
/// again (at ×2 uncertainty the best play would cover only ~74%).
const int minPointsPerQuestion = -100;

/// Target hit rate for a "%90 sure" interval.
const double calibrationTarget = 0.9;

/// Interval score (Gneiting & Raftery 2007) for a central (1−α) interval:
/// `S = width + (2/α)·distance outside`. Its expected value is lowest
/// exactly when the bounds are the player's own 5% and 95% quantiles, so
/// the best strategy is an honest 90% interval — never a deliberately
/// narrow one.
const double intervalAlpha = 1 - calibrationTarget;
const double missPenalty = 2 / intervalAlpha; // 20

/// Points lost per unit of S: per doubling (log2) for magnitudes, per year
/// for years. With the −100 floor this keeps an honest 90% interval the
/// best strategy up to ~×2,8 (magnitude) or ~±25 years of uncertainty.
const double magnitudePointsPerLog2 = 10;
const double yearPointsPerYear = 1;

/// Whether [answer] lies inside the closed interval [low, high].
bool isHit(num low, num high, num answer) => low <= answer && answer <= high;

/// Interval score S of one locked interval (lower is better).
///
/// * magnitude: on a log2 axis, so ×2 too high costs as much as ÷2 too low
/// * year: in years
double intervalScore({
  required QuestionKind kind,
  required num low,
  required num high,
  required num answer,
}) {
  assert(low <= high, 'low ($low) must not exceed high ($high)');
  double Function(num) axis = switch (kind) {
    // Magnitudes are positive; clamp so a 0 bound stays finite.
    QuestionKind.magnitude => (v) => _log2(math.max(v, 1e-9)),
    QuestionKind.year => (v) => v.toDouble(),
  };
  final l = axis(low), h = axis(high), x = axis(answer);
  final outside = x < l
      ? l - x
      : x > h
      ? x - h
      : 0.0;
  return (h - l) + missPenalty * outside;
}

/// Points for one locked interval: `100 − k·S`, clamped to −100…100, with
/// k = 10 per log2 (magnitude) or 1 per year (year).
///
/// A hit scores by width alone (4.500 – 5.500 m → 97). A near miss still
/// earns something; a far miss costs points.
int scoreFor({
  required QuestionKind kind,
  required num low,
  required num high,
  required num answer,
}) {
  final s = intervalScore(kind: kind, low: low, high: high, answer: answer);
  final k = switch (kind) {
    QuestionKind.magnitude => magnitudePointsPerLog2,
    QuestionKind.year => yearPointsPerYear,
  };
  return (maxPointsPerQuestion - k * s).round().clamp(
    minPointsPerQuestion,
    maxPointsPerQuestion,
  );
}

double _log2(num x) => math.log(x) / math.ln2;

/// Result tier, matching the share card squares.
enum ResultTier {
  /// Hit with ≥70 points.
  good('🟩'),

  /// Hit with fewer points (a wide interval).
  partial('🟨'),

  /// The interval missed the answer, even if a near miss earned points.
  miss('⬛');

  const ResultTier(this.emoji);
  final String emoji;

  static ResultTier of({required int points, required bool hit}) => !hit
      ? miss
      : points >= 70
      ? good
      : partial;
}

/// Outcome of one question, as stored for daily sets.
typedef QuestionResult = ({int points, bool hit});

extension QuestionResultTier on QuestionResult {
  ResultTier get tier => ResultTier.of(points: points, hit: hit);
}

int totalPoints(Iterable<QuestionResult> results) =>
    results.fold(0, (sum, r) => sum + r.points);

enum CalibrationFeedback {
  /// Too few answers to say anything.
  notEnoughData,

  /// Hit rate clearly below 90%: intervals are too narrow.
  tooNarrow,

  /// Close to 90%.
  good,

  /// Hit rate clearly above 90%: intervals could be narrower.
  tooWide,
}

/// Minimum answered questions before calibration feedback is shown.
const int minAnswersForCalibration = 10;

/// Share of hits, or null when nothing was answered.
double? calibrationRate(int hits, int total) {
  assert(0 <= hits && hits <= total);
  return total == 0 ? null : hits / total;
}

/// Feedback for the all-time hit rate. "Good" is 80–95%.
CalibrationFeedback calibrationFeedback(int hits, int total) {
  if (total < minAnswersForCalibration) {
    return CalibrationFeedback.notEnoughData;
  }
  final rate = hits / total;
  if (rate < 0.8) return CalibrationFeedback.tooNarrow;
  if (rate > 0.95) return CalibrationFeedback.tooWide;
  return CalibrationFeedback.good;
}
