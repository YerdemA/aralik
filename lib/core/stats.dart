import '../data/question.dart';
import 'scoring.dart';

/// Statistics over the player's answer history (pure functions).

/// One locked interval, as kept in the history.
typedef AnswerRecord = ({
  QuestionCategory category,
  int points,
  Outcome outcome,
});

/// Answers and hits of a group of answers.
typedef Tally = ({int answered, int hits});

/// Questions per bar in the calibration chart.
const int calibrationBlockSize = 10;

/// Bars shown in the calibration chart (the most recent blocks).
const int calibrationMaxBlocks = 12;

/// Hit rate of each complete block of [blockSize] answers, oldest first,
/// keeping only the last [maxBlocks]. An unfinished block is left out.
List<double> hitRateBlocks(
  List<AnswerRecord> log, {
  int blockSize = calibrationBlockSize,
  int maxBlocks = calibrationMaxBlocks,
}) {
  final complete = log.length ~/ blockSize;
  final first = complete > maxBlocks ? complete - maxBlocks : 0;
  return List.unmodifiable([
    for (var b = first; b < complete; b++)
      log
              .sublist(b * blockSize, (b + 1) * blockSize)
              .where((r) => r.outcome == Outcome.hit)
              .length /
          blockSize,
  ]);
}

/// Answers and hits per category, in [QuestionCategory] order. Categories
/// without answers are left out.
Map<QuestionCategory, Tally> tallyByCategory(List<AnswerRecord> log) {
  final answered = <QuestionCategory, int>{};
  final hits = <QuestionCategory, int>{};
  for (final r in log) {
    answered.update(r.category, (n) => n + 1, ifAbsent: () => 1);
    if (r.outcome == Outcome.hit) {
      hits.update(r.category, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return {
    for (final c in QuestionCategory.values)
      if (answered.containsKey(c))
        c: (answered: answered[c]!, hits: hits[c] ?? 0),
  };
}

/// Minimum misses before a lean in their direction is reported.
const int minMissesForBias = 5;

/// Whether misses lean one way: [Outcome.tooHigh] or [Outcome.tooLow] when
/// at least two thirds of at least [minMissesForBias] misses do, else null.
Outcome? missBias(List<AnswerRecord> log) {
  var high = 0, low = 0;
  for (final r in log) {
    if (r.outcome == Outcome.tooHigh) high++;
    if (r.outcome == Outcome.tooLow) low++;
  }
  final misses = high + low;
  if (misses < minMissesForBias) return null;
  if (high * 3 >= misses * 2) return Outcome.tooHigh;
  if (low * 3 >= misses * 2) return Outcome.tooLow;
  return null;
}

/// Played days, rounded average and best of the daily totals.
({int days, int? average, int? best}) dailyScoreSummary(Iterable<int> totals) {
  if (totals.isEmpty) return (days: 0, average: null, best: null);
  final sum = totals.fold(0, (a, b) => a + b);
  return (
    days: totals.length,
    average: (sum / totals.length).round(),
    best: totals.reduce((a, b) => a > b ? a : b),
  );
}
