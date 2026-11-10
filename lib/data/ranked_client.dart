import 'package:shared_preferences/shared_preferences.dart';

import '../core/ranked.dart';
import 'leaderboard.dart';

/// Why a table could not be read.
enum RankedFailure { offline, server }

class RankedException implements Exception {
  const RankedException(this.failure);
  final RankedFailure failure;
}

/// The monthly ranked duel tables (GET /v1/duel/ranked) and the month-end
/// recap: once a new month starts, the player who played ranked duels in
/// the one that ended sees how it went, once.
class RankedService {
  RankedService({
    required this.serviceUri,
    required this.account,
    required this._prefs,
    JsonRequest? request,
    DateTime Function()? now,
  }) : _request = request ?? defaultJsonRequest,
       _now = now ?? DateTime.now;

  /// The server (manifest's `leaderboard` field), or null without one.
  final Uri? Function() serviceUri;

  /// The leaderboard account, for the viewer's own line; null when not
  /// joined.
  final LeaderboardAccount? Function() account;

  final SharedPreferences _prefs;
  final JsonRequest _request;
  final DateTime Function() _now;

  static const _recapKey = 'ranked_recap_month';

  bool get isAvailable => serviceUri() != null;

  /// [mode]'s table for [month] (this month when null).
  Future<RankedTable> table(RankedMode mode, {RankedMonth? month}) async {
    final base = serviceUri();
    if (base == null) throw const RankedException(RankedFailure.offline);
    final uri = base
        .resolve('v1/duel/ranked')
        .replace(
          queryParameters: {
            'mode': mode.query,
            'month': ?month?.toString(),
            'player': ?account()?.id,
          },
        );
    final JsonReply reply;
    try {
      reply = await _request('GET', uri);
    } on Object {
      throw const RankedException(RankedFailure.offline);
    }
    final table = reply.status == 200 ? RankedTable.fromJson(reply.body) : null;
    if (table == null) throw const RankedException(RankedFailure.server);
    return table;
  }

  /// The tables of the month that just ended in which this player has a
  /// line, unless the recap was shown already ([markRecapShown]); empty
  /// otherwise. Asks the server only while the month's recap is due, so at
  /// most a few times a month. Never throws.
  Future<List<RankedTable>> monthEndRecap() async {
    if (account() == null || !isAvailable) return const [];
    // Months turn in Turkey time, like the server's.
    final ended = previousRankedMonth(rankedMonthOf(_now()));
    if ((_prefs.getInt(_recapKey) ?? 0) >= ended) return const [];
    try {
      final tables = <RankedTable>[];
      for (final mode in RankedMode.values) {
        final t = await table(mode, month: ended);
        if (t.me != null) tables.add(t);
      }
      // Nothing to show: no need to ask again this month.
      if (tables.isEmpty) await markRecapShown(ended);
      return tables;
    } on Object {
      return const [];
    }
  }

  /// The recap of [month] was seen.
  Future<void> markRecapShown(RankedMonth month) =>
      _prefs.setInt(_recapKey, month);
}
