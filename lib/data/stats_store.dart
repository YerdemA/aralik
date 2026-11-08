import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/daily.dart';
import '../core/scoring.dart';
import '../core/stats.dart';
import 'question.dart';

/// On-device player history (shared_preferences). Nothing leaves the device.
class StatsStore extends ChangeNotifier {
  StatsStore(this._prefs)
    : _seenIds = {...?_prefs.getStringList(_seenKey)},
      _answered = _prefs.getInt(_answeredKey) ?? 0,
      _hits = _prefs.getInt(_hitsKey) ?? 0,
      _completedDays = {
        for (final d in _prefs.getStringList(_completedKey) ?? const [])
          int.parse(d),
      },
      _log = [
        for (final entry in _prefs.getStringList(_logKey) ?? const [])
          ?_decodeRecord(entry),
      ];

  static Future<StatsStore> open() async =>
      StatsStore(await SharedPreferences.getInstance());

  static const _seenKey = 'seen_ids';
  static const _answeredKey = 'answered';
  static const _hitsKey = 'hits';
  static const _completedKey = 'completed_days';
  static const _logKey = 'answer_log';
  static const _mathAnsweredKey = 'math_answered';
  static const _mathHitsKey = 'math_hits';
  static String _dailyKey(int day) => 'daily_results_$day';
  static String _startedKey(int day) => 'daily_started_$day';

  final SharedPreferences _prefs;
  final Set<String> _seenIds;
  final Set<int> _completedDays;
  final List<AnswerRecord> _log;
  int _answered;
  int _hits;

  /// Every question id the player has locked an answer for, in any mode.
  /// Free play never repeats these.
  Set<String> get seenIds => UnmodifiableSetView(_seenIds);

  /// All-time locked intervals, for calibration.
  int get answered => _answered;

  /// All-time intervals that contained the answer.
  int get hits => _hits;

  /// Math mode's own calibration: kept apart from [answered] and [hits]
  /// (estimating a computation is another skill), and its questions are
  /// never added to [seenIds] (they may come again).
  int get mathAnswered => _prefs.getInt(_mathAnsweredKey) ?? 0;
  int get mathHits => _prefs.getInt(_mathHitsKey) ?? 0;

  Future<void> recordMathAnswer({required bool hit}) async {
    await Future.wait([
      _prefs.setInt(_mathAnsweredKey, mathAnswered + 1),
      if (hit) _prefs.setInt(_mathHitsKey, mathHits + 1),
    ]);
    notifyListeners();
  }

  /// Every locked interval since the log was added, oldest first. Older
  /// answers only count in [answered] and [hits].
  List<AnswerRecord> get answerLog => UnmodifiableListView(_log);

  /// Day indices whose daily set was finished.
  Set<int> get completedDays => UnmodifiableSetView(_completedDays);

  /// Results of the daily questions locked so far on [day], in order.
  /// Stored as `"85:1"` (points:hit).
  List<QuestionResult> dailyResults(int day) => List.unmodifiable([
    for (final entry in _prefs.getStringList(_dailyKey(day)) ?? const [])
      (points: int.parse(entry.split(':').first), hit: entry.endsWith(':1')),
  ]);

  bool isDayComplete(int day) => _completedDays.contains(day);

  int streak(int today) => currentStreak(_completedDays, today);

  /// The most recent finished day before or on [today], or null.
  int? lastCompletedDay(int today) {
    final past = _completedDays.where((d) => d <= today);
    return past.isEmpty ? null : past.reduce((a, b) => a > b ? a : b);
  }

  /// When the daily question at [position] (0-based) of [day] was first
  /// shown. The first call stores [now]; later calls return that moment,
  /// so leaving and coming back does not restart the countdown.
  DateTime startDailyQuestion(int day, int position, DateTime now) {
    final stored = _prefs.getString(_startedKey(day))?.split(':');
    if (stored != null && stored.length == 2 && stored[0] == '$position') {
      final millis = int.tryParse(stored[1]);
      if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    // One entry per day is enough: only the current question can be open.
    _prefs.setString(
      _startedKey(day),
      '$position:${now.millisecondsSinceEpoch}',
    );
    return now;
  }

  /// Records a locked interval. Pass [dailyDay] for daily-set questions so
  /// the set can be resumed and the streak counted.
  ///
  /// A null [outcome] is a daily question whose time ran out before a guess
  /// was typed: it counts in the daily score, but not in calibration (there
  /// was no interval to be calibrated).
  Future<void> recordAnswer({
    required String questionId,
    required QuestionCategory category,
    required Outcome? outcome,
    int? dailyDay,
    int points = 0,
  }) async {
    final hit = outcome == Outcome.hit;
    _seenIds.add(questionId);
    final writes = <Future<bool>>[
      _prefs.setStringList(_seenKey, _seenIds.toList()),
    ];
    if (outcome != null) {
      _answered++;
      if (hit) _hits++;
      _log.add((category: category, points: points, outcome: outcome));
      writes.addAll([
        _prefs.setInt(_answeredKey, _answered),
        _prefs.setInt(_hitsKey, _hits),
        _prefs.setStringList(_logKey, [for (final r in _log) _encodeRecord(r)]),
      ]);
    }
    if (dailyDay != null) {
      final daily = [...dailyResults(dailyDay), (points: points, hit: hit)];
      writes.add(
        _prefs.setStringList(_dailyKey(dailyDay), [
          for (final r in daily) '${r.points}:${r.hit ? 1 : 0}',
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

  static const _outcomeCodes = {
    Outcome.hit: 'h',
    Outcome.tooHigh: 'o',
    Outcome.tooLow: 'u',
  };

  /// `"geography:85:h"` (category:points:outcome).
  static String _encodeRecord(AnswerRecord r) =>
      '${r.category.name}:${r.points}:${_outcomeCodes[r.outcome]}';

  /// Null for an entry this version cannot read.
  static AnswerRecord? _decodeRecord(String entry) {
    final parts = entry.split(':');
    if (parts.length != 3) return null;
    final category = QuestionCategory.values.asNameMap()[parts[0]];
    final points = int.tryParse(parts[1]);
    final outcome = _outcomeCodes.entries
        .where((e) => e.value == parts[2])
        .map((e) => e.key)
        .firstOrNull;
    if (category == null || points == null || outcome == null) return null;
    return (category: category, points: points, outcome: outcome);
  }
}
