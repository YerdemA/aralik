import 'package:aralik/core/match_share.dart';
import 'package:aralik/core/scoring.dart';
import 'package:aralik/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

MatchShareRow _row(String name, List<int> points, {bool me = false}) =>
    MatchShareRow(
      name: name,
      points: points.fold(0, (a, b) => a + b),
      hits: points.where((p) => p >= 40).length,
      me: me,
      tiers: [for (final p in points) ResultTier.of(points: p, hit: p >= 40)],
    );

void main() {
  test('a duel as text: outcome, totals, both rows of squares', () {
    final share = MatchShare.duel(
      math: false,
      me: _row('Ayşe', [92, 85, 50, -20, 74], me: true),
      opponent: _row('Bora', [70, 40, -50, 30, 88]),
    );
    expect(share.outcome, MatchOutcome.win);
    expect(
      matchShareText(share),
      'Kabaca · Bilgi düellosu · Kazandım!\n'
      'Ayşe (Ben) 281 – 178 Bora\n'
      '🟩🟩🟨⬛🟩\n'
      '🟩🟨⬛⬛🟩',
    );
  });

  test('a math duel lost, or won because the opponent left', () {
    final lost = MatchShare.duel(
      math: true,
      me: _row('Ben', [10], me: true),
      opponent: _row('Bora', [90]),
    );
    expect(lost.kind.label, AppStrings.mathDuelTitle);
    expect(lost.headline, AppStrings.shareDuelLoss);
    final left = MatchShare.duel(
      math: false,
      me: _row('Ben', [10], me: true),
      opponent: _row('Bora', [90]),
      opponentLeft: true,
    );
    expect(left.outcome, MatchOutcome.win);
    expect(matchShareText(left), endsWith(AppStrings.duelOpponentLeft));
    final draw = MatchShare.duel(
      math: false,
      me: _row('Ben', [50], me: true),
      opponent: _row('Bora', [50]),
    );
    expect(draw.headline, AppStrings.shareDuelDraw);
  });

  test('a tournament as text: place, own squares, the standings', () {
    final share = MatchShare.tournament(
      rows: [
        _row('Ayşe', [90, 90]),
        _row('Ece', [92, 20], me: true),
        _row('Cem', [40, 40]),
        const MatchShareRow(name: 'Deniz', points: -100, hits: 0, left: true),
      ],
    );
    expect(share.rank, 2);
    expect(share.fileName, AppStrings.shareTournamentFileName);
    expect(
      matchShareText(share),
      'Kabaca · Turnuva · 2. oldum\n'
      '🟩⬛\n'
      '🥇 Ayşe 180\n'
      '🥈 Ece (Ben) 112\n'
      '🥉 Cem 80\n'
      '4. Deniz -100 (ayrıldı)',
    );
    final first = MatchShare.tournament(
      rows: [
        _row('Ben', [1], me: true),
        _row('Ayşe', [0]),
      ],
    );
    expect(first.headline, 'Birinci oldum!');
  });
}
