import 'dart:convert';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/duel_client.dart';
import 'package:aralik/data/pending_match.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/data/question_repository.dart';
import 'package:aralik/data/stats_store.dart';
import 'package:aralik/features/duel/duel_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/duel_client_test.dart' show FakeChannel;

/// Leaving a duel and going back to it: the close button's choices, the
/// duel kept on the phone, and coming back with the secret.
void main() {
  late StatsStore stats;
  late QuestionRepository repository;
  late PendingMatchStore pending;
  late List<Uri> uris;
  late List<FakeChannel> channels;
  late DuelService service;
  late Question question;

  Future<void> setUpDuel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    stats = StatsStore(prefs);
    pending = PendingMatchStore(prefs);
    repository = QuestionRepository();
    question = (await tester.runAsync(repository.load))!.first;
    uris = [];
    channels = [];
    service = DuelService(
      serviceUri: () => Uri.parse('https://lb.example/'),
      connect: (uri) async {
        uris.add(uri);
        final c = FakeChannel();
        channels.add(c);
        return c;
      },
    );
  }

  void say(Map<String, Object?> m) => channels.last.incoming.add(jsonEncode(m));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> open(WidgetTester tester, {String? rejoin}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DuelScreen(
                  service: service,
                  repository: repository,
                  stats: stats,
                  code: 'K7M2P',
                  name: 'Ayşe',
                  rejoin: rejoin,
                  pending: pending,
                ),
              ),
            ),
            child: const Text('start'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
  }

  void start() {
    say({
      't': 'start',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [question.id],
      'questionMs': 15000,
      'rejoin': 's0',
    });
    say({'t': 'question', 'i': 0, 'ms': 15000});
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.byTooltip(AppStrings.quit));
    await settle(tester);
    expect(find.text(AppStrings.duelQuitBody), findsOneWidget);
  }

  testWidgets('the duel is kept while played; "Çık" leaves it to go back to', (
    tester,
  ) async {
    await setUpDuel(tester);
    await open(tester);
    start();
    await settle(tester);
    final kept = pending.current!;
    expect(kept.kind, PendingKind.duel);
    expect(kept.code, 'K7M2P');
    expect(kept.rejoin, 's0');
    expect(kept.name, 'Ayşe');

    // "Kal" keeps playing.
    await tapClose(tester);
    await tester.tap(find.text(AppStrings.duelStay));
    await settle(tester);
    expect(find.text(question.text), findsOneWidget);

    await tapClose(tester);
    await tester.tap(find.text(AppStrings.quit));
    await tester.pumpAndSettle();
    expect(find.text('start'), findsOneWidget);
    expect(channels.last.closed, isTrue);
    // Nothing given up: the room waits and the duel can be gone back to.
    expect(
      channels.last.sent.map(jsonDecode),
      isNot(contains(equals({'t': 'resign'}))),
    );
    expect(pending.current?.rejoin, 's0');
    expect(pending.current!.isLive(DateTime.now()), isTrue);
  });

  testWidgets('"Teslim ol" gives the duel up and forgets it', (tester) async {
    await setUpDuel(tester);
    await open(tester);
    start();
    await settle(tester);
    await tapClose(tester);
    await tester.tap(find.text(AppStrings.duelResign));
    await tester.pumpAndSettle();
    expect(find.text('start'), findsOneWidget);
    expect(
      channels.last.sent.map(jsonDecode),
      contains(equals({'t': 'resign'})),
    );
    expect(pending.current, isNull);
  });

  testWidgets('going back resumes with the secret; the end forgets it', (
    tester,
  ) async {
    await setUpDuel(tester);
    await pending.save(
      PendingMatch(
        kind: PendingKind.duel,
        code: 'K7M2P',
        rejoin: 's0',
        name: 'Ayşe',
        until: DateTime.now().add(const Duration(seconds: 40)),
      ),
    );
    await open(tester, rejoin: 's0');
    expect(uris.single.queryParameters['rejoin'], 's0');
    say({
      't': 'resume',
      'you': 0,
      'names': ['Ayşe', 'Bora'],
      'questions': [question.id],
      'questionMs': 15000,
      'rejoin': 's0',
      'index': 0,
      'phase': 'question',
      'ms': 8000,
      'results': <Object>[],
      'totals': [0, 0],
      'locked': [false, true],
      'away': null,
      'awayMs': null,
    });
    await settle(tester);
    expect(find.text(question.text), findsOneWidget);
    expect(find.byTooltip(AppStrings.duelOpponentLocked), findsOneWidget);
    say({
      't': 'end',
      'totals': [0, 30],
      'winner': 1,
      'reason': 'done',
    });
    await settle(tester);
    expect(pending.current, isNull);
  });

  testWidgets('a duel that ended meanwhile says so and is forgotten', (
    tester,
  ) async {
    await setUpDuel(tester);
    await pending.save(
      PendingMatch(
        kind: PendingKind.duel,
        code: 'K7M2P',
        rejoin: 's0',
        name: 'Ayşe',
        until: DateTime.now().add(const Duration(seconds: 40)),
      ),
    );
    await open(tester, rejoin: 's0');
    say({'t': 'error', 'code': 'no_room'});
    await settle(tester);
    expect(find.text(AppStrings.duelEnded), findsOneWidget);
    expect(pending.current, isNull);
  });
}
