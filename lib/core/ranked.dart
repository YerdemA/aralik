/// The monthly ranked duel tables (server/leaderboard/src/ranked.js).
///
/// Duels with a random opponent between two players who joined the
/// leaderboard count; knowledge and math duels have tables of their own.
/// Everyone starts each month at [rankedStart]; a win gains and a loss
/// costs points by Elo, scaled by the match's margin. The server computes
/// everything; the app only shows it.
library;

import 'package:flutter/foundation.dart';

import 'mascot_look.dart';
import 'strings.dart';

/// The rating everyone starts each month with (ranked.js START; 1000
/// until 2026-11-11). Ratings never go below it.
const rankedStart = 0;

/// Which duels a table is for; [query] is the server's `mode`.
enum RankedMode {
  bank('bank'),
  math('math');

  const RankedMode(this.query);
  final String query;
}

/// A month as YYYYMM (202611 is November 2026).
typedef RankedMonth = int;

/// The month in Turkey (UTC+3, no DST) at [now], as the server counts.
RankedMonth rankedMonthOf(DateTime now) {
  final t = now.toUtc().add(const Duration(hours: 3));
  return t.year * 100 + t.month;
}

RankedMonth previousRankedMonth(RankedMonth month) {
  final y = month ~/ 100, m = month % 100;
  return m == 1 ? (y - 1) * 100 + 12 : y * 100 + m - 1;
}

/// "Kasım 2026".
String rankedMonthLabel(RankedMonth month) =>
    '${monthName(month % 100)} ${month ~/ 100}';

/// One player's line of a month's table.
@immutable
class RankedRow {
  const RankedRow({
    required this.rank,
    required this.nickname,
    required this.rating,
    required this.played,
    required this.won,
    required this.drawn,
    required this.average,
    required this.hitRate,
    this.look = MascotLook.philosopher,
  });

  static RankedRow? fromJson(Object? json) {
    if (json is! Map) return null;
    int? n(String key) => json[key] is int ? json[key] as int : null;
    final rank = n('rank'), rating = n('rating'), played = n('played');
    final nickname = json['nickname'];
    if (rank == null || rating == null || played == null) return null;
    if (nickname is! String) return null;
    return RankedRow(
      rank: rank,
      nickname: nickname,
      rating: rating,
      played: played,
      won: n('won') ?? 0,
      drawn: n('drawn') ?? 0,
      average: n('average') ?? 0,
      hitRate: n('hitRate') ?? 0,
      look: MascotLook.parse(json['look'] as String?),
    );
  }

  final int rank;
  final String nickname;
  final int rating;
  final int played;
  final int won;
  final int drawn;
  int get lost => played - won - drawn;

  /// The average match total.
  final int average;

  /// Hit intervals out of all answered, in percent.
  final int hitRate;
  final MascotLook look;
}

/// A month's table as the server sends it.
@immutable
class RankedTable {
  const RankedTable({
    required this.month,
    required this.current,
    required this.mode,
    required this.players,
    required this.top,
    this.me,
  });

  static RankedTable? fromJson(Object? json) {
    if (json is! Map) return null;
    final month = json['month'], current = json['current'];
    final players = json['players'], top = json['top'];
    if (month is! int || current is! int || players is! int || top is! List) {
      return null;
    }
    return RankedTable(
      month: month,
      current: current,
      mode: json['mode'] == 'math' ? RankedMode.math : RankedMode.bank,
      players: players,
      top: [for (final r in top) ?RankedRow.fromJson(r)],
      me: RankedRow.fromJson(json['me']),
    );
  }

  final RankedMonth month;

  /// The server's current month (in Turkey).
  final RankedMonth current;
  final RankedMode mode;
  final int players;
  final List<RankedRow> top;

  /// This player's line; null when they have not played a ranked duel.
  final RankedRow? me;
}

/// A rating before and after a ranked duel.
typedef RatingChange = ({int before, int after});

extension RatingChangeDelta on RatingChange {
  int get delta => after - before;
}
