import 'package:aralik/data/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await stats.recordAnswer(questionId: 'q0001', hit: true);
    await stats.recordAnswer(questionId: 'dist:Q1:Q2', hit: false);
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
    await stats.recordAnswer(questionId: 'q1', hit: true);
    expect(calls, 1);
  });

  test('tracks daily progress, completion and streak', () async {
    final stats = await StatsStore.open();
    for (var i = 0; i < 4; i++) {
      await stats.recordAnswer(
        questionId: 'q$i',
        hit: true,
        dailyDay: 7,
        points: 50 + i,
      );
    }
    expect(stats.dailyResults(7).map((r) => r.points), [50, 51, 52, 53]);
    expect(stats.isDayComplete(7), isFalse);
    expect(stats.streak(7), 0);

    await stats.recordAnswer(
      questionId: 'q4',
      hit: false,
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
    await stats.recordAnswer(questionId: 'dist:Q1:Q2', hit: true);
    expect(stats.completedDays, isEmpty);
    expect(stats.dailyResults(0), isEmpty);
  });

  test('seenIds is read-only', () async {
    final stats = await StatsStore.open();
    expect(() => stats.seenIds.add('x'), throwsUnsupportedError);
  });
}
