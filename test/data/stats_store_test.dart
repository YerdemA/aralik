import 'package:aralik/core/scoring.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _geo = QuestionCategory.geography;

Outcome _outcome(bool hit) => hit ? Outcome.hit : Outcome.tooHigh;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts empty', () async {
    final stats = await StatsStore.open();
    expect(stats.seenIds, isEmpty);
    expect(stats.answered, 0);
    expect(stats.hits, 0);
  });

  test('records answers and persists them', () async {
    final stats = await StatsStore.open();
    await stats.recordAnswer(
      questionId: 'q0001',
      category: _geo,
      outcome: Outcome.hit,
    );
    await stats.recordAnswer(
      questionId: 'dist:Q1:Q2',
      category: _geo,
      outcome: Outcome.tooLow,
    );
    expect(stats.seenIds, {'q0001', 'dist:Q1:Q2'});
    expect(stats.answered, 2);
    expect(stats.hits, 1);

    final reopened = await StatsStore.open();
    expect(reopened.seenIds, {'q0001', 'dist:Q1:Q2'});
    expect(reopened.answered, 2);
    expect(reopened.hits, 1);
  });

  test('notifies listeners', () async {
    final stats = await StatsStore.open();
    var calls = 0;
    stats.addListener(() => calls++);
    await stats.recordAnswer(
      questionId: 'q1',
      category: _geo,
      outcome: Outcome.hit,
    );
    expect(calls, 1);
  });

  test('tracks daily progress, completion and streak', () async {
    final stats = await StatsStore.open();
    for (var i = 0; i < 4; i++) {
      await stats.recordAnswer(
        questionId: 'q$i',
        category: _geo,
        outcome: _outcome(true),
        dailyDay: 7,
        points: 50 + i,
      );
    }
    expect(stats.dailyResults(7).map((r) => r.points), [50, 51, 52, 53]);
    expect(stats.isDayComplete(7), isFalse);
    expect(stats.streak(7), 0);

    await stats.recordAnswer(
      questionId: 'q4',
      category: _geo,
      outcome: _outcome(false),
      dailyDay: 7,
      points: 0,
    );
    expect(stats.isDayComplete(7), isTrue);
    expect(stats.streak(7), 1);
    expect(stats.streak(8), 1); // alive until day 8 is over
    expect(stats.lastCompletedDay(8), 7);
    expect(stats.lastCompletedDay(6), isNull);

    final reopened = await StatsStore.open();
    expect(reopened.dailyResults(7), [
      (points: 50, hit: true),
      (points: 51, hit: true),
      (points: 52, hit: true),
      (points: 53, hit: true),
      (points: 0, hit: false),
    ]);
    expect(reopened.completedDays, {7});
    expect(reopened.answered, 5);
    expect(reopened.hits, 4);
  });

  test('free-play answers do not touch daily progress', () async {
    final stats = await StatsStore.open();
    await stats.recordAnswer(
      questionId: 'dist:Q1:Q2',
      category: _geo,
      outcome: Outcome.hit,
    );
    expect(stats.completedDays, isEmpty);
    expect(stats.dailyResults(0), isEmpty);
  });

  test('seenIds is read-only', () async {
    final stats = await StatsStore.open();
    expect(() => stats.seenIds.add('x'), throwsUnsupportedError);
  });

  test('keeps an answer log across launches', () async {
    final stats = await StatsStore.open();
    await stats.recordAnswer(
      questionId: 'q1',
      category: QuestionCategory.history,
      outcome: Outcome.tooLow,
      points: -40,
    );
    await stats.recordAnswer(
      questionId: 'q2',
      category: QuestionCategory.sports,
      outcome: Outcome.hit,
      points: 85,
    );
    final expected = [
      (
        category: QuestionCategory.history,
        points: -40,
        outcome: Outcome.tooLow,
      ),
      (category: QuestionCategory.sports, points: 85, outcome: Outcome.hit),
    ];
    expect(stats.answerLog, expected);
    expect((await StatsStore.open()).answerLog, expected);
  });

  test('skips log entries it cannot read', () async {
    SharedPreferences.setMockInitialValues({
      'answer_log': ['geography:85:h', 'nope', 'music:10:h', 'tarih:x:h'],
    });
    final stats = await StatsStore.open();
    expect(stats.answerLog, [
      (category: QuestionCategory.geography, points: 85, outcome: Outcome.hit),
    ]);
  });
}
