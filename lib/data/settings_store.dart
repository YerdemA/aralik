import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings (shared_preferences). For now only the theme.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
    : _themeMode =
          ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
          ThemeMode.system;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  static const _themeKey = 'theme_mode';

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
}
