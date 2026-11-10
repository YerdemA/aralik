/// The player's own mascot: the philosopher with chosen features.
///
/// Stored and sent as a nine-digit code, one digit per feature in the
/// order of [MascotLook.code] (e.g. `011100000` is the default
/// philosopher). Opponents see it in duels and tournaments; a code that
/// does not parse draws the default.
library;

enum MascotGender { man, woman }

/// Skin tones, light to dark; [medium] is the original philosopher.
enum MascotSkin { light, medium, dark }

/// Beards; [full] is the original round white beard.
enum MascotBeard { none, full, short, goatee, long }

/// Moustaches; [classic] is the original.
enum MascotMoustache { none, classic, pencil, handlebar, walrus }

/// Hair; [tufts] is the original bald head with two tufts.
enum MascotHair { tufts, curly, long, bun }

enum MascotHat { none, fez, mortarboard, beret }

/// How open eyes look (closed, laughing eyes keep their arcs).
enum MascotEyes { dots, round, almond, sleepy }

/// Glasses: thin gold wire, thick black frames, reading glasses on a
/// cord, aviator sunglasses, a monocle.
enum MascotGlasses { none, round, square, halfMoon, sunglasses, monocle }

/// For hair, beard and moustache; [white] is the original philosopher's.
enum MascotHairColor { white, black, brown, blonde, red }

class MascotLook {
  const MascotLook({
    this.gender = MascotGender.man,
    this.skin = MascotSkin.medium,
    this.beard = MascotBeard.full,
    this.moustache = MascotMoustache.classic,
    this.hair = MascotHair.tufts,
    this.hat = MascotHat.none,
    this.eyes = MascotEyes.dots,
    this.glasses = MascotGlasses.none,
    this.hairColor = MascotHairColor.white,
  });

  /// The original philosopher (the app icon).
  static const philosopher = MascotLook();

  /// A starting point when the player picks a woman.
  static const woman = MascotLook(
    gender: MascotGender.woman,
    beard: MascotBeard.none,
    moustache: MascotMoustache.none,
    hair: MascotHair.long,
    eyes: MascotEyes.almond,
    hairColor: MascotHairColor.brown,
  );

  final MascotGender gender;
  final MascotSkin skin;
  final MascotBeard beard;
  final MascotMoustache moustache;
  final MascotHair hair;
  final MascotHat hat;
  final MascotEyes eyes;
  final MascotGlasses glasses;
  final MascotHairColor hairColor;

  bool get isWoman => gender == MascotGender.woman;

  /// The beard drawn: a woman has none whatever is stored.
  MascotBeard get shownBeard => isWoman ? MascotBeard.none : beard;

  MascotMoustache get shownMoustache =>
      isWoman ? MascotMoustache.none : moustache;

  /// Nine digits, one per feature.
  String get code => [
    gender,
    skin,
    beard,
    moustache,
    hair,
    hat,
    eyes,
    glasses,
    hairColor,
  ].map((e) => e.index).join();

  /// Options per digit; the server's look.js has the same list.
  static const _sizes = [2, 3, 5, 5, 4, 4, 4, 6, 5];

  /// The look of [code], or null when it is not a valid code.
  static MascotLook? tryParse(String? code) {
    if (code == null || code.length != _sizes.length) return null;
    final d = <int>[];
    for (var i = 0; i < code.length; i++) {
      final v = code.codeUnitAt(i) - 0x30;
      if (v < 0 || v >= _sizes[i]) return null;
      d.add(v);
    }
    return MascotLook(
      gender: MascotGender.values[d[0]],
      skin: MascotSkin.values[d[1]],
      beard: MascotBeard.values[d[2]],
      moustache: MascotMoustache.values[d[3]],
      hair: MascotHair.values[d[4]],
      hat: MascotHat.values[d[5]],
      eyes: MascotEyes.values[d[6]],
      glasses: MascotGlasses.values[d[7]],
      hairColor: MascotHairColor.values[d[8]],
    );
  }

  /// The look of [code], or the default philosopher.
  static MascotLook parse(String? code) => tryParse(code) ?? philosopher;

  MascotLook copyWith({
    MascotGender? gender,
    MascotSkin? skin,
    MascotBeard? beard,
    MascotMoustache? moustache,
    MascotHair? hair,
    MascotHat? hat,
    MascotEyes? eyes,
    MascotGlasses? glasses,
    MascotHairColor? hairColor,
  }) => MascotLook(
    gender: gender ?? this.gender,
    skin: skin ?? this.skin,
    beard: beard ?? this.beard,
    moustache: moustache ?? this.moustache,
    hair: hair ?? this.hair,
    hat: hat ?? this.hat,
    eyes: eyes ?? this.eyes,
    glasses: glasses ?? this.glasses,
    hairColor: hairColor ?? this.hairColor,
  );

  @override
  bool operator ==(Object other) => other is MascotLook && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'MascotLook($code)';
}

/// How often the mascot may change, like the user name.
const mascotChangeEvery = Duration(days: 3);

/// When a mascot last changed at [changedAt] may change again, or null
/// when it may change now. The first choice is not a change.
DateTime? nextMascotChangeAfter(DateTime? changedAt, DateTime now) {
  if (changedAt == null) return null;
  final at = changedAt.add(mascotChangeEvery);
  return now.isBefore(at) ? at : null;
}
