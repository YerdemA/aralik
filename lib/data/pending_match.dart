import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A duel or tournament this player is in the middle of: kept on the phone
/// while it is played, so that after leaving it (the close button, the app
/// closed or killed) the home screen offers to go back to it with the
/// player's rejoin secret, or to give it up.
enum PendingKind { duel, tournament }

@immutable
class PendingMatch {
  const PendingMatch({
    required this.kind,
    required this.code,
    required this.rejoin,
    required this.name,
    required this.until,
  });

  final PendingKind kind;
  final String code;
  final String rejoin;

  /// The name it is played under (the room checks it on coming back).
  final String name;

  /// Until when the room keeps the seat: for a duel the player's time away
  /// left (from when the app last heard from the room), for a tournament
  /// an estimate of when its match ends.
  final DateTime until;

  bool isLive(DateTime now) => now.isBefore(until);

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'code': code,
    'rejoin': rejoin,
    'name': name,
    'until': until.millisecondsSinceEpoch,
  };

  String toJsonString() => jsonEncode(toJson());

  static PendingMatch? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = PendingKind.values.asNameMap()[json['kind']];
    final code = json['code'];
    final rejoin = json['rejoin'];
    final name = json['name'];
    final until = json['until'];
    if (kind == null ||
        code is! String ||
        rejoin is! String ||
        name is! String ||
        until is! int) {
      return null;
    }
    return PendingMatch(
      kind: kind,
      code: code,
      rejoin: rejoin,
      name: name,
      until: DateTime.fromMillisecondsSinceEpoch(until),
    );
  }
}

/// How long a tournament may still run with [questionsLeft] questions to
/// go: each takes at most a question and a reveal, plus some slack.
Duration tournamentRejoinWindow(int questionsLeft) =>
    Duration(seconds: 30 * questionsLeft + 30);

/// The one match in progress (shared_preferences). The screen playing it
/// keeps it fresh; the home screen reads it.
class PendingMatchStore extends ChangeNotifier {
  PendingMatchStore(this._prefs);

  static const _key = 'pending_match';

  final SharedPreferences _prefs;

  /// The match left behind, if any (it may have run out; see
  /// [PendingMatch.isLive]).
  PendingMatch? get current {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PendingMatch.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(PendingMatch match) async {
    await _prefs.setString(_key, match.toJsonString());
    notifyListeners();
  }

  /// Forgets the match; with [rejoin], only if it is still that one.
  Future<void> clear({String? rejoin}) async {
    final stored = current;
    if (stored == null) {
      if (_prefs.containsKey(_key)) await _prefs.remove(_key);
      return;
    }
    if (rejoin != null && stored.rejoin != rejoin) return;
    await _prefs.remove(_key);
    notifyListeners();
  }
}

/// Keeps [store] in step with a match being played: saved (with a fresh
/// [PendingMatch.until]) at most every few seconds while it runs, cleared
/// once it is over. Used by the duel and tournament screens.
class PendingMatchKeeper {
  PendingMatchKeeper(this.store, {required this.kind, required this.now});

  final PendingMatchStore? store;
  final PendingKind kind;
  final DateTime Function() now;

  DateTime? _savedAt;
  String? _rejoin;

  static const _every = Duration(seconds: 3);

  /// The match is on: room [code], secret [rejoin], seat kept for [window].
  void playing({
    required String code,
    required String rejoin,
    required String name,
    required Duration window,
    bool force = false,
  }) {
    final store = this.store;
    if (store == null) return;
    final t = now();
    final saved = _savedAt;
    if (!force &&
        _rejoin == rejoin &&
        saved != null &&
        t.difference(saved) < _every) {
      return;
    }
    _savedAt = t;
    _rejoin = rejoin;
    store
        .save(
          PendingMatch(
            kind: kind,
            code: code,
            rejoin: rejoin,
            name: name,
            until: t.add(window),
          ),
        )
        .ignore();
  }

  /// The match is over (or can never be gone back to). [rejoin]: its
  /// secret, when this keeper never saved it (a failed attempt to go back).
  void over({String? rejoin}) {
    final secret = _rejoin ?? rejoin;
    _savedAt = null;
    _rejoin = null;
    if (secret == null) return;
    store?.clear(rejoin: secret).ignore();
  }
}
