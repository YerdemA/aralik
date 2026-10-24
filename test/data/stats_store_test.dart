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

  test('seenIds is read-only', () async {
    final stats = await StatsStore.open();
    expect(() => stats.seenIds.add('x'), throwsUnsupportedError);
  });
}
