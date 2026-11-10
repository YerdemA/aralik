import 'package:flutter/foundation.dart';

import 'scoring.dart';
import 'strings.dart';

/// What a shared duel or tournament result is.
enum MatchKind {
  duel,
  mathDuel,
  tournament;

  String get label => switch (this) {
    MatchKind.duel => AppStrings.duelModeBank,
    MatchKind.mathDuel => AppStrings.mathDuelTitle,
    MatchKind.tournament => AppStrings.tournament,
  };
}

/// A duel's end from this player's side.
enum MatchOutcome { win, loss, draw }

/// One player's line on a shared duel or tournament result.
@immutable
class MatchShareRow {
  const MatchShareRow({
    required this.name,
    required this.points,
    required this.hits,
    this.me = false,
    this.left = false,
    this.tiers = const [],
  });

  /// As shown on this phone (a blocked name is already replaced).
  final String name;
  final int points;
  final int hits;

  /// This player.
  final bool me;

  /// Left the match before its end.
  final bool left;

  /// Each question's square; empty when not known (others in a tournament).
  final List<ResultTier> tiers;

  /// The name as shared: this player's with "(Ben)" after it.
  String get label => me ? '$name (${AppStrings.shareMe})' : name;
}

/// A duel or tournament result to share.
@immutable
class MatchShare {
  MatchShare.duel({
    required bool math,
    required MatchShareRow me,
    required MatchShareRow opponent,
    this.opponentLeft = false,
  }) : kind = math ? MatchKind.mathDuel : MatchKind.duel,
       rows = [me, opponent];

  const MatchShare.tournament({required this.rows})
    : kind = MatchKind.tournament,
      opponentLeft = false;

  final MatchKind kind;
  final bool opponentLeft;

  /// A duel: this player, then the opponent. A tournament: the standings.
  final List<MatchShareRow> rows;

  bool get isDuel => kind != MatchKind.tournament;

  MatchShareRow get me => rows.firstWhere((r) => r.me);

  /// The duel's opponent.
  MatchShareRow get opponent => rows.firstWhere((r) => !r.me);

  /// A duel's outcome for this player.
  MatchOutcome get outcome {
    final diff = me.points - opponent.points;
    if (opponentLeft || diff > 0) return MatchOutcome.win;
    return diff < 0 ? MatchOutcome.loss : MatchOutcome.draw;
  }

  /// This player's place in a tournament (1 = first).
  int get rank => rows.indexWhere((r) => r.me) + 1;

  /// "Kazandım!", "2. oldum" …
  String get headline => isDuel
      ? switch (outcome) {
          MatchOutcome.win => AppStrings.shareDuelWin,
          MatchOutcome.loss => AppStrings.shareDuelLoss,
          MatchOutcome.draw => AppStrings.shareDuelDraw,
        }
      : AppStrings.shareTournamentRank(rank);

  String get fileName => isDuel
      ? AppStrings.shareDuelFileName
      : AppStrings.shareTournamentFileName;
}

/// The result as text, Wordle style:
///
/// ```
/// Kabaca · Bilgi düellosu · Kazandım!
/// Ayşe (Ben) 320 – 280 Bora
/// 🟩🟨⬛🟩🟩
/// 🟨🟨⬛⬛🟩
/// ```
///
/// ```
/// Kabaca · Turnuva · 2. oldum
/// 🟩🟨⬛🟩🟩
/// 🥇 Ayşe 410
/// 🥈 Ayşe (Ben) 320
/// 🥉 Cem 200
/// 4. Deniz 150
/// ```
String matchShareText(MatchShare share) {
  final title = [
    AppStrings.appName,
    share.kind.label,
    share.headline,
  ].join(' · ');
  String squares(MatchShareRow r) => r.tiers.map((t) => t.emoji).join();
  if (share.isDuel) {
    final me = share.me, them = share.opponent;
    return [
      title,
      '${me.label} ${me.points} – ${them.points} ${them.label}',
      if (me.tiers.isNotEmpty) squares(me),
      if (them.tiers.isNotEmpty) squares(them),
      if (share.opponentLeft) AppStrings.duelOpponentLeft,
    ].join('\n');
  }
  const medals = ['🥇', '🥈', '🥉'];
  return [
    title,
    if (share.me.tiers.isNotEmpty) squares(share.me),
    for (final (k, r) in share.rows.indexed)
      [
        k < medals.length ? medals[k] : '${k + 1}.',
        r.label,
        '${r.points}',
        if (r.left) '(${AppStrings.tournamentLeft})',
      ].join(' '),
  ].join('\n');
}
