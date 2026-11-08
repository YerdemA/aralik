import 'dart:convert';

import 'package:aralik/core/duel.dart';
import 'package:aralik/core/math/math_problem.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/sound.dart';
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
    final played = Sounds.played = [];
    addTearDown(() => Sounds.played = null);

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
    expect(played, isNot(contains(Sfx.duelWin)));

    await tester.tap(find.text(AppStrings.duelSeeResult));
    await settle();
    expect(find.text(AppStrings.duelWin), findsOneWidget);
    expect(played.first, Sfx.duelStart);
    expect(played.where((s) => s == Sfx.duelWin), hasLength(1));
    expect(played.last, Sfx.duelWin);

    await tester.tap(find.text(AppStrings.duelPlayAgain));
    await settle();
    expect(popped, isTrue);
    await tester.pumpAndSettle(); // the screen is gone: its connection closes
    expect(channel.closed, isTrue);
  });

  testWidgets('shows why a room cannot be joined', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    // The bank parses on a background isolate: load it before the clock
    // stops being real.
    final repository = QuestionRepository();
    await tester.runAsync(repository.load);
    final channel = FakeChannel();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: DuelService(
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
    final repository = QuestionRepository();
    await tester.runAsync(repository.load);
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
          repository: repository,
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

  testWidgets('a reveal counts down; going on waits for the other side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final channel = FakeChannel();
    var clock = DateTime(2026, 11, 5, 12);
    Future<void> wait(Duration d) async {
      clock = clock.add(d);
      await tester.pump(d);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: DuelService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            connect: (_) async => channel,
          ),
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
          now: () => clock,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      // Short ones: the test font is much wider than Roboto.
      'questions': [
        for (final q in [
          ...bank,
        ]..sort((a, b) => a.text.length.compareTo(b.text.length)))
          q.id,
      ].take(2).toList(),
      'questionMs': 15000,
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    await tester.pump();
    expect(find.text(AppStrings.questionProgress(1, 2)), findsOneWidget);
    // A room that does not say how long it waits: the default is shown.
    say({
      't': 'reveal',
      'i': 0,
      'results': [
        {'low': null, 'high': null, 'points': -50, 'hit': false},
        {'low': null, 'high': null, 'points': -50, 'hit': false},
      ],
      'totals': [-50, -50],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(AppStrings.duelNextIn(duelRevealWait.inSeconds)),
      findsOneWidget,
    );
    await wait(const Duration(seconds: 3));
    expect(
      find.text(AppStrings.duelNextIn(duelRevealWait.inSeconds - 3)),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.next));
    await tester.pump();
    expect(find.text(AppStrings.duelWaitingOther), findsOneWidget);
    expect(jsonDecode(channel.sent.last), {'t': 'next', 'i': 0});

    // The next question: the button and the countdown are gone.
    say({'t': 'question', 'i': 1, 'ms': 15000});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.questionProgress(2, 2)), findsOneWidget);
    expect(find.text(AppStrings.duelWaitingOther), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a dropped connection pauses the duel and comes back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = (await tester.runAsync(repository.load))!;
    final question = bank.first;
    final first = FakeChannel();
    final second = FakeChannel();
    final opened = <Uri>[];
    var clock = DateTime(2026, 11, 7, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: DuelService(
            serviceUri: () => Uri.parse('https://lb.example/'),
            connect: (uri) async {
              opened.add(uri);
              return opened.length == 1 ? first : second;
            },
          ),
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
          now: () => clock,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    void say(FakeChannel c, Map<String, Object?> m) =>
        c.incoming.add(jsonEncode(m));
    say(first, {
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [question.id],
      'questionMs': 15000,
      'rejoin': 'sec',
    });
    say(first, {'t': 'question', 'i': 0, 'ms': 15000});
    await settle();
    expect(find.text(question.text), findsOneWidget);

    // Bora drops mid-question: a note, and the question goes on for us.
    say(first, {'t': 'away', 'seat': 1, 'ms': 45000});
    await settle();
    expect(
      find.text(AppStrings.duelOpponentAwayQuestion('Bora')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.duelOpponentAway('Bora')), findsNothing);
    expect(find.text(question.text), findsOneWidget);
    clock = clock.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    say(first, {'t': 'back', 'seat': 1, 'ms': 10000});
    await settle();
    expect(
      find.text(AppStrings.duelOpponentAwayQuestion('Bora')),
      findsNothing,
    );

    // Our connection drops: covered, and back with the secret.
    await first.incoming.close();
    await settle();
    expect(find.text(AppStrings.reconnecting), findsOneWidget);
    expect(opened.last.queryParameters['rejoin'], 'sec');
    say(second, {
      't': 'resume',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [question.id],
      'questionMs': 15000,
      'rejoin': 'sec',
      'index': 0,
      'phase': 'question',
      'ms': 10000,
      'results': <Object>[],
      'totals': [0, 0],
      'locked': [false, false],
      'away': null,
      'awayMs': null,
    });
    await settle();
    expect(find.text(AppStrings.reconnecting), findsNothing);
    expect(find.text(question.text), findsOneWidget);
    // The clock runs on from the room's 10 s: it times out and locks.
    clock = clock.add(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 1));
    final lock = jsonDecode(second.sent.single) as Map<String, dynamic>;
    expect(lock['t'], 'lock');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a rematch: asked by the opponent, accepted, played again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = await tester.runAsync(repository.load);
    final first = bank![0];
    final second = bank[1];

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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: service,
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle();

    void start(String id, int round, String rejoin) {
      say({
        't': 'start',
        'you': 0,
        'names': ['Ayşe', 'Bora'],
        'questions': [id],
        'questionMs': 15000,
        'rejoin': rejoin,
        'round': round,
      });
      say({'t': 'question', 'i': 0, 'ms': 15000});
    }

    start(first.id, 1, 'tA');
    await settle();
    expect(find.text(first.text), findsOneWidget);
    say({
      't': 'reveal',
      'i': 0,
      'results': [
        {'low': null, 'high': null, 'points': -50, 'hit': false},
        {'low': null, 'high': null, 'points': -50, 'hit': false},
      ],
      'totals': [-50, -50],
    });
    say({
      't': 'end',
      'totals': [-50, -50],
      'winner': null,
      'reason': 'done',
      'rematch': true,
    });
    await settle();
    await tester.tap(find.text(AppStrings.duelSeeResult));
    await settle();
    expect(find.text(AppStrings.duelRematch), findsOneWidget);
    // With a rematch on offer, a new search is the second choice.
    expect(
      find.widgetWithText(OutlinedButton, AppStrings.duelPlayAgain),
      findsOneWidget,
    );

    say({'t': 'rematch', 'seat': 1});
    await settle();
    expect(find.text(AppStrings.duelRematchOffer('Bora')), findsOneWidget);
    channel.sent.clear();
    await tester.tap(find.text(AppStrings.duelRematchAccept));
    await settle();
    expect(channel.sent, [DuelMessages.rematch()]);
    expect(find.text(AppStrings.duelRematchStarting), findsOneWidget);

    // Same room, same screen: the next duel's first question.
    start(second.id, 2, 'nA');
    await settle();
    expect(find.text(second.text), findsOneWidget);
    expect(find.text(AppStrings.duelWaitingOpponent), findsNothing);
    expect(find.text(AppStrings.duelRematchStarting), findsNothing);
  });

  testWidgets('a rematch request the opponent turns down', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    final bank = await tester.runAsync(repository.load);
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: service,
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle();
    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [bank!.first.id],
      'questionMs': 15000,
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
    say({
      't': 'end',
      'totals': [0, 0],
      'winner': null,
      'reason': 'left',
    });
    await settle();
    // Not played to the end: no rematch.
    expect(find.text(AppStrings.duelRematch), findsNothing);
    expect(
      find.widgetWithText(FilledButton, AppStrings.duelPlayAgain),
      findsOneWidget,
    );
  });

  testWidgets('a math duel makes its questions from their ids', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsStore.open();
    final repository = QuestionRepository();
    await tester.runAsync(repository.load);
    final channel = FakeChannel();
    final service = DuelService(
      serviceUri: () => Uri.parse('https://lb.example/'),
      connect: (_) async => channel,
    );
    var clock = DateTime(2026, 11, 8, 12);
    void say(Map<String, Object?> m) => channel.incoming.add(jsonEncode(m));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DuelScreen(
          service: service,
          repository: repository,
          stats: stats,
          code: 'K7M2P',
          name: 'Ayşe',
          math: true,
          now: () => clock,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle();
    const id = 'math:carpma:1:12345';
    final problem = mathProblemFromId(id)!;
    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [id],
      'questionMs': 30000,
    });
    say({'t': 'question', 'i': 0, 'ms': 30000});
    await settle();
    expect(find.text(problem.text), findsOneWidget);
    expect(find.text(AppStrings.duelMissingQuestions), findsNothing);
    // Time runs out with nothing typed: 0 here, never −50; math stats.
    clock = clock.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    await settle();
    final lock = jsonDecode(channel.sent.last) as Map<String, dynamic>;
    expect(lock['t'], 'lock');
    expect((stats.mathAnswered, stats.answered), (1, 0));
    expect(stats.seenIds, isEmpty);
  });
}
