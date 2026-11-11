import 'dart:convert';

import 'package:aralik/core/duel.dart';
import 'package:aralik/core/ranked.dart';
import 'package:aralik/core/mascot_look.dart';
import 'package:flutter_test/flutter_test.dart';

String _msg(Map<String, Object?> m) => jsonEncode(m);

DuelEvent _parse(Map<String, Object?> m) => DuelEvent.parse(_msg(m))!;

const _bothHit = [
  (low: 1, high: 9, points: 40, hit: true),
  (low: 2, high: 3, points: 90, hit: true),
];

void main() {
  test('room codes: upper case, no spaces, no look-alike characters', () {
    expect(normalizeRoomCode(' ab cde '), 'ABCDE');
    expect(normalizeRoomCode('k7m2p'), 'K7M2P');
    expect(normalizeRoomCode('ABCD0'), isNull); // 0 is not used
    expect(normalizeRoomCode('ABCDI'), isNull); // nor I
    expect(normalizeRoomCode('ABCD'), isNull);
    expect(normalizeRoomCode('ABCDEF'), isNull);
    expect(roomCodeAlphabet.length, 31);
  });

  test('both mascots come with start; older servers send none', () {
    final match = DuelMatch()
      ..handle(
        _parse({
          't': 'start',
          'you': 1,
          'names': ['Ayşe', 'Bora'],
          'looks': ['120131212', null],
          'questions': ['q1'],
          'questionMs': 15000,
        }),
      );
    expect(match.opponentLook, MascotLook.parse('120131212'));
    expect(match.myLook, MascotLook.philosopher);
    final old = DuelMatch()
      ..handle(
        _parse({
          't': 'start',
          'you': 0,
          'names': ['Ayşe', 'Bora'],
          'questions': ['q1'],
          'questionMs': 15000,
        }),
      );
    expect(old.opponentLook, MascotLook.philosopher);
  });

  test('parses every message of the protocol', () {
    expect(
      (_parse({'t': 'waiting', 'code': 'ABCDE'}) as DuelWaiting).code,
      'ABCDE',
    );
    final start = _parse({
      't': 'start',
      'you': 1,
      'names': ['Ayşe', 'Bora'],
      'questions': ['q1', 'q2'],
      'questionMs': 15000,
    }) as DuelStart;
    expect(start.you, 1);
    expect(start.questionIds, ['q1', 'q2']);
    expect(start.questionTime, const Duration(seconds: 15));
    final question = _parse({'t': 'question', 'i': 2, 'ms': 14000});
    expect((question as DuelQuestion).timeLeft, const Duration(seconds: 14));
    final locked = _parse({'t': 'locked', 'i': 2, 'seat': 0}) as DuelLocked;
    expect(locked.seat, 0);
    final reveal = _parse({
      't': 'reveal',
      'i': 0,
      'results': [
        {'low': 1, 'high': 9, 'points': 40, 'hit': true},
        {'low': null, 'high': null, 'points': -50, 'hit': false},
      ],
      'totals': [40, -50],
    }) as DuelReveal;
    expect(reveal.results[1].low, isNull);
    expect(reveal.results[0].points, 40);
    expect(reveal.totals, [40, -50]);
    final end = _parse({
      't': 'end',
      'totals': [1, 2],
      'winner': null,
      'reason': 'left',
    }) as DuelEnd;
    expect(end.winner, isNull);
    expect(end.opponentLeft, isTrue);
    expect(
      (_parse({'t': 'error', 'code': 'room_full'}) as DuelError).code,
      'room_full',
    );
  });

  test('ignores unknown or broken messages', () {
    expect(DuelEvent.parse('nope'), isNull);
    expect(DuelEvent.parse(_msg({'t': 'chat'})), isNull);
    expect(DuelEvent.parse(_msg({'t': 'question', 'i': 'x'})), isNull);
  });

  test('outgoing messages match the server protocol', () {
    expect(jsonDecode(DuelMessages.lock(2, low: 10, high: 20)), {
      't': 'lock',
      'i': 2,
      'low': 10,
      'high': 20,
    });
    expect(jsonDecode(DuelMessages.lock(0)), {
      't': 'lock',
      'i': 0,
      'low': null,
      'high': null,
    });
    expect(jsonDecode(DuelMessages.next(3)), {'t': 'next', 'i': 3});
  });

  group('DuelMatch', () {
    DuelMatch started({int you = 1}) => DuelMatch()
      ..handle(const DuelWaiting('ABCDE'))
      ..handle(
        DuelStart(
          you: you,
          names: const ['Ayşe', 'Bora'],
          questionIds: const ['q1', 'q2'],
          questionTime: const Duration(seconds: 15),
        ),
      )
      ..handle(const DuelQuestion(0, Duration(seconds: 15)));

    DuelMatch ended(int? winner) => started()
      ..handle(
        DuelEnd(totals: const [1, 2], winner: winner, opponentLeft: false),
      );

    test('turns seats around to me and the opponent', () {
      final m = started();
      expect(m.phase, DuelPhase.question);
      expect(m.code, 'ABCDE');
      expect(m.myName, 'Bora');
      expect(m.opponentName, 'Ayşe');
      m.handle(const DuelLocked(0, 1));
      expect(m.opponentLocked, isFalse, reason: 'that was me');
      m.handle(const DuelLocked(0, 0));
      expect(m.opponentLocked, isTrue);
      m.handle(const DuelReveal(index: 0, results: _bothHit, totals: [40, 90]));
      expect(m.phase, DuelPhase.reveal);
      expect(m.results.single.me.points, 90);
      expect(m.results.single.opponent.points, 40);
      expect(m.myTotal, 90);
      expect(m.opponentTotal, 40);
      m.handle(const DuelQuestion(1, Duration(seconds: 15)));
      expect(m.opponentLocked, isFalse);
      expect(m.isLastQuestion, isTrue);
    });

    test('ends with a win, a loss or a draw', () {
      expect(ended(1).outcome, DuelOutcome.win);
      expect(ended(0).outcome, DuelOutcome.loss);
      expect(ended(null).outcome, DuelOutcome.draw);
      expect(started().outcome, isNull);
    });

    test('the monthly rating arrives after the end and is kept', () {
      final m = ended(1)
        ..handle(
          const DuelRated([
            (before: 140, after: 126),
            (before: 120, after: 138),
          ]),
        );
      expect(m.phase, DuelPhase.over);
      expect(m.rating, (before: 120, after: 138));
      expect(m.rating!.delta, 18);
      // Other messages after the end still do nothing.
      m.handle(const DuelQuestion(1, Duration(seconds: 15)));
      expect(m.phase, DuelPhase.over);
    });

    test('a failure is final', () {
      final m = started()..connectionLost();
      expect(m.phase, DuelPhase.failed);
      expect(m.error, 'connection_lost');
      m.handle(const DuelQuestion(1, Duration(seconds: 15)));
      expect(m.phase, DuelPhase.failed);
    });

    test('a reveal out of order is ignored', () {
      final m = started()
        ..handle(
          const DuelReveal(index: 1, results: _bothHit, totals: [40, 90]),
        );
      expect(m.results, isEmpty);
      expect(m.phase, DuelPhase.question);
    });
  });

  test('cards get deeper with the points: greener hits, greyer misses', () {
    expect(
      duelTintStrength(points: 95, hit: true),
      greaterThan(duelTintStrength(points: 20, hit: true)),
    );
    expect(
      duelTintStrength(points: -50, hit: false),
      greaterThan(duelTintStrength(points: 30, hit: false)),
    );
    for (final (points, hit) in [(-80, true), (100, true), (200, false)]) {
      final t = duelTintStrength(points: points, hit: hit);
      expect(t, inInclusiveRange(0, 1));
    }
  });

  test('a reveal says when the next question comes', () {
    final r =
        DuelEvent.parse(
              jsonEncode({
                't': 'reveal',
                'i': 0,
                'results': [
                  {'low': 1, 'high': 9, 'points': 40, 'hit': true},
                  {'low': 2, 'high': 3, 'points': 90, 'hit': true},
                ],
                'totals': [40, 90],
                'ms': 12000,
              }),
            )!
            as DuelReveal;
    expect(r.nextIn, const Duration(seconds: 12));
    final m = DuelMatch()
      ..handle(
        const DuelStart(
          you: 0,
          names: ['A', 'B'],
          questionIds: ['q1', 'q2'],
          questionTime: Duration(seconds: 15),
        ),
      )
      ..handle(const DuelQuestion(0, Duration(seconds: 15)))
      ..handle(r);
    expect(m.nextIn, const Duration(seconds: 12));
  });

  test('the search notes change every 15 seconds and wrap around', () {
    Duration s(int n) => Duration(seconds: n);
    expect(duelTipAt(s(0), first: 3, count: 5), 3);
    expect(duelTipAt(s(14), first: 3, count: 5), 3);
    expect(duelTipAt(s(15), first: 3, count: 5), 4);
    expect(duelTipAt(s(30), first: 3, count: 5), 0);
  });

  group('dropped connections', () {
    DuelMatch playing() => DuelMatch()
      ..handle(
        const DuelStart(
          you: 0,
          names: ['Ayşe', 'Bora'],
          questionIds: ['a', 'b'],
          questionTime: Duration(seconds: 15),
          rejoin: 's',
        ),
      )
      ..handle(const DuelQuestion(0, Duration(seconds: 15)));

    test('the opponent away: an open question runs on, a reveal waits', () {
      final m = playing();
      final clock = m.clock;
      m.handle(const DuelAway(1, Duration(seconds: 45)));
      // Nobody's question stops: no free time to look an answer up.
      expect(m.paused, isFalse);
      expect(m.opponentAway, isTrue);
      expect(m.awayLeft, const Duration(seconds: 45));
      // The open question's clock is not touched.
      expect(m.clock, clock);
      m.handle(
        const DuelReveal(
          index: 0,
          results: [
            (low: 1, high: 2, points: 10, hit: true),
            (low: null, high: null, points: -50, hit: false),
          ],
          totals: [10, -50],
          nextIn: Duration(seconds: 12),
        ),
      );
      expect(m.paused, isTrue);
      m.handle(const DuelBack(1, Duration(seconds: 7)));
      expect(m.paused, isFalse);
      expect(m.nextIn, const Duration(seconds: 7));
      // About this player: ignored (the room tells the other one).
      m.handle(const DuelAway(0, Duration(seconds: 60)));
      expect(m.paused, isFalse);
    });

    test('losing the connection in play means coming back, not failing', () {
      final m = playing()..connectionLost();
      expect(m.reconnecting, isTrue);
      expect(m.phase, DuelPhase.question);
      m.reconnectFailed();
      expect(m.phase, DuelPhase.failed);
      // Before the duel starts there is nothing to come back to.
      final waiting = DuelMatch()
        ..handle(const DuelWaiting('K7M2P'))
        ..connectionLost();
      expect(waiting.phase, DuelPhase.failed);
    });

    test('a resume rebuilds the duel as the room has it', () {
      final m = playing()..connectionLost();
      final event = DuelEvent.parse(
        jsonEncode({
          't': 'resume',
          'you': 1,
          'names': ['Bora', 'Ayşe'],
          'questions': ['a', 'b'],
          'questionMs': 15000,
          'rejoin': 's',
          'index': 0,
          'phase': 'reveal',
          'ms': 8000,
          'results': [
            [
              {'low': 1, 'high': 2, 'points': 10, 'hit': false},
              {'low': 3, 'high': 4, 'points': 90, 'hit': true},
            ],
          ],
          'totals': [10, 90],
          'locked': [true, true],
          'away': 0,
          'awayMs': 40000,
          'budget': 31000,
        }),
      )!;
      m.handle(event);
      expect(m.reconnecting, isFalse);
      expect(m.phase, DuelPhase.reveal);
      expect(m.myTotal, 90);
      expect(m.opponentName, 'Bora');
      expect(m.results.single.me.points, 90);
      expect(m.nextIn, const Duration(seconds: 8));
      expect(m.opponentAway, isTrue);
      expect(m.awayLeft, const Duration(seconds: 40));
      // This player's own time away left, for the home screen's card.
      expect(m.awayBudget, const Duration(seconds: 31));
      expect(DuelMatch().awayBudget, duelReconnectWindow);
    });
  });

  group('rematch', () {
    DuelMatch over({bool rematch = true}) {
      final m = DuelMatch();
      m.handle(
        _parse({
          't': 'start',
          'you': 1,
          'names': ['Bora', 'Ayşe'],
          'questions': ['q1'],
          'questionMs': 15000,
          'rejoin': 'tB',
        }),
      );
      m.handle(_parse({'t': 'question', 'i': 0, 'ms': 15000}));
      m.handle(
        _parse({
          't': 'end',
          'totals': [10, 20],
          'winner': 1,
          'reason': 'done',
          'rematch': rematch,
        }),
      );
      return m;
    }

    test('offered only when the room says so', () {
      expect(over().rematch, RematchState.available);
      final old = over(rematch: false);
      expect(old.rematch, RematchState.unavailable);
      expect(old.askRematch(), isFalse);
    });

    test('asking, being asked, and both at once', () {
      final asker = over();
      expect(asker.askRematch(), isTrue);
      expect(asker.rematch, RematchState.asked);
      expect(asker.askRematch(), isFalse);
      // The other one asked too: the room is starting again.
      asker.handle(_parse({'t': 'rematch', 'seat': 0}));
      expect(asker.rematch, RematchState.starting);

      final asked = over();
      asked.handle(_parse({'t': 'rematch', 'seat': 0}));
      expect(asked.rematch, RematchState.offered);
      // Its own echo changes nothing.
      asked.handle(_parse({'t': 'rematch', 'seat': 1}));
      expect(asked.rematch, RematchState.offered);
      expect(asked.askRematch(), isTrue); // accept
      expect(asked.rematch, RematchState.starting);
    });

    test('no, left, expired and no questions close it', () {
      for (final (reason, state) in [
        ('no', RematchState.declined),
        ('left', RematchState.gone),
        ('expired', RematchState.expired),
        ('no_questions', RematchState.noQuestions),
      ]) {
        final m = over()..askRematch();
        m.handle(
          _parse({
            't': 'rematch_no',
            'seat': reason == 'no' || reason == 'left' ? 0 : null,
            'reason': reason,
          }),
        );
        expect(m.rematch, state, reason: reason);
      }
      final refusing = over();
      expect(refusing.declineRematch(), isTrue);
      expect(refusing.rematch, RematchState.refused);
      expect(refusing.declineRematch(), isFalse);
    });

    test('a lost connection after the end ends the offer', () {
      final m = over()..askRematch();
      m.connectionLost();
      expect(m.phase, DuelPhase.over);
      expect(m.rematch, RematchState.gone);
    });

    test('a new round starts from nothing, same players', () {
      final m = over()..askRematch();
      m.handle(_parse({'t': 'rematch', 'seat': 0}));
      m.handle(
        _parse({
          't': 'start',
          'you': 1,
          'names': ['Bora', 'Ayşe'],
          'questions': ['q7', 'q8'],
          'questionMs': 15000,
          'rejoin': 'nB',
          'round': 2,
        }),
      );
      expect(m.round, 2);
      expect(m.phase, DuelPhase.connecting);
      expect(m.results, isEmpty);
      expect((m.myTotal, m.opponentTotal), (0, 0));
      expect(m.outcome, isNull);
      expect(m.rematch, RematchState.unavailable);
      expect(m.rejoin, 'nB');
      m.handle(_parse({'t': 'question', 'i': 0, 'ms': 15000}));
      expect((m.phase, m.index), (DuelPhase.question, 0));
      expect(m.questionIds, ['q7', 'q8']);
    });
  });
}
