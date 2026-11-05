import 'dart:convert';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/duel_client_test.dart' show FakeChannel;

void main() {
  testWidgets('waits, plays a question against the opponent, sees the result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = await tester.runAsync(repository.load);
    final question = bank!.first;

    final channel = FakeChannel();
    final service = DuelService(
      serviceUri: () => Uri.parse('https://lb.example/'),
      connect: (_) async => channel,
    );
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    bool? popped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => DuelScreen(
                    service: service,
                    repository: repository,
                    stats: stats,
                    code: 'K7M2P',
                    name: 'Ayşe',
                  ),
                ),
              );
            },
            child: const Text('start'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await settle();
    // Let the screen load the bank and connect.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle();

    say({'t': 'waiting', 'code': 'K7M2P'});
    await settle();
    expect(find.text('K7M2P'), findsOneWidget);
    expect(find.text(AppStrings.duelShareCode), findsOneWidget);

    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [question.id],
      'questionMs': 15000,
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    await settle();
    expect(find.text(question.text), findsOneWidget);
    expect(find.byTooltip(AppStrings.duelOpponentThinking), findsOneWidget);

    say({'t': 'locked', 'i': 0, 'seat': 1});
    await settle();
    expect(find.byTooltip(AppStrings.duelOpponentLocked), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text(AppStrings.next));
    await settle();
    await tester.tap(find.text(AppStrings.lock));
    await settle();
    expect(find.text(AppStrings.duelWaitingOpponent), findsOneWidget);
    final lock = jsonDecode(channel.sent.single) as Map<String, dynamic>;
    expect(lock['t'], 'lock');
    expect(lock['i'], 0);
    expect(lock['low'], lessThanOrEqualTo(1));
    expect(stats.seenIds, contains(question.id));

    say({
      't': 'reveal',
      'i': 0,
      'results': [
        {'low': lock['low'], 'high': lock['high'], 'points': 12, 'hit': false},
        {'low': null, 'high': null, 'points': -50, 'hit': false},
      ],
      'totals': [12, -50],
    });
    say({
      't': 'end',
      'totals': [12, -50],
      'winner': 0,
      'reason': 'done',
    });
    await settle();
    expect(find.text(AppStrings.duelAnswer), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(find.text(AppStrings.duelNoInterval), findsOneWidget);

    await tester.tap(find.text(AppStrings.duelSeeResult));
    await settle();
    expect(find.text(AppStrings.duelWin), findsOneWidget);

    await tester.tap(find.text(AppStrings.duelPlayAgain));
    await settle();
    expect(popped, isTrue);
    await tester.pumpAndSettle(); // the screen is gone: its connection closes
    expect(channel.closed, isTrue);
  });

  testWidgets('shows why a room cannot be joined', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final channel = FakeChannel();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: DuelService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            connect: (_) async => channel,
          ),
          repository: QuestionRepository(),
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    channel.incoming.add(jsonEncode({'t': 'error', 'code': 'no_room'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.duelErrorText('no_room')), findsOneWidget);
  });

  testWidgets('finds a random opponent, then joins the room it names', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final lobby = FakeChannel();
    final room = FakeChannel();
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: DuelService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            connect: (uri) async {
              opened.add(uri);
              return uri.path.endsWith('random') ? lobby : room;
            },
          ),
          repository: QuestionRepository(),
          stats: stats,
          code: null,
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text(AppStrings.duelSearching), findsOneWidget);

    lobby.incoming.add(jsonEncode({'t': 'matched', 'code': 'K7M2P'}));
    await tester.pump();
    await tester.pump();
    room.incoming.add(jsonEncode({'t': 'waiting', 'code': 'K7M2P'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened.last.path, '/v1/duel/rooms/K7M2P');
    // A random duel never shows the room code.
    expect(find.text(AppStrings.duelFound), findsOneWidget);
    expect(find.text('K7M2P'), findsNothing);

    // The opponent never comes.
    await tester.pump(const Duration(seconds: 21));
    expect(find.text(AppStrings.duelNoShow), findsOneWidget);
  });
}
