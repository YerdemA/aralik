import 'dart:convert';

import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

TournamentEvent ev(Map<String, Object?> m) =>
    TournamentEvent.parse(jsonEncode(m))!;

Map<String, Object?> roomMsg({int host = 1, List<String>? names}) => {
  't': 'room',
  'code': 'K7M2P',
  'host': host,
  'count': 5,
  'players': [
    for (final (k, n) in (names ?? ['Ayşe', 'Bora']).indexed)
      {'id': k + 1, 'name': n},
  ],
  'min': 3,
  'max': 8,
};

void main() {
  test('players show the mascot they sent', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 1}))
      ..handle(
        ev({
          ...roomMsg(),
          'players': [
            {'id': 1, 'name': 'Ayşe', 'look': '120131212'},
            {'id': 2, 'name': 'Bora'},
          ],
        }),
      );
    expect(room.lookOf(1), MascotLook.parse('120131212'));
    expect(room.lookOf(2), MascotLook.philosopher);
    expect(room.lookOf(9), MascotLook.philosopher);
  });

  test('the lobby knows the host and when a round can start', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 1}))
      ..handle(ev(roomMsg()));
    expect(room.phase, TournamentPhase.lobby);
    expect(room.isHost, isTrue);
    expect(room.canStart, isFalse); // two of three
    room.handle(ev(roomMsg(names: ['Ayşe', 'Bora', 'Cem'])));
    expect(room.canStart, isTrue);
    room.handle(ev(roomMsg(host: 2, names: ['Ayşe', 'Bora', 'Cem'])));
    expect(room.isHost, isFalse);
    expect(room.canStart, isFalse);
  });

  test('a round: questions, reveals, standings, back to the room', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 2}))
      ..handle(ev(roomMsg(names: ['Ayşe', 'Bora', 'Cem'])))
      ..handle(
        ev({
          't': 'start',
          'questions': ['a'],
          'questionMs': 15000,
          'players': [
            {'id': 1, 'name': 'Ayşe'},
            {'id': 2, 'name': 'Bora'},
            {'id': 3, 'name': 'Cem'},
          ],
        }),
      )
      ..handle(ev({'t': 'question', 'i': 0, 'ms': 15000}));
    expect(room.phase, TournamentPhase.question);
    room.handle(ev({'t': 'locked', 'i': 0, 'id': 3}));
    expect(room.locked, {3});

    room
      ..handle(
        ev({
          't': 'reveal',
          'i': 0,
          'results': [
            {'id': 1, 'low': 1, 'high': 9, 'points': 40, 'hit': true},
            {'id': 2, 'low': 5, 'high': 6, 'points': 90, 'hit': true},
            {'id': 3, 'low': null, 'high': null, 'points': -50, 'hit': false},
          ],
        }),
      )
      ..handle(
        ev({
          't': 'end',
          'questions': 1,
          'standings': [
            {'id': 2, 'name': 'Bora', 'points': 90, 'hits': 1, 'left': false},
            {'id': 1, 'name': 'Ayşe', 'points': 40, 'hits': 1, 'left': false},
            {'id': 3, 'name': 'Cem', 'points': -50, 'hits': 0, 'left': true},
          ],
        }),
      );
    // The last reveal stays until the player asks for the standings.
    expect(room.phase, TournamentPhase.reveal);
    expect(room.roundOver, isTrue);
    expect(room.ranked(0).map((r) => r.id), [2, 1, 3]);
    expect(room.myResult(0)?.points, 90);
    expect(room.totals, {1: 40, 2: 90, 3: -50});

    room.showStandings();
    expect(room.phase, TournamentPhase.standings);
    expect(room.myRank, 1);
    expect(room.standings.last.left, isTrue);
    room.backToRoom();
    expect(room.phase, TournamentPhase.lobby);
  });

  test('a kicked player is not shown the closed connection', () {
    final room = TournamentRoom()
      ..handle(ev(roomMsg()))
      ..handle(ev({'t': 'kicked'}))
      ..connectionLost();
    expect(room.phase, TournamentPhase.kicked);
  });

  test('unknown or malformed messages are ignored', () {
    expect(TournamentEvent.parse('{"t":"nope"}'), isNull);
    expect(TournamentEvent.parse('not json'), isNull);
    expect(TournamentEvent.parse('{"t":"room"}'), isNull);
  });

  test('messages to the room', () {
    expect(jsonDecode(TournamentMessages.count(10)), {'t': 'count', 'n': 10});
    expect(jsonDecode(TournamentMessages.kick(3)), {'t': 'kick', 'id': 3});
    expect(jsonDecode(TournamentMessages.start()), {'t': 'start'});
  });

  test('a dropped player comes back to the match as it is', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 2, 'rejoin': 's2'}))
      ..handle(ev(roomMsg(names: ['Ayşe', 'Bora', 'Cem'])))
      ..handle(
        ev({
          't': 'start',
          'questions': ['a', 'b'],
          'questionMs': 15000,
          'players': [
            {'id': 1, 'name': 'Ayşe'},
            {'id': 2, 'name': 'Bora'},
            {'id': 3, 'name': 'Cem'},
          ],
        }),
      )
      ..handle(ev({'t': 'question', 'i': 0, 'ms': 15000}));
    final ids = room.questionIds;
    room.connectionLost();
    expect(room.reconnecting, isTrue);
    expect(room.phase, TournamentPhase.question);
    room.handle(
      ev({
        't': 'resume',
        'you': 2,
        'rejoin': 's2',
        'room': roomMsg(names: ['Ayşe', 'Bora', 'Cem']),
        'start': {
          't': 'start',
          'questions': ['a', 'b'],
          'questionMs': 15000,
          'players': [
            {'id': 1, 'name': 'Ayşe'},
            {'id': 2, 'name': 'Bora'},
            {'id': 3, 'name': 'Cem'},
          ],
        },
        'index': 1,
        'phase': 'question',
        'ms': 6000,
        'results': [
          [
            {'id': 1, 'low': 1, 'high': 9, 'points': 40, 'hit': true},
            {'id': 2, 'low': null, 'high': null, 'points': -50, 'hit': false},
            {'id': 3, 'low': 5, 'high': 6, 'points': 90, 'hit': true},
          ],
        ],
        'locked': [1],
      }),
    );
    expect(room.reconnecting, isFalse);
    expect(room.phase, TournamentPhase.question);
    expect(room.index, 1);
    expect(room.timeLeft, const Duration(seconds: 6));
    expect(room.locked, {1});
    expect(room.myLocked, isFalse);
    expect(room.myResult(0)?.points, -50);
    // Same round: the list is kept, so the screen keeps its input.
    expect(identical(room.questionIds, ids), isTrue);
  });

  test('a drop in the lobby comes back to the seat', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 1, 'rejoin': 's'}))
      ..handle(ev(roomMsg()))
      ..connectionLost();
    expect(room.reconnecting, isTrue);
    expect(room.phase, TournamentPhase.lobby);
    room.handle(ev({'t': 'welcome', 'you': 1, 'rejoin': 's'}));
    expect(room.reconnecting, isFalse);
    expect(room.phase, TournamentPhase.lobby);
  });

  test('a drop in the lobby without a secret loses the room', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 1}))
      ..handle(ev(roomMsg()))
      ..connectionLost();
    expect(room.phase, TournamentPhase.failed);
  });

  test('away players are shown', () {
    final msg = roomMsg(names: ['Ayşe', 'Bora', 'Cem']);
    (msg['players']! as List)[2] = {'id': 3, 'name': 'Cem', 'away': true};
    final room = TournamentRoom()
      ..handle(ev({'t': 'welcome', 'you': 1, 'rejoin': 's'}))
      ..handle(ev(msg));
    expect(room.players, hasLength(3));
    expect(room.isAway(3), isTrue);
    expect(room.isAway(2), isFalse);
    expect(room.canStart, isTrue);
    room.handle(ev(roomMsg(names: ['Ayşe', 'Bora', 'Cem'])));
    expect(room.isAway(3), isFalse);
  });

  test('a refusal stays the reason when the connection then closes', () {
    final room = TournamentRoom()
      ..handle(ev({'t': 'error', 'code': 'kicked'}))
      ..connectionLost();
    expect(room.phase, TournamentPhase.failed);
    expect(room.error, 'kicked');
  });

  test('going back with a secret tries again if dropped first', () {
    final room = TournamentRoom()..expectRejoin('K7M2P', 's2');
    expect(room.rejoin, 's2');
    room.connectionLost();
    expect(room.reconnecting, isTrue);
    expect(room.phase, TournamentPhase.connecting);
  });
}
