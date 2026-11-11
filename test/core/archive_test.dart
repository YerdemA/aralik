import 'package:aralik/core/archive.dart';
import 'package:aralik/core/mascot_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the archive; broken entries are skipped', () {
    final a = LeaderboardArchive.fromJson({
      'days': [
        {'day': 9, 'nickname': 'Bora', 'points': 300, 'look': '111111111'},
        {'day': 8, 'nickname': 'Aslan', 'points': 200, 'look': null},
        {'nickname': 'Gün yok'},
      ],
      'month': 202610,
      'duels': {
        'bank': [
          {'rank': 1, 'nickname': 'Deniz', 'rating': 60, 'look': 'bozuk'},
        ],
        'math': 'bozuk',
      },
    })!;
    expect(a.month, 202610);
    expect(a.days.map((e) => e.day), [9, 8]);
    expect(a.days.first.value, 300);
    expect(a.days.first.look, MascotLook.parse('111111111'));
    expect(a.days.last.look, MascotLook.philosopher);
    expect(a.bank.single.rank, 1);
    expect(a.bank.single.value, 60);
    expect(a.bank.single.look, MascotLook.philosopher);
    expect(a.math, isEmpty);
  });

  test('not an archive', () {
    expect(LeaderboardArchive.fromJson(null), isNull);
    expect(LeaderboardArchive.fromJson({'days': []}), isNull);
  });
}
