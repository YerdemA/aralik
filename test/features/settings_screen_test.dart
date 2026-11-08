import 'dart:io';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/attributions.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/features/settings/attributions_screen.dart';
import 'package:aralik/features/settings/connection_test_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sources = [
  Attribution(
    name: 'Wikidata',
    attribution: 'Wikidata, Wikimedia Vakfı.',
    license: 'CC0 1.0',
    licenseUrl: 'https://www.wikidata.org/wiki/Wikidata:Licensing',
    url: 'https://www.wikidata.org/',
  ),
];

Widget app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Future<SettingsStore> settingsStore([Map<String, Object> prefs = const {}]) {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsStore.open();
}

void main() {
  testWidgets('settings lists data sources, licenses and privacy', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(SettingsScreen(settings: await settingsStore())),
    );
    expect(find.text(AppStrings.dataSources), findsOneWidget);
    expect(find.text(AppStrings.openSourceLicenses), findsOneWidget);
    expect(find.text(AppStrings.privacyPolicyUrl), findsOneWidget);
    // No server, nothing to test.
    expect(find.text(AppStrings.netTest), findsNothing);
  });

  testWidgets('with a server the connection test opens from settings', (
    tester,
  ) async {
    final store = LeaderboardStore(
      await SharedPreferences.getInstance(),
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
      request: (method, uri, [body]) async => (status: 200, body: null),
    );
    await tester.pumpWidget(
      app(SettingsScreen(settings: await settingsStore(), leaderboard: store)),
    );
    await tester.tap(find.text(AppStrings.netTest));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionTestScreen), findsOneWidget);
    expect(find.text(AppStrings.netTestRun), findsOneWidget);
  });

  testWidgets('choosing a theme updates and keeps it', (tester) async {
    final settings = await settingsStore();
    expect(settings.themeMode, ThemeMode.system);
    await tester.pumpWidget(app(SettingsScreen(settings: settings)));

    await tester.tap(find.text(AppStrings.themeDark));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect((await SettingsStore.open()).themeMode, ThemeMode.dark);

    await tester.tap(find.text(AppStrings.themeLight));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.light);
  });

  test('an unknown stored theme falls back to the system', () async {
    final settings = await settingsStore({'theme_mode': 'sepia'});
    expect(settings.themeMode, ThemeMode.system);
  });

  testWidgets('sound effects are on by default and can be turned off', (
    tester,
  ) async {
    final settings = await settingsStore();
    expect(settings.soundOn, isTrue);
    await tester.pumpWidget(app(SettingsScreen(settings: settings)));
    await tester.tap(find.text(AppStrings.soundEffects));
    await tester.pumpAndSettle();
    expect(settings.soundOn, isFalse);
    expect((await SettingsStore.open()).soundOn, isFalse);
  });

  testWidgets('the app follows the chosen theme', (tester) async {
    final settings = await settingsStore({'theme_mode': 'dark'});
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: const Scaffold(),
        ),
      ),
    );
    BuildContext ctx() => tester.element(find.byType(Scaffold));
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    await settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);
  });

  testWidgets('the sources screen shows each credit and license', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(AttributionsScreen(load: () async => _sources)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wikidata'), findsOneWidget);
    expect(find.text('Wikidata, Wikimedia Vakfı.'), findsOneWidget);
    expect(find.text('${AppStrings.license}: CC0 1.0'), findsOneWidget);
    expect(find.text('https://www.wikidata.org/'), findsOneWidget);
  });

  test('the bundled attributions parse and name Wikidata', () {
    final sources = parseAttributions(
      File(attributionsAssetPath).readAsStringSync(),
    );
    expect(sources.map((s) => s.name), contains('Wikidata'));
    for (final s in sources) {
      expect(s.url, startsWith('https://'));
      expect(s.licenseUrl, startsWith('https://'));
    }
  });

  test('parseAttributions rejects incomplete entries', () {
    expect(() => parseAttributions('{}'), throwsFormatException);
    expect(
      () => parseAttributions('[{"name": "X", "attribution": "Y"}]'),
      throwsFormatException,
    );
  });

  testWidgets('the one name is chosen in settings', (tester) async {
    final settings = await settingsStore();
    await tester.pumpWidget(app(SettingsScreen(settings: settings)));
    expect(find.text(AppStrings.userNameUnset), findsOneWidget);
    await tester.tap(find.text(AppStrings.userNameUnset));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.nicknameTooShort), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Ayşe ');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(settings.userName, 'Ayşe');
    expect(find.text('Ayşe'), findsOneWidget);
    // The first choice is free; a change then waits three days.
    expect(settings.nextNameChange(), isNull);

    await tester.tap(find.text('Ayşe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bora');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(settings.userName, 'Bora');
    final next = settings.nextNameChange();
    expect(next, isNotNull);
    expect(find.text(AppStrings.userNameNextChange(next!)), findsOneWidget);

    await tester.tap(find.text('Bora'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.renameWait(next)), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });

  testWidgets('while joined a change renames on the leaderboard too', (
    tester,
  ) async {
    final settings = await settingsStore({'duel_name': 'Ayşe'});
    final prefs = await SharedPreferences.getInstance();
    final sent = <String, Object?>{};
    var wait = false;
    final store = LeaderboardStore(
      prefs,
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
      request: (method, uri, [body]) async {
        sent[uri.path] = body;
        return switch (uri.path) {
          '/v1/register' => (
            status: 201,
            body: {'id': 'p1', 'token': 't', 'nickname': body!['nickname']},
          ),
          '/v1/rename' when wait => (
            status: 429,
            body: {
              'error': 'rename_wait',
              'retry_at': DateTime(2026, 11, 20).millisecondsSinceEpoch,
            },
          ),
          '/v1/rename' => (status: 200, body: {'nickname': body!['nickname']}),
          _ => (status: 200, body: const <String, Object?>{}),
        };
      },
    );
    await store.join('Ayşe');
    await tester.pumpWidget(
      app(SettingsScreen(settings: settings, leaderboard: store)),
    );
    expect(find.text(AppStrings.leaveLeaderboardHint), findsOneWidget);

    await tester.tap(find.text('Ayşe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bora');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect((sent['/v1/rename']! as Map)['nickname'], 'Bora');
    expect(store.account?.nickname, 'Bora');
    expect(settings.userName, 'Bora');

    // The server knows of a later change than the app: its date wins.
    await settings.freeNameChange();
    wait = true;
    await tester.tap(find.text('Bora'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cem');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(settings.userName, 'Bora');
    expect(
      settings.nextNameChange(DateTime(2026, 11, 19)),
      DateTime(2026, 11, 20),
    );
    expect(
      find.text(AppStrings.renameWait(DateTime(2026, 11, 20))),
      findsOneWidget,
    );
  });

  testWidgets('leaving the table keeps the name', (tester) async {
    final settings = await settingsStore({'duel_name': 'Ayşe'});
    final store = LeaderboardStore(
      await SharedPreferences.getInstance(),
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
      request: (method, uri, [body]) async => switch (uri.path) {
        '/v1/register' => (
          status: 201,
          body: {'id': 'p1', 'token': 't', 'nickname': 'Ayşe'},
        ),
        _ => (status: 200, body: const <String, Object?>{}),
      },
    );
    await store.join('Ayşe');
    await tester.pumpWidget(
      app(SettingsScreen(settings: settings, leaderboard: store)),
    );
    await tester.tap(find.text(AppStrings.leaveLeaderboard));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaveConfirmBody), findsOneWidget);
    await tester.tap(find.text(AppStrings.leave));
    await tester.pumpAndSettle();
    expect(store.joined, isFalse);
    expect(settings.userName, 'Ayşe');
    expect(find.text(AppStrings.leaveLeaderboard), findsNothing);
  });

  testWidgets('the tour can be played again from settings', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = await settingsStore({
      'tour_home_seen': true,
      'tour_guess_seen': true,
      'tour_range_seen': true,
    });
    bool? replay;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              replay = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(settings: settings),
                ),
              );
            },
            child: const Text('ayarlar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ayarlar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.tourReplay),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.tourReplay));
    await tester.pumpAndSettle();
    expect(replay, isTrue); // home starts it
    for (final part in TourPart.values) {
      expect(settings.tourSeen(part), isFalse);
    }
  });
}
