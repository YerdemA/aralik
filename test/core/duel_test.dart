import 'dart:convert';

import 'package:aralik/core/duel.dart';
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
}
