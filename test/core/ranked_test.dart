import 'dart:convert';

import 'package:aralik/core/duel.dart';
import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/ranked.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> row(int rank, String name, {int rating = 1000}) => {
  'rank': rank,
  'nickname': name,
  'rating': rating,
  'played': 4,
  'won': 2,
  'drawn': 1,
  'average': 250,
  'hitRate': 70,
  'look': '120131212',
};

void main() {
  test('months turn in Turkey time', () {
    expect(rankedMonthOf(DateTime.utc(2026, 11, 10)), 202611);
    // 30 Nov 22:30 UTC is already December in Turkey.
    expect(rankedMonthOf(DateTime.utc(2026, 11, 30, 22, 30)), 202612);
    expect(previousRankedMonth(202611), 202610);
    expect(previousRankedMonth(202701), 202612);
    expect(rankedMonthLabel(202611), 'Kasım 2026');
  });

  test('parses a table with the viewer\'s line', () {
    final t = RankedTable.fromJson({
      'month': 202611,
      'current': 202611,
      'mode': 'math',
      'players': 12,
      'top': [row(1, 'Ayşe', rating: 1100), row(2, 'Bora'), 'junk'],
      'me': row(7, 'Cem', rating: 980),
    })!;
    expect(t.mode, RankedMode.math);
    expect(t.players, 12);
    expect(t.top.map((r) => r.nickname), ['Ayşe', 'Bora']);
    expect(t.top.first.rating, 1100);
    expect(t.top.first.lost, 1);
    expect(t.top.first.look, MascotLook.parse('120131212'));
    expect(t.me!.rank, 7);
    expect(RankedTable.fromJson({'month': 'x'}), isNull);
  });

  test('a ranked start and the rating at the end', () {
    final match = DuelMatch();
    for (final m in [
      {
        't': 'start',
        'you': 1,
        'names': ['Ayşe', 'Bora'],
        'questions': ['q1'],
        'questionMs': 15000,
        'ranked': true,
      },
      {
        't': 'rated',
        'ratings': [
          {'before': 1000, 'after': 984},
          {'before': 1000, 'after': 1016},
        ],
      },
    ]) {
      match.handle(DuelEvent.parse(jsonEncode(m))!);
    }
    expect(match.ranked, isTrue);
    expect(match.rating, (before: 1000, after: 1016));
    expect(match.rating!.delta, 16);
  });
}
