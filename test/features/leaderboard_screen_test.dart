import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/features/leaderboard/leaderboard_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _board({bool withMe = false}) => {
  'day': 3,
  'players': 12,
  'limit': 10,
  'top': [
    {'rank': 1, 'nickname': 'Aslan', 'points': 480, 'hits': 5, 'me': false},
    {'rank': 2, 'nickname': 'Pars', 'points': 410, 'hits': 4, 'me': false},
  ],
  'me': withMe ? {'rank': 7, 'points': 210, 'hits': 3} : null,
};

void main() {
  late LeaderboardStore store;
  late SettingsStore settings;
  late List<String> paths;
  late bool withMe;
  late bool taken;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    paths = [];
    withMe = false;
    taken = false;
    settings = SettingsStore(prefs);
    store = LeaderboardStore(
      prefs,
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
      request: (method, uri, [body]) async {
        paths.add(uri.path);
        return switch (uri.path) {
          '/v1/register' when taken => (
            status: 409,
            body: {'error': 'nickname_taken'},
          ),
          '/v1/register' => (
            status: 201,
            body: {'id': 'p1', 'token': 't', 'nickname': body!['nickname']},
          ),
          '/v1/day/3' => (status: 200, body: _board(withMe: withMe)),
          _ => (status: 200, body: const <String, Object?>{}),
        };
      },
    );
  });

  Future<void> open(WidgetTester tester, {bool dayDone = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LeaderboardScreen(
          store: store,
          settings: settings,
          day: 3,
          dayDone: dayDone,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the board and invites to join', (tester) async {
    await open(tester);
    expect(find.text('Aslan'), findsOneWidget);
    expect(find.text('480'), findsOneWidget);
    expect(
      find.textContaining(AppStrings.leaderboardPlayers(12)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.leaderboardJoin), findsOneWidget);
  });

  testWidgets('without a name, joining sends the player to settings', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text(AppStrings.leaderboardJoin));
    await tester.pumpAndSettle();
    // The name is never typed here.
    expect(find.byType(TextField), findsNothing);
    expect(find.text(AppStrings.leaderboardJoinNeedsName), findsOneWidget);
    await tester.tap(find.text(AppStrings.openSettings));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(paths, isNot(contains('/v1/register')));
  });

  testWidgets('a taken name can be changed in settings without waiting', (
    tester,
  ) async {
    await settings.setUserName('Aslan');
    await settings.setUserName('Kaplan'); // a change: the wait starts
    expect(settings.nextNameChange(), isNotNull);
    taken = true;
    await open(tester);
    await tester.tap(find.text(AppStrings.leaderboardJoin));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.join));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardNameTaken), findsOneWidget);
    expect(store.joined, isFalse);
    expect(settings.nextNameChange(), isNull);
  });

  testWidgets('joining with the name from settings', (tester) async {
    await settings.setUserName('Kaplan');
    await open(tester);
    await tester.tap(find.text(AppStrings.leaderboardJoin));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text(AppStrings.leaderboardJoinBody('Kaplan')), findsOneWidget);
    await tester.tap(find.text(AppStrings.join));
    await tester.pumpAndSettle();
    expect(store.account?.nickname, 'Kaplan');
    expect(find.text(AppStrings.joinedAs('Kaplan')), findsOneWidget);
    expect(find.text(AppStrings.leaderboardJoin), findsNothing);
    expect(find.text(AppStrings.leaderboardFinishSet), findsOneWidget);
  });

  testWidgets('own row below the top', (tester) async {
    await store.join('Kaplan');
    withMe = true;
    await open(tester, dayDone: true);
    expect(find.text('Kaplan (${AppStrings.you})'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text(AppStrings.leaderboardSendFailed), findsNothing);
  });

  testWidgets('offline shows a retry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store = LeaderboardStore(
      await SharedPreferences.getInstance(),
      serviceUri: () => Uri.parse('https://lb.example/'),
      deviceKey: () async => null,
      request: (method, uri, [body]) async => throw Exception('offline'),
    );
    await open(tester);
    expect(find.text(AppStrings.leaderboardOffline), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  test('the first three get gold, silver and bronze frames', () {
    expect(Medal.ofRank(1), Medal.gold);
    expect(Medal.ofRank(2), Medal.silver);
    expect(Medal.ofRank(3), Medal.bronze);
    expect(Medal.ofRank(4), isNull);
    expect(Medal.ofRank(0), isNull);
  });
}
