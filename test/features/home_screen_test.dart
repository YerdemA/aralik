import 'package:aralik/core/app_update.dart';
import 'package:aralik/core/daily.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
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
  int? latestAppBuild,
  Future<bool> Function()? openStore,
  bool withServer = false,
}) async {
  HomeScreen.updateOffered = false;
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
        latestAppBuild: () => latestAppBuild,
        openStore: openStore ?? () async => true,
        leaderboard: withServer
            ? LeaderboardStore(
                await SharedPreferences.getInstance(),
                serviceUri: () => Uri.parse('https://lb.example/'),
              )
            : null,
      ),
    ),
  );
  return stats;
}

void main() {
  final today = dayIndexFor(DateTime.now());

  testWidgets('offers a newer build on Google Play once per launch', (
    tester,
  ) async {
    var opened = 0;
    await pumpHome(
      tester,
      latestAppBuild: appBuild + 1,
      openStore: () async {
        opened++;
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.updateTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.updateNow));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text(AppStrings.updateTitle), findsNothing);
    expect(HomeScreen.updateOffered, isTrue);
  });

  testWidgets('the duel sits between the daily set and free play', (
    tester,
  ) async {
    await pumpHome(tester, withServer: true);
    await tester.pumpAndSettle();
    final today = tester.getCenter(find.text(AppStrings.playToday)).dy;
    final duel = tester.getCenter(find.text(AppStrings.duel)).dy;
    final free = tester.getCenter(find.text(AppStrings.freePlay)).dy;
    expect(today, lessThan(duel));
    expect(duel, lessThan(free));
  });

  testWidgets('no duel without a server', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.duel), findsNothing);
  });

  testWidgets('says nothing when this build is the newest', (tester) async {
    await pumpHome(tester, latestAppBuild: appBuild);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.updateTitle), findsNothing);
  });

  testWidgets('fresh install offers today\'s set', (tester) async {
    await pumpHome(tester);
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
    expect(find.text(AppStrings.todayDone), findsOneWidget);
    expect(find.text(AppStrings.scoreOutOf(287, 500)), findsOneWidget);
    expect(find.text(AppStrings.share), findsOneWidget);
    expect(find.text(AppStrings.playToday), findsNothing);
    // Free play takes over as the main card.
    expect(find.text(AppStrings.freePlay), findsOneWidget);
    expect(find.text(AppStrings.newRound), findsOneWidget);
    expect(find.text(AppStrings.todayTitle), findsNothing);
    expect(find.text(AppStrings.streakDays(1)), findsOneWidget);
    expect(find.text('287'), findsOneWidget); // last score
  });

  testWidgets('the date and weekday are on today\'s card', (tester) async {
    await pumpHome(tester);
    expect(find.text(dayLabelWithWeekday(dateOfDay(today))), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    await pumpHome(tester);
    tester.view.physicalSize = const Size(960, 1600); // 320 x 533 dp
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finished day fits a small phone too', (tester) async {
    await pumpHome(
      tester,
      prefs: {
        'daily_results_$today': ['100:1', '75:1', '40:1', '0:0', '72:1'],
        'completed_days': ['$today'],
      },
    );
    tester.view.physicalSize = const Size(960, 1600); // 320 x 533 dp
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
