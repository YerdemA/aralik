import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings (shared_preferences): the theme, sound effects and the
/// duel name.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
    : _themeMode =
          ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
          ThemeMode.system;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  static const _themeKey = 'theme_mode';
  static const _duelNameKey = 'duel_name';
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

  Future<void> setSoundOn(bool on) async {
    if (on == soundOn) return;
    await _prefs.setBool(_soundKey, on);
    notifyListeners();
  }

  /// The name shown to duel opponents, or null until one is chosen
  /// (Settings → Düello adın; the lobby has no name field).
  String? get duelName => _prefs.getString(_duelNameKey);

  Future<void> setDuelName(String name) async {
    await _prefs.setString(_duelNameKey, name);
    notifyListeners();
  }
}
