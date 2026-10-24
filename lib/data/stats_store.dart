import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/daily.dart';

/// On-device player history (shared_preferences). Nothing leaves the device.
class StatsStore extends ChangeNotifier {
  StatsStore._(this._prefs)
    : _seenIds = {...?_prefs.getStringList(_seenKey)},
      _answered = _prefs.getInt(_answeredKey) ?? 0,
      _hits = _prefs.getInt(_hitsKey) ?? 0,
      _completedDays = {
        for (final d in _prefs.getStringList(_completedKey) ?? const [])
          int.parse(d),
      };

  static Future<StatsStore> open() async =>
      StatsStore._(await SharedPreferences.getInstance());

  static const _seenKey = 'seen_ids';
  static const _answeredKey = 'answered';
  static const _hitsKey = 'hits';
  static const _completedKey = 'completed_days';
  static String _dailyKey(int day) => 'daily_points_$day';

  final SharedPreferences _prefs;
  final Set<String> _seenIds;
  final Set<int> _completedDays;
  int _answered;
  int _hits;

  /// Every question id the player has locked an answer for, in any mode.
  /// Free play never repeats these.
  Set<String> get seenIds => UnmodifiableSetView(_seenIds);

  /// All-time locked intervals, for calibration.
  int get answered => _answered;

  /// All-time intervals that contained the answer.
  int get hits => _hits;

  /// Day indices whose daily set was finished.
  Set<int> get completedDays => UnmodifiableSetView(_completedDays);

  /// Points of the daily questions locked so far on [day], in order.
  List<int> dailyPoints(int day) => List.unmodifiable([
    for (final p in _prefs.getStringList(_dailyKey(day)) ?? const [])
      int.parse(p),
  ]);

  bool isDayComplete(int day) => _completedDays.contains(day);

  int streak(int today) => currentStreak(_completedDays, today);

  /// The most recent finished day before or on [today], or null.
  int? lastCompletedDay(int today) {
    final past = _completedDays.where((d) => d <= today);
    return past.isEmpty ? null : past.reduce((a, b) => a > b ? a : b);
  }

  /// Records a locked interval. Pass [dailyDay] for daily-set questions so
  /// the set can be resumed and the streak counted.
  Future<void> recordAnswer({
    required String questionId,
    required bool hit,
    int? dailyDay,
    int points = 0,
  }) async {
    _seenIds.add(questionId);
    _answered++;
    if (hit) _hits++;
    final writes = <Future<bool>>[
      _prefs.setStringList(_seenKey, _seenIds.toList()),
      _prefs.setInt(_answeredKey, _answered),
      _prefs.setInt(_hitsKey, _hits),
    ];
    if (dailyDay != null) {
      final daily = [...dailyPoints(dailyDay), points];
      writes.add(
        _prefs.setStringList(_dailyKey(dailyDay), [
          for (final p in daily) '$p',
        ]),
      );
      if (daily.length >= questionsPerDay && _completedDays.add(dailyDay)) {
        writes.add(
          _prefs.setStringList(_completedKey, [
            for (final d in _completedDays) '$d',
          ]),
        );
      }
    }
    notifyListeners();
    await Future.wait(writes);
  }
}
