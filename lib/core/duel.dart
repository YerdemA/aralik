/// Real-time 1v1 duel: room codes, the wire protocol and the match state
/// (pure Dart). The server side is server/leaderboard/src/duel.js; both
/// follow the protocol below.
///
/// Two players answer the same five questions at the same time, 15 s
/// each. A question is revealed when both locked or its time ran out. The
/// server scores every interval with the same formula as the app.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Must match DUEL_VERSION in duel.js; the server refuses other versions.
const int duelProtocolVersion = 1;

/// No I, L, O, 0 or 1: nothing to mix up when read aloud.
const String roomCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int roomCodeLength = 5;

/// [raw] as a room code (upper case, spaces dropped), or null if it cannot
/// be one.
String? normalizeRoomCode(String raw) {
  final code = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (code.length != roomCodeLength) return null;
  for (final c in code.split('')) {
    if (!roomCodeAlphabet.contains(c)) return null;
  }
  return code;
}

/// One player's locked interval on a revealed question. Null bounds: time
/// ran out with nothing typed.
typedef DuelResult = ({int? low, int? high, int points, bool hit});

/// A message from the room.
@immutable
sealed class DuelEvent {
  const DuelEvent();

  /// Parses one message; null for anything this version does not know.
  static DuelEvent? parse(String text) {
    try {
      final m = jsonDecode(text);
      if (m is! Map<String, dynamic>) return null;
      return switch (m['t']) {
        'waiting' => DuelWaiting(m['code'] as String),
        'start' => DuelStart(
          you: m['you'] as int,
          names: (m['names'] as List).cast<String>(),
          questionIds: (m['questions'] as List).cast<String>(),
          questionTime: Duration(milliseconds: m['questionMs'] as int),
        ),
        'question' => DuelQuestion(
          m['i'] as int,
          Duration(milliseconds: m['ms'] as int),
        ),
        'locked' => DuelLocked(m['i'] as int, m['seat'] as int),
        'reveal' => DuelReveal(
          index: m['i'] as int,
          results: [
            for (final r in (m['results'] as List).cast<Map<String, dynamic>>())
              (
                low: r['low'] as int?,
                high: r['high'] as int?,
                points: r['points'] as int,
                hit: r['hit'] as bool,
              ),
          ],
          totals: (m['totals'] as List).cast<int>(),
        ),
        'end' => DuelEnd(
          totals: (m['totals'] as List).cast<int>(),
          winner: m['winner'] as int?,
          opponentLeft: m['reason'] == 'left',
        ),
        'error' => DuelError(m['code'] as String),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

/// The room is open; the friend joins with [code].
class DuelWaiting extends DuelEvent {
  const DuelWaiting(this.code);
  final String code;
}

/// Both players are in. [you] is this player's seat (0 or 1).
class DuelStart extends DuelEvent {
  const DuelStart({
    required this.you,
    required this.names,
    required this.questionIds,
    required this.questionTime,
  });
  final int you;
  final List<String> names;
  final List<String> questionIds;
  final Duration questionTime;
}

/// Question [index] starts now, with [timeLeft] to lock.
class DuelQuestion extends DuelEvent {
  const DuelQuestion(this.index, this.timeLeft);
  final int index;
  final Duration timeLeft;
}

/// The player in [seat] locked question [index] (values come with the
/// reveal).
class DuelLocked extends DuelEvent {
  const DuelLocked(this.index, this.seat);
  final int index;
  final int seat;
}

/// Both intervals of question [index] and the running totals, by seat.
class DuelReveal extends DuelEvent {
  const DuelReveal({
    required this.index,
    required this.results,
    required this.totals,
  });
  final int index;
  final List<DuelResult> results;
  final List<int> totals;
}

/// The duel is over. [winner] is a seat, or null for a draw.
class DuelEnd extends DuelEvent {
  const DuelEnd({
    required this.totals,
    required this.winner,
    required this.opponentLeft,
  });
  final List<int> totals;
  final int? winner;
  final bool opponentLeft;
}

/// The room refused or closed: `no_room`, `room_full`, `room_closed`,
/// `expired`, `invalid_name`, `blocked_name`, `version`, …
class DuelError extends DuelEvent {
  const DuelError(this.code);
  final String code;
}

/// Messages to the room.
abstract final class DuelMessages {
  /// Locks question [index]; null bounds when time ran out empty.
  static String lock(int index, {int? low, int? high}) =>
      jsonEncode({'t': 'lock', 'i': index, 'low': low, 'high': high});

  /// Ready for the question after [index].
  static String next(int index) => jsonEncode({'t': 'next', 'i': index});
}

enum DuelPhase {
  /// Opening the connection.
  connecting,

  /// In the room, waiting for the friend.
  waiting,

  /// A question is open.
  question,

  /// A question was revealed; waiting for the next one.
  reveal,

  /// Finished (or the opponent left).
  over,

  /// Refused, closed or the connection dropped; see [DuelMatch.error].
  failed,
}

enum DuelOutcome { win, loss, draw }

/// How deep a revealed interval's card is tinted, 0…1. Hits get greener
/// with their points; misses get a deeper grey the further they missed
/// (the fewer points).
double duelTintStrength({required int points, required bool hit}) {
  final p = points.clamp(-50, 100);
  return hit ? (p + 50) / 150 : (100 - p) / 150;
}

/// The state of one duel as seen by this player, built from the room's
/// events. Seats are turned around so "me" and "opponent" read naturally.
class DuelMatch extends ChangeNotifier {
  DuelPhase _phase = DuelPhase.connecting;
  String? _code;
  int _you = 0;
  List<String> _names = const [];
  List<String> _questionIds = const [];
  Duration _questionTime = Duration.zero;
  int _index = -1;
  Duration _timeLeft = Duration.zero;
  bool _opponentLocked = false;
  final List<({DuelResult me, DuelResult opponent})> _results = [];
  List<int> _totals = const [0, 0];
  int? _winner;
  bool _opponentLeft = false;
  String? _error;

  DuelPhase get phase => _phase;

  /// The room code (known once the room said so, or set by [expectCode]).
  String? get code => _code;
  String get myName => _names.isEmpty ? '' : _names[_you];
  String get opponentName => _names.length < 2 ? '' : _names[1 - _you];
  List<String> get questionIds => _questionIds;
  Duration get questionTime => _questionTime;

  /// The open (or last revealed) question; -1 before the first.
  int get index => _index;

  /// Time left on question [index] when it was opened.
  Duration get timeLeft => _timeLeft;
  bool get opponentLocked => _opponentLocked;

  /// Revealed questions so far, in order.
  List<({DuelResult me, DuelResult opponent})> get results =>
      List.unmodifiable(_results);
  int get myTotal => _totals[_you];
  int get opponentTotal => _totals[1 - _you];
  bool get isLastQuestion => _index == _questionIds.length - 1;
  bool get opponentLeft => _opponentLeft;

  /// Error code of a failed duel.
  String? get error => _error;

  /// Null until the duel is over.
  DuelOutcome? get outcome {
    if (_phase != DuelPhase.over) return null;
    if (_winner == null) return DuelOutcome.draw;
    return _winner == _you ? DuelOutcome.win : DuelOutcome.loss;
  }

  /// Shows [code] while connecting to a friend's room.
  void expectCode(String code) {
    _code = code;
    notifyListeners();
  }

  void handle(DuelEvent event) {
    if (_phase == DuelPhase.over || _phase == DuelPhase.failed) return;
    switch (event) {
      case DuelWaiting(:final code):
        _code = code;
        _phase = DuelPhase.waiting;
      case DuelStart():
        _you = event.you;
        _names = event.names;
        _questionIds = event.questionIds;
        _questionTime = event.questionTime;
      case DuelQuestion(:final index, :final timeLeft):
        _index = index;
        _timeLeft = timeLeft;
        _opponentLocked = false;
        _phase = DuelPhase.question;
      case DuelLocked(:final index, :final seat):
        if (index == _index && seat != _you) _opponentLocked = true;
      case DuelReveal(:final index, :final results, :final totals):
        if (index != _results.length || results.length != 2) return;
        _results.add((me: results[_you], opponent: results[1 - _you]));
        _totals = totals;
        _phase = DuelPhase.reveal;
      case DuelEnd(:final totals, :final winner, :final opponentLeft):
        _totals = totals;
        _winner = winner;
        _opponentLeft = opponentLeft;
        _phase = DuelPhase.over;
      case DuelError(:final code):
        _error = code;
        _phase = DuelPhase.failed;
    }
    notifyListeners();
  }

  /// The connection dropped before the duel was over.
  void connectionLost() => handle(const DuelError('connection_lost'));
}
