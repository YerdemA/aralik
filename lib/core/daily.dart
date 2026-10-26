/// Daily set selection. Everyone sees the same questions on the same local
/// date, so no backend is needed.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

const int questionsPerDay = 5;

/// Day 0 of the game (local calendar date).
final DateTime epoch = DateTime(2026, 11, 1);

/// Days between [epoch] and the local calendar date of [now].
///
/// Computed on calendar dates in UTC, so DST shifts and the time of day do
/// not matter. Negative before the epoch.
int dayIndexFor(DateTime now) {
  final local = now.toLocal();
  final today = DateTime.utc(local.year, local.month, local.day);
  final start = DateTime.utc(epoch.year, epoch.month, epoch.day);
  return today.difference(start).inDays;
}

/// Public puzzle number shown in the share text ("Kabaca #1" on day 0).
/// Zero or negative before the epoch (closed test).
int puzzleNumber(int dayIndex) => dayIndex + 1;

/// Consecutive completed days ending today, or ending yesterday while
/// today's set is not done yet (the streak is still alive until midnight).
int currentStreak(Set<int> completedDays, int today) {
  var day = completedDays.contains(today) ? today : today - 1;
  var streak = 0;
  while (completedDays.contains(day)) {
    streak++;
    day--;
  }
  return streak;
}

/// Longest run of consecutive days in [completedDays].
int longestStreak(Set<int> completedDays) {
  var best = 0;
  for (final day in completedDays) {
    if (completedDays.contains(day - 1)) continue; // not a run's start
    var length = 1;
    while (completedDays.contains(day + length)) {
      length++;
    }
    if (length > best) best = length;
  }
  return best;
}

/// Days of the schedule that free play keeps away from, so the next
/// daily sets are not spoiled.
const int freePlayHorizonDays = 60;

/// The daily sets: day index → five question ids
/// (assets/questions/schedule.json, `{"days": [[id, …], …]}`).
///
/// Separate from the bank's order, so sets can be balanced by difficulty
/// and category. Append-only: days are only ever added at the end, so
/// everyone keeps seeing the same questions on the same day.
class Schedule {
  Schedule(Iterable<List<String>> days)
    : days = List.unmodifiable(<List<String>>[
        for (final d in days) List<String>.unmodifiable(d),
      ]);

  final List<List<String>> days;

  int get length => days.length;

  /// Every id in the schedule.
  Set<String> get ids => {for (final d in days) ...d};

  /// Parses and checks schedule.json: every day has [questionsPerDay]
  /// distinct ids and no question appears twice. Throws [FormatException].
  factory Schedule.parse(String source) {
    final decoded = jsonDecode(source);
    final rawDays = decoded is Map<String, dynamic> ? decoded['days'] : null;
    if (rawDays is! List) {
      throw const FormatException('schedule.json needs a "days" list');
    }
    final seen = <String>{};
    final days = <List<String>>[];
    for (final (i, day) in rawDays.indexed) {
      if (day is! List ||
          day.length != questionsPerDay ||
          day.any((id) => id is! String)) {
        throw FormatException('Day $i must list $questionsPerDay ids: $day');
      }
      for (final id in day.cast<String>()) {
        if (!seen.add(id)) throw FormatException('Day $i repeats $id');
      }
      days.add(List<String>.from(day));
    }
    return Schedule(days);
  }

  /// Question ids of [dayIndex]. Wraps around when the schedule runs out;
  /// days before the epoch (closed test) count back from its end.
  List<String> idsFor(int dayIndex) =>
      days.isEmpty ? const [] : days[dayIndex % days.length];

  /// Ids of the [horizon] days starting with [today], wrapping like
  /// [idsFor]. Covers the whole schedule when it is shorter than [horizon].
  Set<String> upcomingIds(int today, {int horizon = freePlayHorizonDays}) => {
    for (var d = today; d < today + horizon && d < today + length; d++)
      ...idsFor(d),
  };

  /// Whether this schedule keeps every day of [base] unchanged and only
  /// appends days.
  bool extendsSchedule(Schedule base) {
    if (length < base.length) return false;
    for (var i = 0; i < base.length; i++) {
      if (!listEquals(days[i], base.days[i])) return false;
    }
    return true;
  }
}
