import 'package:aralik/core/daily.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/home/home_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:aralik/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StatsStore> pumpHome(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final stats = await StatsStore.open();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: HomeScreen(
        repository: QuestionRepository(),
        stats: stats,
        settings: await SettingsStore.open(),
      ),
    ),
  );
  return stats;
}

void main() {
  final today = dayIndexFor(DateTime.now());

  testWidgets('fresh install offers today\'s set', (tester) async {
    await pumpHome(tester);
    expect(find.text(AppStrings.previewEdition), findsNothing);
    expect(find.text(AppStrings.playToday), findsOneWidget);
    expect(find.text(AppStrings.freePlay), findsOneWidget);
    expect(find.text(AppStrings.streakDays(0)), findsOneWidget);
    expect(find.text(AppStrings.calibrationNoData), findsOneWidget);
  });

  testWidgets('a half-played day can be continued', (tester) async {
    await pumpHome(
      tester,
      prefs: {
        'daily_results_$today': ['80:1', '-20:0'],
      },
    );
    expect(find.text(AppStrings.continueToday(2, 5)), findsOneWidget);
  });

  testWidgets('a finished day shows the score and share', (tester) async {
    await pumpHome(
      tester,
      prefs: {
        'daily_results_$today': ['100:1', '75:1', '40:1', '0:0', '72:1'],
        'completed_days': ['$today'],
        'answered': 5,
        'hits': 4,
      },
    );
    expect(find.text('${AppStrings.todayDone}: 287 / 500'), findsOneWidget);
    expect(find.text(AppStrings.share), findsOneWidget);
    expect(find.text(AppStrings.playToday), findsNothing);
    expect(find.text(AppStrings.streakDays(1)), findsOneWidget);
    expect(find.text('287'), findsOneWidget); // last score
  });

  testWidgets('the chart icon opens the stats screen', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip(AppStrings.stats));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
  });

  testWidgets('the gear icon opens settings', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip(AppStrings.settings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
