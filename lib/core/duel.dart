/// Real-time 1v1 duel: room codes, the wire protocol and the match state
/// (pure Dart). The server side is server/leaderboard/src/duel.js; both
/// follow the protocol below.
///
/// Two players answer the same five questions at the same time, 15 s
/// each. A question is revealed when both locked or its time ran out. The
/// server scores every interval with the same formula as the app.
///
/// A dropped connection does not end the duel: the app comes back with its
/// rejoin secret; the room then sends the whole duel so far ([DuelResume]).
/// Each player has [duelReconnectWindow] of time away for the whole duel.
/// An open question does not stop for anyone (the one away loses its
/// seconds), only a revealed one waits for them: dropping out to look an
/// answer up gains nothing.
///
/// After a duel played to the end the two can ask for a rematch
/// ([RematchState]): once both want it the same room starts again with new
/// questions, no new code or search.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'mascot_look.dart';
import 'ranked.dart';

/// Must match DUEL_VERSION in duel.js; the server refuses other versions.
const int duelProtocolVersion = 1;

/// How long the room waits on a revealed question before the next one
/// (REVEAL_MS in duel.js). The room says so in each reveal; this is for a
/// room that does not.
const Duration duelRevealWait = Duration(seconds: 12);

/// A player's time away for the whole duel (AWAY_BUDGET_MS in duel.js);
/// the app keeps trying to come back for at most this long.
const Duration duelReconnectWindow = Duration(seconds: 45);

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

/// The mascot codes of a `start` or `resume` (by seat); older servers
/// send none.
List<String?> _parseLooks(Object? list) {
  if (list is! List || list.length != 2) return const [null, null];
  return [for (final l in list) l is String ? l : null];
}

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
          looks: _parseLooks(m['looks']),
          questionIds: (m['questions'] as List).cast<String>(),
          questionTime: Duration(milliseconds: m['questionMs'] as int),
          rejoin: m['rejoin'] as String?,
          round: m['round'] as int? ?? 1,
          ranked: m['ranked'] == true,
        ),
        'rated' => DuelRated([
          for (final r in (m['ratings'] as List).cast<Map<String, dynamic>>())
            (before: r['before'] as int, after: r['after'] as int),
        ]),
        'rematch' => DuelRematch(m['seat'] as int),
        'rematch_no' => DuelRematchNo(
          m['seat'] as int?,
          m['reason'] as String? ?? 'no',
        ),
        'away' => DuelAway(
          m['seat'] as int,
          Duration(milliseconds: m['ms'] as int),
        ),
        'back' => DuelBack(
          m['seat'] as int,
          Duration(milliseconds: m['ms'] as int),
        ),
        'resume' => DuelResume(
          you: m['you'] as int,
          names: (m['names'] as List).cast<String>(),
          looks: _parseLooks(m['looks']),
          questionIds: (m['questions'] as List).cast<String>(),
          questionTime: Duration(milliseconds: m['questionMs'] as int),
          rejoin: m['rejoin'] as String?,
          index: m['index'] as int,
          revealed: m['phase'] == 'reveal',
          left: Duration(milliseconds: m['ms'] as int),
          results: [
            for (final pair in (m['results'] as List).cast<List>())
              [for (final r in pair.cast<Map<String, dynamic>>()) _result(r)],
          ],
          totals: (m['totals'] as List).cast<int>(),
          locked: (m['locked'] as List).cast<bool>(),
          away: m['away'] as int?,
          awayLeft: m['awayMs'] is int
              ? Duration(milliseconds: m['awayMs'] as int)
              : null,
          budget: m['budget'] is int
              ? Duration(milliseconds: m['budget'] as int)
              : null,
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
              _result(r),
          ],
          totals: (m['totals'] as List).cast<int>(),
          nextIn: m['ms'] is int
              ? Duration(milliseconds: m['ms'] as int)
              : null,
        ),
        'end' => DuelEnd(
          totals: (m['totals'] as List).cast<int>(),
          winner: m['winner'] as int?,
          opponentLeft: m['reason'] == 'left',
          rematch: m['rematch'] == true,
        ),
        'error' => DuelError(m['code'] as String),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  static DuelResult _result(Map<String, dynamic> r) => (
    low: r['low'] as int?,
    high: r['high'] as int?,
    points: r['points'] as int,
    hit: r['hit'] as bool,
  );
}

/// The player in [seat] lost their connection; the clock stops and they
/// have [left] to come back.
class DuelAway extends DuelEvent {
  const DuelAway(this.seat, this.left);
  final int seat;
  final Duration left;
}

/// The player in [seat] is back; the clock runs on with [left] on the open
/// question (or the reveal).
class DuelBack extends DuelEvent {
  const DuelBack(this.seat, this.left);
  final int seat;
  final Duration left;
}

/// This player came back: the duel so far, as the room has it.
class DuelResume extends DuelEvent {
  const DuelResume({
    required this.you,
    required this.names,
    this.looks = const [null, null],
    required this.questionIds,
    required this.questionTime,
    required this.rejoin,
    required this.index,
    required this.revealed,
    required this.left,
    required this.results,
    required this.totals,
    required this.locked,
    required this.away,
    required this.awayLeft,
    this.budget,
  });
  final int you;
  final List<String> names;

  /// Both players' mascot codes by seat; null where not sent.
  final List<String?> looks;
  final List<String> questionIds;
  final Duration questionTime;
  final String? rejoin;

  /// The open question, or the one just revealed when [revealed].
  final int index;
  final bool revealed;

  /// Time left on that question (or on its reveal).
  final Duration left;

  /// Per revealed question, both results by seat.
  final List<List<DuelResult>> results;
  final List<int> totals;

  /// Who locked the open question, by seat.
  final List<bool> locked;

  /// The other seat when it is away too, with [awayLeft] to come back.
  final int? away;
  final Duration? awayLeft;

  /// This player's time away left for the rest of the duel.
  final Duration? budget;
}

/// A ranked duel was recorded: both ratings by seat.
class DuelRated extends DuelEvent {
  const DuelRated(this.ratings);
  final List<RatingChange> ratings;
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
    this.looks = const [null, null],
    required this.questionIds,
    required this.questionTime,
    this.rejoin,
    this.round = 1,
    this.ranked = false,
  });
  final int you;

  /// The first round of a random opponent's room between two leaderboard
  /// players: it counts for the monthly table.
  final bool ranked;
  final List<String> names;

  /// Both players' mascot codes by seat; null where not sent.
  final List<String?> looks;
  final List<String> questionIds;
  final Duration questionTime;

  /// This player's secret to come back after a dropped connection.
  final String? rejoin;

  /// 1 for the first duel in the room, 2 for the first rematch, …
  final int round;
}

/// The player in [seat] wants a rematch.
class DuelRematch extends DuelEvent {
  const DuelRematch(this.seat);
  final int seat;
}

/// No rematch: [seat] said no or left (null: the room closed it).
/// [reason] is `no`, `left`, `expired` or `no_questions`.
class DuelRematchNo extends DuelEvent {
  const DuelRematchNo(this.seat, this.reason);
  final int? seat;
  final String reason;
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
    this.nextIn,
  });
  final int index;
  final List<DuelResult> results;
  final List<int> totals;

  /// The next question comes after this long at most, even when nobody
  /// goes on; null after the last question (or from an older server).
  final Duration? nextIn;
}

/// The duel is over. [winner] is a seat, or null for a draw.
class DuelEnd extends DuelEvent {
  const DuelEnd({
    required this.totals,
    required this.winner,
    required this.opponentLeft,
    this.rematch = false,
  });
  final List<int> totals;
  final int? winner;
  final bool opponentLeft;

  /// A rematch may be asked for (both apps know rematches).
  final bool rematch;
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

  /// Gives up: the opponent wins at once.
  static String resign() => jsonEncode({'t': 'resign'});

  /// After the end: wants a rematch, or accepts the opponent's.
  static String rematch() => jsonEncode({'t': 'rematch'});

  /// After the end: no rematch (declines, or takes the request back).
  static String rematchNo() => jsonEncode({'t': 'rematch_no'});
}

/// Where a rematch stands after the end, as this player sees it.
enum RematchState {
  /// Not offered: an older app or server, or the duel did not end normally.
  unavailable,

  /// Either may ask.
  available,

  /// This player asked; waiting for the opponent.
  asked,

  /// The opponent asked; this player may accept or decline.
  offered,

  /// Both want it; the room is starting again.
  starting,

  /// This player said no (or took the request back).
  refused,

  /// The opponent said no.
  declined,

  /// The opponent left, or the connection is gone.
  gone,

  /// The room closed before an answer.
  expired,

  /// The bank has no new questions left for these two.
  noQuestions,
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
  List<String?> _looks = const [null, null];
  bool _ranked = false;
  RatingChange? _rating;
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
  String? _rejoin;
  bool _reconnecting = false;
  bool _opponentAway = false;
  Duration _awayLeft = Duration.zero;
  bool _myLocked = false;
  int _clock = 0;
  RematchState _rematch = RematchState.unavailable;
  int _round = 1;

  /// Where a rematch stands (after the end).
  RematchState get rematch => _rematch;

  /// 1 for the first duel, 2 after the first rematch, …: a new round
  /// starts the screen afresh.
  int get round => _round;

  /// This player asks for a rematch (or accepts the opponent's). Returns
  /// whether there is something to send.
  bool askRematch() {
    final next = switch (_rematch) {
      RematchState.available => RematchState.asked,
      RematchState.offered => RematchState.starting,
      _ => null,
    };
    if (next == null) return false;
    _rematch = next;
    notifyListeners();
    return true;
  }

  /// This player does not want a rematch (declines, or takes theirs back).
  /// Returns whether there is something to send.
  bool declineRematch() {
    const open = {
      RematchState.available,
      RematchState.asked,
      RematchState.offered,
    };
    if (!open.contains(_rematch)) return false;
    _rematch = RematchState.refused;
    notifyListeners();
    return true;
  }

  DuelPhase get phase => _phase;

  /// This player's secret to come back to the room, once the duel started.
  String? get rejoin => _rejoin;

  /// The connection dropped; the app is trying to come back.
  bool get reconnecting => _reconnecting;

  /// The opponent's connection dropped; [awayLeft] was their time to come
  /// back when it happened.
  bool get opponentAway => _opponentAway;
  Duration get awayLeft => _awayLeft;

  /// The clock is stopped: a revealed question waits for someone whose
  /// connection dropped. An open question never stops.
  bool get paused =>
      _phase == DuelPhase.reveal && (_reconnecting || _opponentAway);

  /// This player's time away left for the rest of the duel (the room says
  /// so on coming back).
  Duration get awayBudget => _awayBudget;
  Duration _awayBudget = duelReconnectWindow;

  /// Whether the room has this player's lock on the open question (known
  /// after a [DuelResume]; a lock sent while the connection was gone is
  /// then sent again).
  bool get myLocked => _myLocked;

  /// Changes whenever the room sets the clock again ([timeLeft] or
  /// [nextIn] are new): after a pause, or on coming back.
  int get clock => _clock;

  /// The room code (known once the room said so, or set by [expectCode]).
  String? get code => _code;
  String get myName => _names.isEmpty ? '' : _names[_you];
  String get opponentName => _names.length < 2 ? '' : _names[1 - _you];

  /// This duel counts for the monthly table.
  bool get ranked => _ranked;

  /// This player's rating before and after, once the room recorded it.
  RatingChange? get rating => _rating;

  /// This player's mascot as the room has it.
  MascotLook get myLook => MascotLook.parse(_looks[_you]);

  /// The opponent's mascot; the default philosopher when not sent.
  MascotLook get opponentLook => MascotLook.parse(_looks[1 - _you]);
  List<String> get questionIds => _questionIds;
  Duration get questionTime => _questionTime;

  /// The open (or last revealed) question; -1 before the first.
  int get index => _index;

  /// Time left on question [index] when it was opened.
  Duration get timeLeft => _timeLeft;

  /// After a reveal: how long until the next question comes by itself.
  Duration? get nextIn => _nextIn;
  Duration? _nextIn;
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

  /// Going back to a duel this player left, with their secret: if the
  /// connection drops before the room answers, the app tries again.
  void expectRejoin(String code, String rejoin) {
    _code = code;
    _rejoin = rejoin;
    _comingBack = true;
    notifyListeners();
  }

  bool _comingBack = false;

  void handle(DuelEvent event) {
    if (_phase == DuelPhase.failed) return;
    // After the end only the rematch goes on (and a new round's start).
    if (_phase == DuelPhase.over &&
        event is! DuelRematch &&
        event is! DuelRematchNo &&
        event is! DuelStart) {
      return;
    }
    switch (event) {
      case DuelWaiting(:final code):
        _code = code;
        _phase = DuelPhase.waiting;
      case DuelStart():
        if (_phase == DuelPhase.over) _newRound(event.round);
        _you = event.you;
        _names = event.names;
        _looks = event.looks;
        _ranked = event.ranked;
        _rating = null;
        _questionIds = event.questionIds;
        _questionTime = event.questionTime;
        _rejoin = event.rejoin;
      case DuelRated(:final ratings):
        if (ratings.length == 2) _rating = ratings[_you];
      case DuelQuestion(:final index, :final timeLeft):
        _index = index;
        _timeLeft = timeLeft;
        _opponentLocked = false;
        _myLocked = false;
        _phase = DuelPhase.question;
        _clock++;
      case DuelAway(:final seat, :final left):
        if (seat == _you) return;
        _opponentAway = true;
        _awayLeft = left;
        // Only a revealed question stops; an open one runs on as it was.
        if (_phase == DuelPhase.reveal) _clock++;
      case DuelBack(:final seat, :final left):
        if (seat == _you) return;
        _opponentAway = false;
        if (_phase == DuelPhase.reveal) {
          _nextIn = left;
        } else {
          _timeLeft = left;
        }
        _clock++;
      case DuelResume():
        _resume(event);
      case DuelLocked(:final index, :final seat):
        if (index == _index && seat != _you) _opponentLocked = true;
      case DuelReveal(
        :final index,
        :final results,
        :final totals,
        :final nextIn,
      ):
        if (index != _results.length || results.length != 2) return;
        _results.add((me: results[_you], opponent: results[1 - _you]));
        _totals = totals;
        _nextIn = nextIn;
        _phase = DuelPhase.reveal;
        _clock++;
      case DuelEnd(
        :final totals,
        :final winner,
        :final opponentLeft,
        :final rematch,
      ):
        _totals = totals;
        _winner = winner;
        _opponentLeft = opponentLeft;
        _phase = DuelPhase.over;
        _reconnecting = false;
        _opponentAway = false;
        _rematch = rematch ? RematchState.available : RematchState.unavailable;
      case DuelRematch(:final seat):
        if (seat == _you) return;
        _rematch = switch (_rematch) {
          RematchState.available => RematchState.offered,
          // Both asked at once: the room starts again.
          RematchState.asked => RematchState.starting,
          final other => other,
        };
      case DuelRematchNo(:final seat, :final reason):
        if (seat == _you) return;
        if (_rematch == RematchState.refused) return;
        _rematch = switch (reason) {
          'left' => RematchState.gone,
          'expired' => RematchState.expired,
          'no_questions' => RematchState.noQuestions,
          _ => RematchState.declined,
        };
      case DuelError(:final code):
        _error = code;
        _phase = DuelPhase.failed;
    }
    notifyListeners();
  }

  /// The room starts again after a rematch: everything of the last duel
  /// goes, the players stay.
  void _newRound(int round) {
    _round = round > _round ? round : _round + 1;
    _results.clear();
    _totals = const [0, 0];
    _index = -1;
    _winner = null;
    _opponentLeft = false;
    _opponentLocked = false;
    _myLocked = false;
    _opponentAway = false;
    _nextIn = null;
    _awayBudget = duelReconnectWindow;
    _rematch = RematchState.unavailable;
    _phase = DuelPhase.connecting;
  }

  void _resume(DuelResume r) {
    _you = r.you;
    _names = r.names;
    _looks = r.looks;
    _questionIds = r.questionIds;
    _questionTime = r.questionTime;
    _rejoin = r.rejoin ?? _rejoin;
    _results
      ..clear()
      ..addAll([
        for (final pair in r.results)
          if (pair.length == 2) (me: pair[_you], opponent: pair[1 - _you]),
      ]);
    _totals = r.totals;
    _index = r.index;
    if (r.revealed) {
      _phase = DuelPhase.reveal;
      _nextIn = isLastQuestion ? null : r.left;
    } else {
      _phase = DuelPhase.question;
      _timeLeft = r.left;
    }
    _myLocked = r.locked.length == 2 && r.locked[_you];
    _opponentLocked = r.locked.length == 2 && r.locked[1 - _you];
    _opponentAway = r.away != null;
    _awayLeft = r.awayLeft ?? Duration.zero;
    _awayBudget = r.budget ?? _awayBudget;
    _reconnecting = false;
    _clock++;
  }

  /// The connection dropped. In play, with a secret to come back with, the
  /// app tries again ([reconnecting]); otherwise the duel has failed.
  void connectionLost() {
    if (_phase == DuelPhase.over) {
      // After the end: nothing to come back to, but no rematch either.
      const open = {
        RematchState.available,
        RematchState.asked,
        RematchState.offered,
        RematchState.starting,
      };
      if (open.contains(_rematch)) {
        _rematch = RematchState.gone;
        notifyListeners();
      }
      return;
    }
    final inPlay =
        _phase == DuelPhase.question ||
        _phase == DuelPhase.reveal ||
        (_comingBack && _phase == DuelPhase.connecting);
    if (inPlay && _rejoin != null) {
      if (_reconnecting) return;
      _reconnecting = true;
      _clock++;
      notifyListeners();
      return;
    }
    handle(const DuelError('connection_lost'));
  }

  /// Coming back did not work out in time.
  void reconnectFailed() {
    _reconnecting = false;
    handle(const DuelError('connection_lost'));
  }
}

/// How long each note stays while looking for an opponent.
const Duration duelTipEvery = Duration(seconds: 15);

/// Which of [count] notes shows after [waited], starting from [first].
int duelTipAt(Duration waited, {required int first, required int count}) =>
    (first + waited.inSeconds ~/ duelTipEvery.inSeconds) % count;
