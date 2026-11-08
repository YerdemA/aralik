import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_lobby_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SettingsStore> open(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final settings = await SettingsStore.open();
    final stats = await StatsStore.open();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelLobbyScreen(
          service: DuelService(
            serviceUri: () => Uri.parse('https://lb.example/'),
          ),
          repository: QuestionRepository(),
          stats: stats,
          settings: settings,
        ),
      ),
    );
    return settings;
  }

  FilledButton findButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text(AppStrings.duelFindOpponent),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ),
  );

  testWidgets('without a name the lobby sends the player to settings', (
    tester,
  ) async {
    await open(tester);
    // Only the room code is typed here, never the name.
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
    expect(find.text(AppStrings.duelNameNeeded), findsOneWidget);
    expect(findButton(tester).onPressed, isNull);
    await tester.tap(find.text(AppStrings.duelPickName));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a name from settings is shown and used', (tester) async {
    await open(tester, prefs: {'duel_name': 'Ayşe'});
    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text(AppStrings.duelNameNeeded), findsNothing);
    expect(findButton(tester).onPressed, isNotNull);
  });

  testWidgets('a name chosen later shows up at once', (tester) async {
    final settings = await open(tester);
    await settings.setUserName('Pars');
    await tester.pump();
    expect(find.text('Pars'), findsOneWidget);
    expect(find.text(AppStrings.duelNameNeeded), findsNothing);
  });

  testWidgets('one lobby for both duels: math is a choice at the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'duel_name': 'Ayşe'});
    final settings = await SettingsStore.open();
    final stats = await StatsStore.open();
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelLobbyScreen(
          service: DuelService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            request: (method, uri, [body]) async {
              calls.add('$method $uri');
              // Refused: the lobby stays, nothing else opens.
              return (status: 503, body: null);
            },
          ),
          repository: QuestionRepository(),
          stats: stats,
          settings: settings,
        ),
      ),
    );
    expect(find.text(AppStrings.duelKindBankHint), findsOneWidget);
    await tester.tap(find.text(AppStrings.duelKindMath));
    await tester.pump();
    expect(find.text(AppStrings.duelKindMathHint), findsOneWidget);
    await tester.tap(find.text(AppStrings.duelCreate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, ['POST https://lb.example/v1/duel/rooms?mode=math']);
  });
}
