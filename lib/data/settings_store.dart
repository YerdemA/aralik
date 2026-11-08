import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/nickname.dart' as nick;

/// User settings (shared_preferences): the theme, sound effects and the
/// player's one name.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
    : _themeMode =
          ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
          ThemeMode.system;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  static const _themeKey = 'theme_mode';
  // The one user name; the key is from when it was only the duel name.
  static const _nameKey = 'duel_name';
  static const _nameChangedKey = 'name_changed_at';
  static const _soundKey = 'sound_on';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  /// Light, dark, or follow the system (default).
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  /// Sound effects on (default) or off.
  bool get soundOn => _prefs.getBool(_soundKey) ?? true;

  /// Whether the first-launch tour's [part] was shown.
  bool tourSeen(TourPart part) => _prefs.getBool(part.key) ?? false;

  Future<void> markTourSeen(TourPart part) => _prefs.setBool(part.key, true);

  /// Players from before the tour: they know the app already.
  Future<void> markAllToursSeen() =>
      Future.wait([for (final p in TourPart.values) markTourSeen(p)]);

  /// Ayarlar → "Tanıtımı yeniden oynat".
  Future<void> replayTours() =>
      Future.wait([for (final p in TourPart.values) _prefs.remove(p.key)]);

  Future<void> setSoundOn(bool on) async {
    if (on == soundOn) return;
    await _prefs.setBool(_soundKey, on);
    notifyListeners();
  }

  /// The player's one name: on the leaderboard, in duels and tournaments.
  /// Null until chosen. It is only typed in Settings
  /// (features/settings/user_name_sheet.dart); while joined it is the
  /// leaderboard nickname too.
  String? get userName => _prefs.getString(_nameKey);

  /// When the name last changed (not set by the first choice).
  DateTime? get nameChangedAt {
    final ms = _prefs.getInt(_nameChangedKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// When the name may change again, or null when it may change now.
  DateTime? nextNameChange([DateTime? now]) =>
      nick.nextNameChange(nameChangedAt, now ?? DateTime.now());

  /// Chooses or changes the name. A change (not the first choice) starts
  /// the wait of [nick.nameChangeEvery]; callers check [nextNameChange].
  Future<void> setUserName(String name, {DateTime? now}) async {
    final old = userName;
    if (old == name) return;
    await _prefs.setString(_nameKey, name);
    if (old != null) await markNameChanged(now ?? DateTime.now());
    notifyListeners();
  }

  /// Takes the name the leaderboard account has (a restored account, or
  /// an older app's separate nickname). Not a change by the player.
  Future<void> adoptUserName(String name) async {
    if (userName == name) return;
    await _prefs.setString(_nameKey, name);
    notifyListeners();
  }

  /// Records a change at [at] (the server may know of a later one).
  Future<void> markNameChanged(DateTime at) async {
    await _prefs.setInt(_nameChangedKey, at.millisecondsSinceEpoch);
    notifyListeners();
  }

  /// The leaderboard refused the name (taken or blocked): the player may
  /// pick another one right away.
  Future<void> freeNameChange() async {
    await _prefs.remove(_nameChangedKey);
    notifyListeners();
  }
}

/// The first-launch tour comes in parts, each shown once: the home screen,
/// the first question's guess, and its interval.
enum TourPart {
  home('tour_home_seen'),
  guess('tour_guess_seen'),
  range('tour_range_seen');

  const TourPart(this.key);
  final String key;
}
