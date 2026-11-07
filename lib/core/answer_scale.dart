/// How wide a question's answers can sensibly be (pure functions).
///
/// One rule for every question would not fit them all: ±50 years is far
/// too narrow for an event of 1100 and too wide for one of 2000; ×10 is
/// right for populations and far too wide for stadium capacities. Each
/// question gets a scale from its kind, category and answer: the slider's
/// widest interval, and with it how many points a unit of width costs, so
/// that a hit at the slider's widest end scores [pointsAtWidest] everywhere.
///
/// Must match server/leaderboard/src/scoring.js (`scaleOf`); the shared
/// test vectors check both.
library;

import 'dart:math' as math;

import '../data/question.dart';

/// Points of a hit with the slider at its widest end, for every question.
const int pointsAtWidest = 30;

/// Year the age of an event is counted from. Fixed, so the scale of a
/// question never changes and the server computes the same.
const int scaleBaseYear = 2026;

/// The widest ± years: `20 + age/4`, rounded to tens, kept in 30…400.
const int minYearHalfWidth = 30;
const int maxYearHalfWidthScaled = 400;

/// Widest magnitude factor (÷f … ×f) per category; [defaultMagnitudeFactor]
/// for the rest.
const Map<QuestionCategory, double> magnitudeFactors = {
  QuestionCategory.geography: 10,
  QuestionCategory.companies: 10,
  QuestionCategory.animals: 8,
  QuestionCategory.science: 6,
  QuestionCategory.architecture: 6,
  QuestionCategory.turkey: 6,
  QuestionCategory.everyday: 5,
  QuestionCategory.sports: 4,
};
const double defaultMagnitudeFactor = 8;

/// Unit of a percentage question. Such a magnitude is not stretched on a
/// log axis: its interval is the guess ± up to [maxPercentHalfWidth]
/// points, never above 100 (2026-11-07).
const String percentUnit = '%';
const int maxPercentHalfWidth = 20;

bool isPercentUnit(String unit) => unit == percentUnit;

/// A question's scale. For a magnitude only [maxFactor] matters, for a year
/// only [maxYearHalf], for a percentage only [maxPercentHalf] (non-zero only
/// for percentages, which are scored linearly in points).
typedef AnswerScale = ({double maxFactor, int maxYearHalf, int maxPercentHalf});

AnswerScale scaleOf(Question q) =>
    scaleFor(q.kind, q.category, q.answer, unit: q.unit);

AnswerScale scaleFor(
  QuestionKind kind,
  QuestionCategory category,
  num answer, {
  String unit = '',
}) {
  switch (kind) {
    case QuestionKind.magnitude:
      if (isPercentUnit(unit)) {
        return (
          maxFactor: 0,
          maxYearHalf: 0,
          maxPercentHalf: maxPercentHalfWidth,
        );
      }
      return (
        maxFactor: magnitudeFactors[category] ?? defaultMagnitudeFactor,
        maxYearHalf: 0,
        maxPercentHalf: 0,
      );
    case QuestionKind.year:
      final age = math.max(0, scaleBaseYear - answer.round());
      final half = ((20 + age / 4) / 10).round() * 10;
      return (
        maxFactor: 0,
        maxYearHalf: half.clamp(minYearHalfWidth, maxYearHalfWidthScaled),
        maxPercentHalf: 0,
      );
  }
}

/// Whether [day]'s daily set (and a duel played on [day]) follows the
/// current, scaled rule. [switchDay] is the first such day, from the
/// content manifest (`scoring_v2_day`); null while it is not set, when
/// only free play uses the current rule.
bool scaledOn(int day, int? switchDay) => switchDay != null && day >= switchDay;

/// Points lost per unit of the interval score: per log2 for magnitudes,
/// per year for years, per percentage point for percentages. Chosen so the
/// widest hit scores [pointsAtWidest]: `(100 − 30) / widest width`.
double pointsPerUnit(QuestionKind kind, AnswerScale scale) {
  if (scale.maxPercentHalf > 0) {
    return (100 - pointsAtWidest) / (2.0 * scale.maxPercentHalf);
  }
  final widest = switch (kind) {
    QuestionKind.magnitude => 2 * math.log(scale.maxFactor) / math.ln2,
    QuestionKind.year => 2.0 * scale.maxYearHalf,
  };
  return (100 - pointsAtWidest) / widest;
}
