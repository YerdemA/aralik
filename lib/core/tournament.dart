/// Tournament: three to eight players in one room, the wire protocol and
/// the room's state (pure Dart). The server side is
/// server/leaderboard/src/tournament.js; both follow its protocol.
///
/// The host opens a room, the others join with its code, the host picks 5
/// or 10 questions and starts. Each question then runs like a duel's for
/// everyone at once; at the end come the standings and the room is back in
/// its lobby, ready for another round.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'duel.dart';

/// Must match TOURNAMENT_VERSION in tournament.js.
const int tournamentProtocolVersion = 1;

/// Question counts the host can pick.
const List<int> tournamentQuestionCounts = [5, 10];

typedef TournamentPlayer = ({int id, String name});

/// One player's interval on a revealed question; null bounds: nothing
/// typed in time.
typedef TournamentResult = ({
  int id,
  int? low,
  int? high,
  int points,
  bool hit,
});

/// A player's line in the final standings.
typedef TournamentStanding = ({
  int id,
  String name,
  int points,
  int hits,
  bool left,
});

/// A message from the room.
@immutable
sealed class TournamentEvent {
  const TournamentEvent();

  /// Parses one message; null for anything this version does not know.
  static TournamentEvent? parse(String text) {
    try {
      final m = jsonDecode(text);
      if (m is! Map<String, dynamic>) return null;
      List<TournamentPlayer> players(Object? list) => [
        for (final p in (list as List).cast<Map<String, dynamic>>())
          (id: p['id'] as int, name: p['name'] as String),
      ];
      TournamentRoomState room(Map<String, dynamic> m) => TournamentRoomState(
        code: m['code'] as String,
        host: m['host'] as int?,
        count: m['count'] as int,
        players: players(m['players']),
        min: m['min'] as int,
        max: m['max'] as int,
      );
      TournamentStart start(Map<String, dynamic> m) => TournamentStart(
        questionIds: (m['questions'] as List).cast<String>(),
        questionTime: Duration(milliseconds: m['questionMs'] as int),
        players: players(m['players']),
      );
      return switch (m['t']) {
        'welcome' => TournamentWelcome(
          m['you'] as int,
          rejoin: m['rejoin'] as String?,
        ),
        'room' => room(m),
        'start' => start(m),
        'resume' => TournamentResume(
          you: m['you'] as int,
          rejoin: m['rejoin'] as String?,
          room: room(m['room'] as Map<String, dynamic>),
          start: start(m['start'] as Map<String, dynamic>),
          index: m['index'] as int,
          revealed: m['phase'] == 'reveal',
          left: Duration(milliseconds: m['ms'] as int),
          results: [
            for (final round in (m['results'] as List).cast<List>())
              [for (final r in round.cast<Map<String, dynamic>>()) _result(r)],
          ],
          locked: (m['locked'] as List).cast<int>(),
        ),
        'question' => TournamentQuestion(
          m['i'] as int,
          Duration(milliseconds: m['ms'] as int),
        ),
        'locked' => TournamentLocked(m['i'] as int, m['id'] as int),
        'reveal' => TournamentReveal(
          index: m['i'] as int,
          results: [
            for (final r in (m['results'] as List).cast<Map<String, dynamic>>())
              _result(r),
          ],
          nextIn: m['ms'] is int
              ? Duration(milliseconds: m['ms'] as int)
              : null,
        ),
        'end' => TournamentEnd(
          questionCount: m['questions'] as int,
          standings: [
            for (final s
                in (m['standings'] as List).cast<Map<String, dynamic>>())
              (
                id: s['id'] as int,
                name: s['name'] as String,
                points: s['points'] as int,
                hits: s['hits'] as int,
                left: s['left'] == true,
              ),
          ],
        ),
        'kicked' => const TournamentKicked(),
        'error' => TournamentError('${m['code']}'),
        _ => null,
      };
    } on Object {
      return null; // malformed: ignore
    }
  }

  static TournamentResult _result(Map<String, dynamic> r) => (
    id: r['id'] as int,
    low: r['low'] as int?,
    high: r['high'] as int?,
    points: r['points'] as int,
    hit: r['hit'] as bool,
  );
}

class TournamentWelcome extends TournamentEvent {
  const TournamentWelcome(this.you, {this.rejoin});
  final int you;

  /// This player's secret to come back after a dropped connection.
  final String? rejoin;
}

/// This player came back mid-match: the room and the match so far.
class TournamentResume extends TournamentEvent {
  const TournamentResume({
    required this.you,
    required this.rejoin,
    required this.room,
    required this.start,
    required this.index,
    required this.revealed,
    required this.left,
    required this.results,
    required this.locked,
  });
  final int you;
  final String? rejoin;
  final TournamentRoomState room;
  final TournamentStart start;
  final int index;
  final bool revealed;
  final Duration left;
  final List<List<TournamentResult>> results;
  final List<int> locked;
}

class TournamentRoomState extends TournamentEvent {
  const TournamentRoomState({
    required this.code,
    required this.host,
    required this.count,
    required this.players,
    required this.min,
    required this.max,
  });
  final String code;
  final int? host;
  final int count;
  final List<TournamentPlayer> players;
  final int min;
  final int max;
}

class TournamentStart extends TournamentEvent {
  const TournamentStart({
    required this.questionIds,
    required this.questionTime,
    required this.players,
  });
  final List<String> questionIds;
  final Duration questionTime;
  final List<TournamentPlayer> players;
}

class TournamentQuestion extends TournamentEvent {
  const TournamentQuestion(this.index, this.timeLeft);
  final int index;
  final Duration timeLeft;
}

class TournamentLocked extends TournamentEvent {
  const TournamentLocked(this.index, this.id);
  final int index;
  final int id;
}

class TournamentReveal extends TournamentEvent {
  const TournamentReveal({
    required this.index,
    required this.results,
    this.nextIn,
  });
  final int index;
  final List<TournamentResult> results;
  final Duration? nextIn;
}

class TournamentEnd extends TournamentEvent {
  const TournamentEnd({required this.questionCount, required this.standings});
  final int questionCount;
  final List<TournamentStanding> standings;
}

class TournamentKicked extends TournamentEvent {
  const TournamentKicked();
}

class TournamentError extends TournamentEvent {
  const TournamentError(this.code);
  final String code;
}

/// Messages from this app to the room.
abstract final class TournamentMessages {
  static String count(int n) => jsonEncode({'t': 'count', 'n': n});
  static String kick(int id) => jsonEncode({'t': 'kick', 'id': id});
  static String start() => jsonEncode({'t': 'start'});
  static String lock(int index, {int? low, int? high}) =>
      DuelMessages.lock(index, low: low, high: high);
  static String next(int index) => DuelMessages.next(index);
}

enum TournamentPhase {
  /// Opening the connection.
  connecting,

  /// In the room: the player list, waiting for the host to start.
  lobby,

  /// A question is open.
  question,

  /// A question was revealed.
  reveal,

  /// The standings of the round just played.
  standings,

  /// The host removed this player.
  kicked,

  /// The room refused or the connection is gone; see [TournamentRoom.error].
  failed,
}

/// The room as this app sees it, fed by the room's events.
class TournamentRoom extends ChangeNotifier {
  TournamentPhase _phase = TournamentPhase.connecting;
  int? _you;
  String? _code;
  int? _host;
  int _count = 5;
  List<TournamentPlayer> _players = const [];
  int _min = 3;
  int _max = 8;

  List<String> _questionIds = const [];
  Duration _questionTime = const Duration(seconds: 15);
  List<TournamentPlayer> _matchPlayers = const [];
  int _index = -1;
  Duration _timeLeft = Duration.zero;
  final Set<int> _locked = {};
  final List<List<TournamentResult>> _results = [];
  Duration? _nextIn;
  List<TournamentStanding> _standings = const [];
  int _roundQuestions = 0;
  String? _error;
  String? _rejoin;
  bool _reconnecting = false;
  int _clock = 0;

  /// This player's secret to come back mid-match.
  String? get rejoin => _rejoin;

  /// Going back to a match this player left, with their secret: if the
  /// connection drops before the room answers, the app tries again.
  void expectRejoin(String code, String rejoin) {
    _code = code;
    _rejoin = rejoin;
    _comingBack = true;
  }

  bool _comingBack = false;

  /// Questions of the current match not revealed yet (0 outside one).
  int get questionsLeft {
    if (_phase != TournamentPhase.question &&
        _phase != TournamentPhase.reveal) {
      return 0;
    }
    return _questionIds.length - _results.length;
  }

  /// The connection dropped mid-match; the app is trying to come back.
  /// The others play on meanwhile.
  bool get reconnecting => _reconnecting;

  /// Changes whenever the room sets the clock again.
  int get clock => _clock;

  /// Whether the room has this player's lock on the open question.
  bool get myLocked => _you != null && _locked.contains(_you);

  TournamentPhase get phase => _phase;
  int? get you => _you;
  String? get code => _code;
  int? get host => _host;
  bool get isHost => _you != null && _you == _host;
  int get count => _count;
  List<TournamentPlayer> get players => _players;
  int get minPlayers => _min;
  int get maxPlayers => _max;
  bool get canStart => isHost && _players.length >= _min;

  List<String> get questionIds => _questionIds;
  Duration get questionTime => _questionTime;
  List<TournamentPlayer> get matchPlayers => _matchPlayers;
  int get index => _index;
  bool get isLastQuestion => _index == _questionIds.length - 1;

  /// Time left on the open question when it was announced.
  Duration get timeLeft => _timeLeft;

  /// Players who locked the open question.
  Set<int> get locked => Set.unmodifiable(_locked);
  List<List<TournamentResult>> get results => List.unmodifiable(_results);
  Duration? get nextIn => _nextIn;
  List<TournamentStanding> get standings => _standings;
  int get roundQuestions => _roundQuestions;
  String? get error => _error;

  /// The name of player [id] in the current match (or the lobby).
  String nameOf(int id) {
    for (final p in [..._matchPlayers, ..._players]) {
      if (p.id == id) return p.name;
    }
    return '?';
  }

  /// This player's place in the last standings (1 = first), or null.
  int? get myRank {
    final k = _standings.indexWhere((s) => s.id == _you);
    return k < 0 ? null : k + 1;
  }

  void handle(TournamentEvent event) {
    switch (event) {
      case TournamentWelcome(:final you, :final rejoin):
        _you = you;
        _rejoin = rejoin;
      case TournamentResume():
        _resume(event);
      case TournamentRoomState():
        _applyRoom(event);
      case TournamentStart():
        _applyStart(event);
      case TournamentQuestion(:final index, :final timeLeft):
        _index = index;
        _timeLeft = timeLeft;
        _locked.clear();
        _nextIn = null;
        _phase = TournamentPhase.question;
        _clock++;
      case TournamentLocked(:final index, :final id):
        if (index == _index) _locked.add(id);
      case TournamentReveal(:final index, :final results, :final nextIn):
        if (index != _results.length) return;
        _results.add(results);
        _nextIn = nextIn;
        _phase = TournamentPhase.reveal;
        _clock++;
      case TournamentEnd(:final questionCount, :final standings):
        _roundQuestions = questionCount;
        _standings = standings;
        // The last reveal stays until "Sonuçları gör"; see showStandings.
        if (_phase != TournamentPhase.reveal) {
          _phase = TournamentPhase.standings;
        }
      case TournamentKicked():
        _phase = TournamentPhase.kicked;
      case TournamentError(:final code):
        // The first reason stays: a refusal ('kicked', 'in_progress', …) is
        // followed by the room closing the connection, which is no news.
        if (_phase == TournamentPhase.kicked ||
            _phase == TournamentPhase.failed) {
          return;
        }
        _error = code;
        _phase = TournamentPhase.failed;
        _reconnecting = false;
    }
    notifyListeners();
  }

  /// Whether the round is over and its last reveal is still on screen.
  bool get roundOver => _standings.isNotEmpty;

  /// From the last reveal to the standings.
  void showStandings() {
    if (_standings.isEmpty) return;
    _phase = TournamentPhase.standings;
    notifyListeners();
  }

  /// From the standings back to the room's lobby.
  void backToRoom() {
    if (_phase != TournamentPhase.standings) return;
    _phase = TournamentPhase.lobby;
    notifyListeners();
  }

  void _applyRoom(TournamentRoomState event) {
    _code = event.code;
    _host = event.host;
    _count = event.count;
    _players = event.players;
    _min = event.min;
    _max = event.max;
    if (_phase == TournamentPhase.connecting) {
      _phase = TournamentPhase.lobby;
    }
  }

  void _applyStart(TournamentStart event) {
    // The same round again (on coming back) keeps its list, so the screen
    // keeps its input.
    if (!listEquals(_questionIds, event.questionIds)) {
      _questionIds = event.questionIds;
    }
    _questionTime = event.questionTime;
    _matchPlayers = event.players;
    _results.clear();
    _standings = const [];
    _index = -1;
  }

  void _resume(TournamentResume r) {
    _you = r.you;
    _rejoin = r.rejoin ?? _rejoin;
    _applyRoom(r.room);
    _applyStart(r.start);
    _results
      ..clear()
      ..addAll(r.results);
    _index = r.index;
    _locked
      ..clear()
      ..addAll(r.locked);
    if (r.revealed) {
      _phase = TournamentPhase.reveal;
      _nextIn = isLastQuestion ? null : r.left;
    } else {
      _phase = TournamentPhase.question;
      _timeLeft = r.left;
      _nextIn = null;
    }
    _reconnecting = false;
    _clock++;
  }

  /// The connection dropped. Mid-match, with a secret, the app tries to
  /// come back ([reconnecting]); otherwise the room is lost.
  void connectionLost() {
    final inMatch =
        _phase == TournamentPhase.question ||
        _phase == TournamentPhase.reveal ||
        (_comingBack && _phase == TournamentPhase.connecting);
    if (inMatch && _rejoin != null) {
      if (_reconnecting) return;
      _reconnecting = true;
      notifyListeners();
      return;
    }
    handle(const TournamentError('connection_lost'));
  }

  /// Coming back did not work out.
  void reconnectFailed() {
    _reconnecting = false;
    handle(const TournamentError('connection_lost'));
  }

  /// This player's result on revealed question [i], or null.
  TournamentResult? myResult(int i) {
    if (i >= _results.length) return null;
    for (final r in _results[i]) {
      if (r.id == _you) return r;
    }
    return null;
  }

  /// Revealed question [i]'s results, best points first.
  List<TournamentResult> ranked(int i) =>
      [..._results[i]]..sort((a, b) => b.points - a.points);

  /// Totals so far per player id.
  Map<int, int> get totals {
    final sums = <int, int>{};
    for (final round in _results) {
      for (final r in round) {
        sums[r.id] = (sums[r.id] ?? 0) + r.points;
      }
    }
    return sums;
  }
}
