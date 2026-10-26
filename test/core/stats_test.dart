import 'package:aralik/core/daily.dart';
import 'package:aralik/core/scoring.dart';
import 'package:aralik/core/stats.dart';
import 'package:aralik/data/question.dart';
import 'package:flutter_test/flutter_test.dart';

AnswerRecord r(
  Outcome outcome, {
  QuestionCategory category = QuestionCategory.geography,
  int points = 0,
}) => (category: category, points: points, outcome: outcome);

List<AnswerRecord> hits(int hit, int miss) => [
  for (var i = 0; i < hit; i++) r(Outcome.hit),
  for (var i = 0; i < miss; i++) r(Outcome.tooHigh),
];

void main() {
  group('Outcome.of', () {
    test('inside, including the bounds, is a hit', () {
      expect(Outcome.of(10, 20, 10), Outcome.hit);
      expect(Outcome.of(10, 20, 15), Outcome.hit);
      expect(Outcome.of(10, 20, 20), Outcome.hit);
    });

    test('an interval above the answer is too high', () {
      expect(Outcome.of(10, 20, 9), Outcome.tooHigh);
    });

    test('an interval below the answer is too low', () {
      expect(Outcome.of(10, 20, 21), Outcome.tooLow);
    });
  });

  group('hitRateBlocks', () {
    test('no complete block yields nothing', () {
      expect(hitRateBlocks(hits(9, 0)), isEmpty);
    });

    test('one rate per complete block, the rest left out', () {
      final log = [...hits(9, 1), ...hits(5, 5), ...hits(3, 0)];
      expect(hitRateBlocks(log), [0.9, 0.5]);
    });

    test('keeps the most recent blocks', () {
      final log = [for (var b = 0; b < 5; b++) ...hits(b, 10 - b)];
      expect(hitRateBlocks(log, maxBlocks: 2), [0.3, 0.4]);
    });
  });

  test('tallyByCategory counts per category in enum order', () {
    final tally = tallyByCategory([
      r(Outcome.hit, category: QuestionCategory.sports),
      r(Outcome.tooLow, category: QuestionCategory.history),
      r(Outcome.hit, category: QuestionCategory.history),
      r(Outcome.tooHigh, category: QuestionCategory.sports),
      r(Outcome.hit, category: QuestionCategory.sports),
    ]);
    expect(tally.keys, [QuestionCategory.history, QuestionCategory.sports]);
    expect(tally[QuestionCategory.history], (answered: 2, hits: 1));
    expect(tally[QuestionCategory.sports], (answered: 3, hits: 2));
    expect(tallyByCategory(const []), isEmpty);
  });

  group('missBias', () {
    List<AnswerRecord> misses(int high, int low) => [
      for (var i = 0; i < high; i++) r(Outcome.tooHigh),
      for (var i = 0; i < low; i++) r(Outcome.tooLow),
      ...hits(20, 0),
    ];

    test('needs enough misses', () {
      expect(missBias(misses(4, 0)), isNull);
    });

    test('two thirds one way is a lean', () {
      expect(missBias(misses(4, 2)), Outcome.tooHigh);
      expect(missBias(misses(2, 4)), Outcome.tooLow);
    });

    test('a balanced split is no lean', () {
      expect(missBias(misses(3, 3)), isNull);
    });
  });

  test('dailyScoreSummary', () {
    expect(dailyScoreSummary(const []), (days: 0, average: null, best: null));
    expect(dailyScoreSummary([300, -20, 401]), (
      days: 3,
      average: 227,
      best: 401,
    ));
  });

  test('longestStreak finds the longest run', () {
    expect(longestStreak({}), 0);
    expect(longestStreak({5}), 1);
    expect(longestStreak({1, 2, 3, 7, 8, 10, 11, 12, 13}), 4);
  });
}
