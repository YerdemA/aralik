import 'package:aralik/core/mascot_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default is the original philosopher, 011100000', () {
    expect(MascotLook.philosopher.code, '011100000');
    expect(MascotLook.parse(null), MascotLook.philosopher);
  });

  test('every look survives its code', () {
    var n = 0;
    for (final g in MascotGender.values) {
      for (final s in MascotSkin.values) {
        for (final b in MascotBeard.values) {
          for (final m in MascotMoustache.values) {
            for (final h in MascotHair.values) {
              for (final t in MascotHat.values) {
                for (final e in MascotEyes.values) {
                  for (final l in MascotGlasses.values) {
                    final look = MascotLook(
                      hairColor: MascotHairColor.values[n % 5],
                      gender: g,
                      skin: s,
                      beard: b,
                      moustache: m,
                      hair: h,
                      hat: t,
                      eyes: e,
                      glasses: l,
                    );
                    expect(look.code, hasLength(9));
                    expect(MascotLook.tryParse(look.code), look);
                    n++;
                  }
                }
              }
            }
          }
        }
      }
    }
    // 2 × 3 × 5 × 5 × 4 × 4 × 4 × 6, "none" counted where there is one;
    // the hair colour (× 5) cycles along.
    expect(n, 57600);
    for (final c in MascotHairColor.values) {
      final look = MascotLook.philosopher.copyWith(hairColor: c);
      expect(MascotLook.tryParse(look.code), look);
    }
  });

  test('a bad code draws the default', () {
    for (final bad in [
      '',
      '01110000', // the first eight-digit draft
      '0111000000',
      '211100000', // no third gender
      '000000060', // glasses 0…5
      '000000005', // hair colours 0…4
      '01110000x',
    ]) {
      expect(MascotLook.tryParse(bad), isNull, reason: bad);
      expect(MascotLook.parse(bad), MascotLook.philosopher);
    }
  });

  test('a woman never shows a beard or a moustache', () {
    final look = MascotLook.woman.copyWith(
      beard: MascotBeard.long,
      moustache: MascotMoustache.walrus,
    );
    expect(look.shownBeard, MascotBeard.none);
    expect(look.shownMoustache, MascotMoustache.none);
    // Kept, though: switching back to a man brings them back.
    expect(
      look.copyWith(gender: MascotGender.man).shownBeard,
      MascotBeard.long,
    );
  });

  test('changes wait three days; the first choice does not', () {
    final at = DateTime(2026, 11, 10, 12);
    expect(nextMascotChangeAfter(null, at), isNull);
    expect(
      nextMascotChangeAfter(at, at.add(const Duration(days: 2))),
      DateTime(2026, 11, 13, 12),
    );
    expect(nextMascotChangeAfter(at, at.add(const Duration(days: 3))), isNull);
  });
}
