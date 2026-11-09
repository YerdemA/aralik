import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/nickname.dart';
import '../core/strings.dart';

/// Where a reported name was seen; the server's `place`.
enum ReportPlace { board, duel, tournament }

/// Reporting and blocking the names other players see (App Store guideline
/// 1.2). A report goes to the server (`POST /v1/report`), which hides a
/// name several players report until it is reviewed. Blocking stays on the
/// phone: a blocked name is shown as [AppStrings.blockedPlayer] on the
/// board, in duels and in tournaments.
class Moderation extends ChangeNotifier {
  Moderation({SharedPreferences? prefs, this.report}) : _prefs = prefs {
    _blocked = [...?prefs?.getStringList(_blockedKey)];
  }

  /// The app's one instance, set up in main.dart; tests get an empty one
  /// that keeps nothing.
  static Moderation instance = Moderation();

  static const _blockedKey = 'blocked_names';

  final SharedPreferences? _prefs;
  late List<String> _blocked;

  /// Sends a report; true once the server took it. Null without a server.
  Future<bool> Function(String name, ReportPlace place)? report;

  /// Blocked names, as they were shown when blocked.
  List<String> get blocked => List.unmodifiable(_blocked);

  bool isBlocked(String name) {
    final key = nameKey(name);
    return _blocked.any((b) => nameKey(b) == key);
  }

  /// [name], or the blocked-player label when it is blocked.
  String shown(String name) =>
      name.isNotEmpty && isBlocked(name) ? AppStrings.blockedPlayer : name;

  Future<void> block(String name) async {
    if (name.isEmpty || isBlocked(name)) return;
    _blocked = [..._blocked, name];
    notifyListeners();
    await _prefs?.setStringList(_blockedKey, _blocked);
  }

  Future<void> unblock(String name) async {
    final key = nameKey(name);
    _blocked = [
      for (final b in _blocked)
        if (nameKey(b) != key) b,
    ];
    notifyListeners();
    await _prefs?.setStringList(_blockedKey, _blocked);
  }
}
