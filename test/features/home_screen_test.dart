import 'package:aralik/core/app_update.dart';
import 'package:aralik/core/daily.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/pending_match.dart';
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
  PendingMatchStore? Function(SharedPreferences prefs)? pending,
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
        pending: pending?.call(await SharedPreferences.getInstance()),
        leaderboard: withServer
            ? LeaderboardStore(
                await SharedPreferences.getInstance(),
                serviceUri: () => Uri.parse('https://lb.example/'),
                deviceKey: () async => null,
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

  testWidgets('duel and free play sit side by side under the daily set', (
    tester,
  ) async {
    await pumpHome(tester, withServer: true);
    await tester.pumpAndSettle();
    final today = tester.getCenter(find.text(AppStrings.playToday));
    Offset tile(String title) => tester.getCenter(
      find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first,
    );
    final duel = tile(AppStrings.duel);
    final free = tile(AppStrings.freePlay);
    expect(today.dy, lessThan(duel.dy));
    expect(duel.dy, closeTo(free.dy, 1));
    expect(duel.dx, lessThan(free.dx));
  });

  testWidgets('a set played here before the data was cleared is locked', (
    tester,
  ) async {
    await pumpHome(
      tester,
      withServer: true,
      prefs: {
        'lb_device_played': ['$today'],
        'lb_device_checked': today,
      },
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.todayPlayedBefore), findsOneWidget);
    expect(find.text(AppStrings.playToday), findsNothing);
    await tester.tap(find.text(AppStrings.todayPlayedBefore));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.todayPlayedBefore), findsOneWidget);
  });

  testWidgets('once today is done, free play leads and the duel sits below', (
    tester,
  ) async {
    await pumpHome(
      tester,
      withServer: true,
      prefs: {
        'daily_results_$today': ['90:1', '80:1', '70:1', '-50:0', '60:1'],
        'completed_days': ['$today'],
        'lb_device_checked': today,
      },
    );
    await tester.pumpAndSettle();
    final newRound = tester.getCenter(find.text(AppStrings.newRound));
    final duel = tester.getCenter(find.text(AppStrings.duel));
    expect(newRound.dy, lessThan(duel.dy));
    // Today's board is only in the header, not a second time down here.
    expect(find.text(AppStrings.leaderboard), findsNothing);
  });

  testWidgets('modes still to come are shown but do nothing', (tester) async {
    await pumpHome(tester);
    expect(find.text(AppStrings.modeMath), findsOneWidget);
    expect(find.text(AppStrings.modeTournament), findsOneWidget);
    expect(find.text(AppStrings.comingSoon), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.text(AppStrings.modeMath),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
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
    // Only the streak is left of the stats, on today's card.
    expect(find.text(AppStrings.streakPill(0)), findsOneWidget);
    expect(find.text(AppStrings.calibrationNoData), findsNothing);
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
    expect(find.text(AppStrings.streakPill(1)), findsOneWidget);
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

  group('a match left behind', () {
    String record(Duration fromNow) => PendingMatch(
      kind: PendingKind.duel,
      code: 'K7M2P',
      rejoin: 's0',
      name: 'Ayşe',
      until: DateTime.now().add(fromNow),
    ).toJsonString();

    testWidgets('offers to go back or give up while the room waits', (
      tester,
    ) async {
      late PendingMatchStore store;
      await pumpHome(
        tester,
        prefs: {'pending_match': record(const Duration(seconds: 45))},
        pending: (prefs) => store = PendingMatchStore(prefs),
      );
      await tester.pump();
      expect(find.text(AppStrings.pendingDuelTitle), findsOneWidget);
      expect(find.text(AppStrings.pendingJoin), findsOneWidget);
      await tester.tap(find.text(AppStrings.duelResign));
      await tester.pump();
      expect(store.current, isNull);
      expect(find.text(AppStrings.pendingDuelTitle), findsNothing);
    });

    testWidgets('one whose time ran out is forgotten, with a word', (
      tester,
    ) async {
      late PendingMatchStore store;
      await pumpHome(
        tester,
        prefs: {'pending_match': record(const Duration(seconds: -5))},
        pending: (prefs) => store = PendingMatchStore(prefs),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(AppStrings.pendingDuelTitle), findsNothing);
      expect(find.text(AppStrings.pendingDuelExpired), findsOneWidget);
      expect(store.current, isNull);
    });
  });
}
