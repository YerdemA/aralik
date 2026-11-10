import 'dart:convert';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/sound.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/data/tournament_client.dart';
import 'package:aralik/features/tournament/tournament_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/duel_client_test.dart' show FakeChannel;

void main() {
  late FakeChannel channel;
  late StatsStore stats;
  late QuestionRepository repository;

  Map<String, Object?> room({int host = 1, int players = 3}) => {
    't': 'room',
    'code': 'K7M2P',
    'host': host,
    'count': 5,
    'players': [
      for (var k = 1; k <= players; k++)
        {
          'id': k,
          'name': ['Ayşe', 'Bora', 'Cem', 'Deniz'][k - 1],
        },
    ],
    'min': 3,
    'max': 8,
  };

  Future<void Function(Map<String, Object?>)> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    stats = await StatsStore.open();
    repository = QuestionRepository();
    await tester.runAsync(repository.load);
    channel = FakeChannel();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TournamentScreen(
          service: TournamentService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            connect: (_) async => channel,
          ),
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    return (m) => channel.incoming.add(jsonEncode(m));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<Map<String, dynamic>> sent() => [
    for (final s in channel.sent) jsonDecode(s) as Map<String, dynamic>,
  ];

  testWidgets('the host sees the crown, picks 10, kicks and starts', (
    tester,
  ) async {
    final say = await open(tester);
    say({'t': 'welcome', 'you': 1});
    say(room(players: 2));
    await settle(tester);
    expect(find.text('K7M2P'), findsOneWidget);
    expect(find.byTooltip(AppStrings.tournamentHost), findsOneWidget);
    expect(find.text(AppStrings.tournamentNeedPlayers(3)), findsOneWidget);

    say(room());
    await settle(tester);
    expect(find.text(AppStrings.tournamentPlayers(3, 8)), findsOneWidget);
    await tester.tap(find.text(AppStrings.tournamentQuestionCount(10)));
    await settle(tester);
    expect(sent().last, {'t': 'count', 'n': 10});

    // Remove Bora, after a confirmation.
    await tester.tap(find.byTooltip(AppStrings.tournamentKick).first);
    await settle(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.tournamentKick),
    );
    await settle(tester);
    expect(sent().last, {'t': 'kick', 'id': 2});

    await tester.tap(find.text(AppStrings.tournamentStart));
    await settle(tester);
    expect(sent().last, {'t': 'start'});
  });

  testWidgets('a guest plays a round and sees the standings', (tester) async {
    final played = Sounds.played = [];
    addTearDown(() => Sounds.played = null);
    final say = await open(tester);
    final question = (await tester.runAsync(repository.load))!.first;
    say({'t': 'welcome', 'you': 2});
    say(room());
    await settle(tester);
    expect(find.text(AppStrings.tournamentWaitHost), findsOneWidget);
    expect(find.byTooltip(AppStrings.tournamentKick), findsNothing);

    say({
      't': 'start',
      'questions': [question.id],
      'questionMs': 15000,
      'players': [
        {'id': 1, 'name': 'Ayşe'},
        {'id': 2, 'name': 'Bora'},
        {'id': 3, 'name': 'Cem'},
      ],
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    await settle(tester);
    expect(find.text(question.text), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text(AppStrings.next));
    await settle(tester);
    await tester.tap(find.text(AppStrings.lock));
    await settle(tester);
    final lock = sent().last;
    expect(lock['t'], 'lock');
    expect(stats.seenIds, contains(question.id));

    say({
      't': 'reveal',
      'i': 0,
      'results': [
        {'id': 1, 'low': 1, 'high': 9, 'points': 40, 'hit': true},
        {
          'id': 2,
          'low': lock['low'],
          'high': lock['high'],
          'points': 90,
          'hit': true,
        },
        {'id': 3, 'low': null, 'high': null, 'points': -50, 'hit': false},
      ],
    });
    say({
      't': 'end',
      'questions': 1,
      'standings': [
        {'id': 2, 'name': 'Bora', 'points': 90, 'hits': 1, 'left': false},
        {'id': 1, 'name': 'Ayşe', 'points': 40, 'hits': 1, 'left': false},
        {'id': 3, 'name': 'Cem', 'points': -50, 'hits': 0, 'left': true},
      ],
    });
    say(room());
    await settle(tester);
    expect(find.text(AppStrings.duelAnswer), findsOneWidget);
    expect(find.text(AppStrings.duelNoInterval), findsOneWidget);

    await tester.tap(find.text(AppStrings.tournamentSeeStandings));
    await settle(tester);
    expect(find.text(AppStrings.tournamentStandings), findsOneWidget);
    expect(find.text(AppStrings.tournamentHits(1, 1)), findsNWidgets(2));
    expect(find.textContaining(AppStrings.tournamentLeft), findsOneWidget);
    expect(played.first, Sfx.duelStart);
    expect(played.last, Sfx.duelWin);

    // The standings can be shared.
    await tester.tap(find.text(AppStrings.share));
    await settle(tester);
    expect(find.text(AppStrings.shareTextOnly), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    await tester.tap(find.text(AppStrings.tournamentBackToRoom));
    await settle(tester);
    expect(find.text(AppStrings.tournamentWaitHost), findsOneWidget);
  });

  testWidgets('a kicked player is told so', (tester) async {
    final say = await open(tester);
    say({'t': 'welcome', 'you': 3});
    say(room());
    say({'t': 'kicked'});
    await settle(tester);
    expect(find.text(AppStrings.tournamentKicked), findsOneWidget);
  });

  testWidgets('a room in play turns newcomers away', (tester) async {
    final say = await open(tester);
    say({'t': 'error', 'code': 'in_progress'});
    await settle(tester);
    expect(
      find.text(AppStrings.tournamentErrorText('in_progress')),
      findsOneWidget,
    );
  });
}
