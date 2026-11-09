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

/// Math mode (2026-11-08): answers follow from the numbers, so the slider
/// opens only to ÷2 … ×2 (percentages ±10 points) and a close guess is
/// what scores; the widest hit still scores [pointsAtWidest]. No points
/// below [mathMinPoints]: a miss scores 0, never minus. (With a floor of 0
/// a far miss costs nothing, so a narrow interval pays a little more than
/// an honest 90% one; math mode accepts that, the bank does not.)
const double mathMaxFactor = 2;
const int mathMaxPercentHalf = 10;
const int mathMinPoints = 0;

/// Math mode's scale for [q]: ÷2 … ×2, or ±10 points for a percentage.
AnswerScale mathScaleOf(Question q) => isPercentUnit(q.unit)
    ? (maxFactor: 0, maxYearHalf: 0, linearHalf: mathMaxPercentHalf)
    : (maxFactor: mathMaxFactor, maxYearHalf: 0, linearHalf: 0);

/// A question's scale. For a magnitude only [maxFactor] matters, for a year
/// only [maxYearHalf]; a non-zero [linearHalf] makes the question linear
/// (guess ± up to that many units, scored in units): percentages, and
/// under the refined rule the bank's linear quantities.
typedef AnswerScale = ({double maxFactor, int maxYearHalf, int linearHalf});

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
        return (maxFactor: 0, maxYearHalf: 0, linearHalf: maxPercentHalfWidth);
      }
      return (
        maxFactor: magnitudeFactors[category] ?? defaultMagnitudeFactor,
        maxYearHalf: 0,
        linearHalf: 0,
      );
    case QuestionKind.year:
      final age = math.max(0, scaleBaseYear - answer.round());
      final half = ((20 + age / 4) / 10).round() * 10;
      return (
        maxFactor: 0,
        maxYearHalf: half.clamp(minYearHalfWidth, maxYearHalfWidthScaled),
        linearHalf: 0,
      );
  }
}

/// The scoring rules in order. Points and slider bounds of a daily set or
/// a duel follow the rule of its day ([ruleOn]); free play and math mode
/// always use the newest.
enum ScoreRule {
  /// Days before `scoring_v2_day`: one width for every question.
  first,

  /// From `scoring_v2_day` (2026-11-05): [scaleOf], by kind, category and
  /// answer.
  scaled,

  /// From `scoring_v3_day` (2026-11-09): [refinedScaleOf], the bank's own
  /// scale where a question has one.
  refined,
}

/// The rule of [day], given the manifest's switch days (null: not set).
ScoreRule ruleOn(int day, {int? v2Day, int? v3Day}) {
  if (v3Day != null && day >= v3Day) return ScoreRule.refined;
  if (v2Day != null && day >= v2Day) return ScoreRule.scaled;
  return ScoreRule.first;
}

/// [q]'s scale under [rule]; null under the first rule.
AnswerScale? scaleUnder(ScoreRule rule, Question q) => switch (rule) {
  ScoreRule.first => null,
  ScoreRule.scaled => scaleOf(q),
  ScoreRule.refined => refinedScaleOf(q),
};

/// The refined rule (v3): a question with its own [Question.scale] gets it
/// (linear ± units, or a narrower ÷f … ×f); the rest, percentages and
/// years keep [scaleOf].
AnswerScale refinedScaleOf(Question q) {
  final own = q.scale;
  if (own == null ||
      q.kind != QuestionKind.magnitude ||
      isPercentUnit(q.unit)) {
    return scaleOf(q);
  }
  if (own.half case final half?) {
    return (maxFactor: 0, maxYearHalf: 0, linearHalf: half);
  }
  return (maxFactor: own.factor!, maxYearHalf: 0, linearHalf: 0);
}

/// Whether [q] is answered on a linear slider under [rule]: percentages
/// always, a question with a linear scale under the refined rule.
bool isLinearUnder(ScoreRule rule, Question q) =>
    q.kind == QuestionKind.magnitude &&
    (isPercentUnit(q.unit) ||
        (rule == ScoreRule.refined && q.scale?.half != null));

/// Whether [day]'s daily set (and a duel played on [day]) follows the
/// current, scaled rule. [switchDay] is the first such day, from the
/// content manifest (`scoring_v2_day`); null while it is not set, when
/// only free play uses the current rule.
bool scaledOn(int day, int? switchDay) => switchDay != null && day >= switchDay;

/// Points lost per unit of the interval score: per log2 for magnitudes,
/// per year for years, per percentage point for percentages. Chosen so the
/// widest hit scores [pointsAtWidest]: `(100 − 30) / widest width`.
double pointsPerUnit(QuestionKind kind, AnswerScale scale) {
  if (scale.linearHalf > 0) {
    return (100 - pointsAtWidest) / (2.0 * scale.linearHalf);
  }
  final widest = switch (kind) {
    QuestionKind.magnitude => 2 * math.log(scale.maxFactor) / math.ln2,
    QuestionKind.year => 2.0 * scale.maxYearHalf,
  };
  return (100 - pointsAtWidest) / widest;
}
