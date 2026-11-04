import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/leaderboard.dart';
import 'package:aralik/features/leaderboard/leaderboard_screen.dart';
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
  late List<String> paths;
  late bool withMe;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    paths = [];
    withMe = false;
    store = LeaderboardStore(
      prefs,
      serviceUri: () => Uri.parse('https://lb.example/'),
      request: (method, uri, [body]) async {
        paths.add(uri.path);
        return switch (uri.path) {
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
        home: LeaderboardScreen(store: store, day: 3, dayDone: dayDone),
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

  testWidgets('joining with a nickname', (tester) async {
    await open(tester);
    await tester.tap(find.text(AppStrings.leaderboardJoin));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text(AppStrings.join));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.nicknameTooShort), findsOneWidget);
    expect(paths, isNot(contains('/v1/register')));

    await tester.enterText(find.byType(TextField), '  Kaplan ');
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
      request: (method, uri, [body]) async => throw Exception('offline'),
    );
    await open(tester);
    expect(find.text(AppStrings.leaderboardOffline), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
}
