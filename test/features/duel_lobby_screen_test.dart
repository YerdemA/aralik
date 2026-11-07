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
    String? suggested,
  }) async {
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
          suggestedName: suggested,
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
    expect(find.byType(TextField), findsOneWidget);
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

  testWidgets('the leaderboard nickname stands in until one is chosen', (
    tester,
  ) async {
    final settings = await open(tester, suggested: 'Kaplan');
    expect(find.text('Kaplan'), findsOneWidget);
    await settings.setDuelName('Pars');
    await tester.pump();
    expect(find.text('Pars'), findsOneWidget);
  });
}
