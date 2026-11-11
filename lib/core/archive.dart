/// The leaderboard's archive (server/leaderboard/src/archive.js): who led
/// each of the last week's finished days, and the first three of the
/// month that ended in both duel tables.
library;

import 'package:flutter/foundation.dart';

import 'mascot_look.dart';
import 'ranked.dart';

/// One name in the archive: a day's leader or a month's podium place.
@immutable
class ArchiveEntry {
  const ArchiveEntry({
    required this.nickname,
    required this.look,
    this.day,
    this.rank,
    this.value,
  });

  final String nickname;
  final MascotLook look;

  /// The day index of a day's leader.
  final int? day;

  /// The place (1–3) on a month's duel table.
  final int? rank;

  /// The day's points or the month's rating.
  final int? value;
}

@immutable
class LeaderboardArchive {
  const LeaderboardArchive({
    required this.days,
    required this.month,
    required this.bank,
    required this.math,
  });

  /// Null when [json] is not an archive. Unreadable entries are skipped.
  static LeaderboardArchive? fromJson(Object? json) {
    if (json is! Map) return null;
    final days = json['days'], month = json['month'], duels = json['duels'];
    if (days is! List || month is! int || duels is! Map) return null;
    return LeaderboardArchive(
      days: [for (final d in days) ?_entry(d, 'day', 'points')],
      month: month,
      bank: _podium(duels['bank']),
      math: _podium(duels['math']),
    );
  }

  static List<ArchiveEntry> _podium(Object? json) => json is List
      ? [for (final r in json) ?_entry(r, 'rank', 'rating')]
      : const [];

  static ArchiveEntry? _entry(Object? json, String key, String valueKey) {
    if (json is! Map) return null;
    final nickname = json['nickname'], at = json[key], value = json[valueKey];
    if (nickname is! String || at is! int) return null;
    return ArchiveEntry(
      nickname: nickname,
      look: MascotLook.parse(json['look'] as String?),
      day: key == 'day' ? at : null,
      rank: key == 'rank' ? at : null,
      value: value is int ? value : null,
    );
  }

  /// Each finished day's leader, newest first (at most a week).
  final List<ArchiveEntry> days;

  /// The month that ended.
  final RankedMonth month;

  /// Its first three in knowledge duels and in math duels.
  final List<ArchiveEntry> bank;
  final List<ArchiveEntry> math;
}
