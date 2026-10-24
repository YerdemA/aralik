import 'dart:math' as math;

import '../data/question.dart';

/// Scoring formulas (pure functions).

const int maxPointsPerQuestion = 100;
const int minPointsOnHit = 10;
const int maxDailyPoints = 500;

/// Target hit rate for a "%90 sure" interval.
const double calibrationTarget = 0.9;

/// Whether [answer] lies inside the closed interval [low, high].
bool isHit(num low, num high, num answer) => low <= answer && answer <= high;

/// Points for one locked interval; 0 on a miss.
///
/// * magnitude: `max(10, round(100 − 25·log2(high/low)))`
/// * year: `max(10, 100 − 4·(high−low))`
int scoreFor({
  required QuestionKind kind,
  required num low,
  required num high,
  required num answer,
}) {
  assert(low <= high, 'low ($low) must not exceed high ($high)');
  if (!isHit(low, high, answer)) return 0;
  final raw = switch (kind) {
    // A non-positive low bound is an infinitely wide log interval.
    QuestionKind.magnitude =>
      low > 0 ? (100 - 25 * _log2(high / low)).round() : minPointsOnHit,
    QuestionKind.year => (100 - 4 * (high - low)).round(),
  };
  return raw.clamp(minPointsOnHit, maxPointsPerQuestion);
}

double _log2(num x) => math.log(x) / math.ln2;

/// Result tier, matching the share card squares.
enum ResultTier {
  /// ≥70 points.
  good('🟩'),

  /// 1–69 points.
  partial('🟨'),

  /// Interval missed the answer.
  miss('⬛');

  const ResultTier(this.emoji);
  final String emoji;

  static ResultTier fromPoints(int points) => points >= 70
      ? good
      : points > 0
      ? partial
      : miss;
}

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
