import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device player history (shared_preferences). Nothing leaves the device.
class StatsStore extends ChangeNotifier {
  StatsStore._(this._prefs)
    : _seenIds = {...?_prefs.getStringList(_seenKey)},
      _answered = _prefs.getInt(_answeredKey) ?? 0,
      _hits = _prefs.getInt(_hitsKey) ?? 0;

  static Future<StatsStore> open() async =>
      StatsStore._(await SharedPreferences.getInstance());

  static const _seenKey = 'seen_ids';
  static const _answeredKey = 'answered';
  static const _hitsKey = 'hits';

  final SharedPreferences _prefs;
  final Set<String> _seenIds;
  int _answered;
  int _hits;

  /// Every question id the player has locked an answer for, in any mode.
  /// Free play never repeats these.
  Set<String> get seenIds => UnmodifiableSetView(_seenIds);

  /// All-time locked intervals, for calibration.
  int get answered => _answered;

  /// All-time intervals that contained the answer.
  int get hits => _hits;

  Future<void> recordAnswer({
    required String questionId,
    required bool hit,
  }) async {
    _seenIds.add(questionId);
    _answered++;
    if (hit) _hits++;
    notifyListeners();
    await Future.wait([
      _prefs.setStringList(_seenKey, _seenIds.toList()),
      _prefs.setInt(_answeredKey, _answered),
      _prefs.setInt(_hitsKey, _hits),
    ]);
  }
}
