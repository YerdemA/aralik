import 'dart:math' as math;
import 'dart:ui';

import '../core/day_mood.dart';
import '../core/mascot_look.dart';

/// How the philosopher ends a duel: won, lost or drew.
enum DuelPose { champion, defeated, even }

/// The Kabaca mascot: a thinking philosopher (bald, white beard, eyes
/// closed, one brow raised) in a terracotta toga, with a thought bubble
/// holding a question mark. Drawn with plain canvas calls so the app icon
/// (tools/icon/render_icon_test.dart) and the share card are the same.
///
/// Coordinates are in "design units": the icon's visible area is 1 × 1.
/// [monochrome] draws every shape white and cuts the ink lines out, so the
/// face survives as line art in Android 13 themed icons.
///
/// With a [DayMood] he reacts to the day's score on the share card (face,
/// arms and a prop); with a [DuelPose] he ends a duel; without either he is
/// the thinking icon.
///
/// [look] dresses him up as the player's own mascot (skin, hair, beard,
/// moustache, hat, eyes, glasses); the default look is the icon.
class Philosopher {
  const Philosopher({
    this.monochrome = false,
    this.look = MascotLook.philosopher,
  });

  final bool monochrome;
  final MascotLook look;

  Color get _skin => switch (look.skin) {
    MascotSkin.light => const Color(0xFFFCE4D2),
    MascotSkin.medium => skin,
    MascotSkin.dark => const Color(0xFF8A5536),
  };

  Color get _skinShade => switch (look.skin) {
    MascotSkin.light => const Color(0xFFEFC2A2),
    MascotSkin.medium => skinShade,
    MascotSkin.dark => const Color(0xFF6A3E25),
  };

  /// Hair, beard and moustache.
  Color get _hair => switch (look.hairColor) {
    MascotHairColor.white => beard,
    MascotHairColor.black => const Color(0xFF2F2A2C),
    MascotHairColor.brown => const Color(0xFF7B4A28),
    MascotHairColor.blonde => const Color(0xFFF2C14E),
    MascotHairColor.red => const Color(0xFFC9541F),
  };

  Color get _hairShade => switch (look.hairColor) {
    MascotHairColor.white => beardShade,
    MascotHairColor.black => const Color(0xFF57505A),
    MascotHairColor.brown => const Color(0xFF5A3218),
    MascotHairColor.blonde => const Color(0xFFD69F2C),
    MascotHairColor.red => const Color(0xFFA03A12),
  };

  /// A woman wears a plum chiton, a man the terracotta toga.
  Color get _toga => look.isWoman ? const Color(0xFF9B59B6) : toga;

  Color get _togaShade => look.isWoman ? const Color(0xFF7A3D93) : togaShade;

  static const lips = Color(0xFFD94A64);
  static const gold = Color(0xFFE8B030);

  /// Brows: thick and straight for a man, thin for a woman.
  Paint _brow(double k) => _line(ink, k * (look.isWoman ? 0.011 : 0.022));

  /// A drawn mouth line: rose lips for a woman.
  Paint _mouthLine(double k) =>
      look.isWoman ? _line(lips, k * 0.024) : _line(ink, k * 0.016);

  static const ink = Color(0xFF1C2742);
  static const skin = Color(0xFFF2C29B);
  static const skinShade = Color(0xFFDDA27A);
  static const beard = Color(0xFFF7F3EC);
  static const beardShade = Color(0xFFDCD5CB);
  static const toga = Color(0xFFE0784A);
  static const togaShade = Color(0xFFC25E33);
  static const white = Color(0xFFFFFFFF);
  static const blush = Color(0xFFF59AA0);
  static const mouth = Color(0xFF5B1A2A);
  static const tongue = Color(0xFFF07C8A);
  static const drop = Color(0xFF8EC5FF);
  static const cloud = Color(0xFFB8BED6);
  static const laurel = Color(0xFF6DB356);
  static const laurelShade = Color(0xFF4E8F3B);
  static const flagPole = Color(0xFFB07A4F);

  /// Outline half-width.
  static const double outline = 0.016;

  /// The full icon composition: philosopher and bubble.
  void paintScene(Canvas c, {double bottom = 1.3}) {
    paintPhilosopher(c, const Offset(0.4, 0.52), 1.25, bottom: bottom);
    // Inside the 66 dp safe circle (radius ≈ 0.46) every launcher shows.
    paintThought(c, const Offset(0.6, 0.33), const Offset(0.71, 0.24), 0.14);
  }

  Paint _fill(Color color) => Paint()..color = monochrome ? white : color;

  Paint _line(Color color, double width) => Paint()
    ..color = monochrome ? white : color
    ..blendMode = monochrome ? BlendMode.clear : BlendMode.srcOver
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// A filled shape with a cartoon outline.
  void _outlined(Canvas c, Path p, Color color) {
    c.drawPath(p, _line(ink, outline * 2));
    c.drawPath(p, _fill(color));
  }

  /// Union of circles (beard, hair, cloud) as one path.
  static Path _blob(List<(double, double, double)> circles) {
    var p = Path();
    for (final (x, y, r) in circles) {
      p = Path.combine(
        PathOperation.union,
        p,
        Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r)),
      );
    }
    return p;
  }

  /// Thought bubble: two dots trailing from [from] to a cloud at [at].
  void paintThought(Canvas c, Offset from, Offset at, double size) {
    final dir = at - from;
    for (final (t, r) in [(0.0, 0.022), (0.28, 0.032)]) {
      _outlined(
        c,
        Path()..addOval(Rect.fromCircle(center: from + dir * t, radius: r)),
        white,
      );
    }
    final s = size;
    _outlined(
      c,
      _blob([
        (at.dx - s * 0.42, at.dy + s * 0.05, s * 0.32),
        (at.dx - s * 0.12, at.dy - s * 0.22, s * 0.36),
        (at.dx + s * 0.25, at.dy - s * 0.15, s * 0.34),
        (at.dx + s * 0.45, at.dy + s * 0.12, s * 0.3),
        (at.dx + s * 0.05, at.dy + s * 0.2, s * 0.36),
      ]),
      white,
    );
    _questionMark(c, at, s * 0.82);
  }

  /// A bold "?" of height [h] centred at [at].
  void _questionMark(Canvas c, Offset at, double h) {
    final r = h * 0.22;
    final cx = at.dx;
    final top = at.dy - h * 0.42;
    final hook = Path()
      ..moveTo(cx - r, top + r)
      ..arcToPoint(Offset(cx + r, top + r), radius: Radius.circular(r))
      ..cubicTo(cx + r, top + r * 1.8, cx, top + r * 1.7, cx, top + r * 2.45)
      ..lineTo(cx, top + r * 2.6);
    c.drawPath(hook, _line(ink, h * 0.15));
    c.drawCircle(
      Offset(cx, at.dy + h * 0.36),
      h * 0.085,
      Paint()
        ..color = ink
        ..blendMode = monochrome ? BlendMode.clear : BlendMode.srcOver,
    );
  }

  /// Bald head centred at [h], white beard and a toga reaching down to
  /// [bottom]; [k] scales. Without a [mood] or a [pose]: closed thinking
  /// eyes, or with [awake] open eyes and a small smile (the mascot
  /// editor, the players' faces). [sash] draws a band across the toga in a
  /// player's colour.
  void paintPhilosopher(
    Canvas c,
    Offset h,
    double k, {
    double bottom = 1.3,
    DayMood? mood,
    DuelPose? pose,
    Color? sash,
    bool awake = false,
  }) {
    assert(mood == null || pose == null, 'a mood or a pose, not both');
    double s(double v) => v * k;
    final hx = h.dx;

    // Toga and shoulders, with a drape line. Proud puffs the chest out;
    // down slumps the shoulders and drops the head.
    final (wide, hip, top) = switch ((mood, pose)) {
      (DayMood.proud, _) || (_, DuelPose.champion) => (0.30, 0.44, 0.25),
      (DayMood.down, _) || (_, DuelPose.defeated) => (0.18, 0.31, 0.31),
      _ => (0.2, 0.36, 0.27),
    };
    // A woman's shoulders are narrower.
    final shoulder = look.isWoman ? wide * 0.82 : wide;
    final waist = look.isWoman ? hip * 0.86 : hip;
    final bodyY = h.dy;
    // Arms come out from behind the toga (the head-scratching hand is drawn
    // again over the head below).
    if (mood != null) _arms(c, h, k, mood);
    if (pose != null) _duelArms(c, h, k, pose);
    final hy =
        h.dy +
        (mood == DayMood.down
            ? s(0.035)
            : pose == DuelPose.defeated
            ? s(0.05)
            : 0);
    // The neck, its foot under the toga (the beard used to hide it).
    _outlined(
      c,
      Path()..addRect(
        Rect.fromLTRB(
          hx - s(0.06),
          hy + s(0.08),
          hx + s(0.06),
          bodyY + s(top + 0.06),
        ),
      ),
      _skin,
    );
    final togaPath = Path()
      ..moveTo(hx - s(waist), bottom)
      ..cubicTo(
        hx - s(waist - 0.02),
        bodyY + s(top + 0.07),
        hx - s(shoulder),
        bodyY + s(top),
        hx,
        bodyY + s(top),
      )
      ..cubicTo(
        hx + s(shoulder),
        bodyY + s(top),
        hx + s(waist - 0.02),
        bodyY + s(top + 0.07),
        hx + s(waist),
        bottom,
      )
      ..close();
    _outlined(c, togaPath, _toga);
    if (!monochrome) {
      c.save();
      c.clipPath(togaPath);
      c.drawPath(
        Path()
          ..moveTo(hx - s(waist - 0.09), bodyY + s(top + 0.09))
          ..quadraticBezierTo(
            hx + s(0.02),
            bodyY + s(top + 0.29),
            hx + s(waist - 0.06),
            bottom,
          ),
        _line(_togaShade, s(0.022)),
      );
      if (sash != null) {
        // A band from the left shoulder to the right hip.
        final band = Path()
          ..moveTo(hx - s(shoulder * 0.8), bodyY + s(top + 0.02))
          ..quadraticBezierTo(
            hx + s(0.02),
            bodyY + s(top + 0.2),
            hx + s(waist),
            bottom - s(0.08),
          );
        c.drawPath(band, _line(ink, s(0.085) + outline * 2));
        c.drawPath(band, _line(sash, s(0.085)));
        c.drawPath(band, _line(white.withValues(alpha: 0.35), s(0.012)));
      }
      c.restore();
      if (mood == DayMood.proud || pose == DuelPose.champion) {
        // The puffed chest.
        for (final side in [-1.0, 1.0]) {
          c.drawPath(
            Path()
              ..moveTo(hx + side * s(0.05), bodyY + s(0.43))
              ..quadraticBezierTo(
                hx + side * s(0.17),
                bodyY + s(0.47),
                hx + side * s(0.26),
                bodyY + s(0.39),
              ),
            _line(_togaShade, s(0.016)),
          );
        }
      }
    }

    // Hair behind the head, the ears (long hair covers them) and the original tufts above them.
    _hairBehind(c, hx, hy, k);
    if (look.hair != MascotHair.long) {
      for (final side in [-1.0, 1.0]) {
        _outlined(
          c,
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(hx + side * s(0.165), hy + s(0.03)),
              width: s(0.075),
              height: s(0.11),
            ),
          ),
          _skin,
        );
      }
    }
    if (look.hair == MascotHair.tufts) {
      for (final side in [-1.0, 1.0]) {
        _outlined(
          c,
          _blob([
            (hx + side * s(0.16), hy - s(0.045), s(0.05)),
            (hx + side * s(0.175), hy, s(0.045)),
            (hx + side * s(0.145), hy - s(0.08), s(0.04)),
          ]),
          _hair,
        );
      }
    }

    // Head, its shine and a thinking wrinkle.
    _outlined(c, _headOval(hx, hy, k), _skin);
    if (look.isWoman) {
      // Gold hoops below the ears.
      for (final side in [-1.0, 1.0]) {
        final at = Offset(hx + side * s(0.16), hy + s(0.11));
        c.drawCircle(at, s(0.026), _line(ink, s(0.014) + outline * 2));
        c.drawCircle(
          at,
          s(0.026),
          _line(gold, s(0.014))..blendMode = BlendMode.srcOver,
        );
      }
    }
    if (mood != null) _cheeks(c, hx, hy, k, mood);
    if (pose == DuelPose.champion) _cheeks(c, hx, hy, k, DayMood.great);
    if (look.isWoman && mood == null && pose == null) {
      _cheeks(c, hx, hy, k, DayMood.great);
    }
    if (!monochrome) {
      c.drawPath(
        Path()..addArc(
          Rect.fromCenter(
            center: Offset(hx - s(0.045), hy - s(0.12)),
            width: s(0.09),
            height: s(0.06),
          ),
          3.6,
          1.2,
        ),
        _line(white.withValues(alpha: 0.7), s(0.016)),
      );
      if (!look.isWoman) {
        c.drawPath(
          Path()
            ..moveTo(hx - s(0.05), hy - s(0.105))
            ..quadraticBezierTo(hx, hy - s(0.125), hx + s(0.05), hy - s(0.105)),
          _line(_skinShade, s(0.012)),
        );
      }
    }
    _hairOnTop(c, hx, hy, k);

    _beard(c, hx, hy, k);

    if (mood != null) _mouth(c, hx, hy, k, mood);
    if (pose != null) _duelMouth(c, hx, hy, k, pose);
    if (mood == null && pose == null && awake) {
      if (look.isWoman) {
        // Full rose lips in a small smile.
        final lip = Path()
          ..moveTo(hx - s(0.048), hy + s(0.118))
          ..quadraticBezierTo(hx - s(0.02), hy + s(0.098), hx, hy + s(0.11))
          ..quadraticBezierTo(
            hx + s(0.02),
            hy + s(0.098),
            hx + s(0.048),
            hy + s(0.118),
          )
          ..quadraticBezierTo(hx, hy + s(0.165), hx - s(0.048), hy + s(0.118))
          ..close();
        _outlined(c, lip, lips);
        c.drawLine(
          Offset(hx - s(0.04), hy + s(0.12)),
          Offset(hx + s(0.04), hy + s(0.12)),
          _line(mouth, s(0.008)),
        );
      } else {
        c.drawPath(
          Path()
            ..moveTo(hx - s(0.04), hy + s(0.12))
            ..quadraticBezierTo(hx, hy + s(0.15), hx + s(0.04), hy + s(0.12)),
          _line(ink, s(0.016)),
        );
      }
    }

    // Moustache, then the nose on top of it.
    _moustache(c, hx, hy, k);
    _outlined(
      c,
      Path()
        ..moveTo(hx - s(0.008), hy - s(0.01))
        ..quadraticBezierTo(hx - s(0.035), hy + s(0.055), hx, hy + s(0.06))
        ..quadraticBezierTo(
          hx + s(0.03),
          hy + s(0.058),
          hx + s(0.015),
          hy + s(0.035),
        ),
      _skin,
    );

    if (mood != null) {
      _eyes(c, hx, hy, k, mood);
    } else if (pose != null) {
      _duelEyes(c, hx, hy, k, pose);
    } else if (awake) {
      for (final side in [-1.0, 1.0]) {
        _openEye(c, Offset(hx + side * s(0.062), hy - s(0.005)), k, 0.02, side);
        c.drawPath(
          Path()
            ..moveTo(hx + side * s(0.035), hy - s(0.075))
            ..quadraticBezierTo(
              hx + side * s(0.066),
              hy - s(look.isWoman ? 0.1 : 0.088),
              hx + side * s(0.098),
              hy - s(0.075),
            ),
          _brow(k),
        );
      }
    } else {
      _thinkingEyes(c, hx, hy, k);
    }
    _glasses(c, hx, hy, k);
    // A hat takes the laurel's place.
    if (pose == DuelPose.champion && look.hat == MascotHat.none) {
      _laurel(c, hx, hy, k);
    }
    _hat(c, hx, hy, k);

    if (mood == DayMood.unsure) {
      // The hand on top of his head.
      final hand = Offset(hx + s(0.17), hy - s(0.13));
      c.drawCircle(hand, s(0.055) + outline, _fill(ink));
      c.drawCircle(hand, s(0.055), _fill(_skin));
      for (final dx in [-0.02, 0.012]) {
        c.drawLine(
          hand + Offset(s(dx), s(0.01)),
          hand + Offset(s(dx + 0.012), s(0.045)),
          _line(_skinShade, s(0.01)),
        );
      }
      _sweat(c, Offset(hx - s(0.13), hy - s(0.1)), s(0.05));
    }
    if (mood == DayMood.down) {
      final above = switch (look.hat) {
        MascotHat.none => 0.33,
        MascotHat.fez => 0.48,
        _ => 0.43,
      };
      _rainCloud(c, Offset(hx, hy - s(above)), k);
    }
  }

  Path _headOval(double hx, double hy, double k, [double grow = 0]) =>
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(hx, hy - k * 0.02),
          width: k * (0.29 + grow),
          height: k * (0.33 + grow),
        ),
      );

  /// Closed eyes; the right brow raised in thought.
  void _thinkingEyes(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    final eye = _line(ink, s(0.016));
    for (final side in [-1.0, 1.0]) {
      c.drawPath(
        Path()..addArc(
          Rect.fromCenter(
            center: Offset(hx + side * s(0.062), hy - s(0.005)),
            width: s(0.06),
            height: s(0.04),
          ),
          0.2,
          2.74,
        ),
        eye,
      );
      if (look.isWoman && !monochrome) {
        final end = Offset(hx + side * s(0.092), hy + s(0.0));
        c.drawLine(end, end + Offset(side * s(0.018), s(0.006)), eye);
      }
    }
    c.drawLine(
      Offset(hx - s(0.095), hy - s(0.06)),
      Offset(hx - s(0.035), hy - s(0.055)),
      _brow(k),
    );
    c.drawPath(
      Path()
        ..moveTo(hx + s(0.032), hy - s(0.065))
        ..quadraticBezierTo(
          hx + s(0.065),
          hy - s(0.09),
          hx + s(0.098),
          hy - s(0.07),
        ),
      _brow(k),
    );
  }

  /// An open eye of the look's kind, radius [r] (in units of [k]) at
  /// [at]; [side] is −1 for the eye on the left, 1 for the other.
  void _openEye(Canvas c, Offset at, double k, double r, double side) {
    final rr = r * k;
    void shine(Offset centre, double size) {
      if (monochrome) return;
      c.drawCircle(
        centre + Offset(-size * 0.9, -size * 1.1),
        size,
        _fill(white),
      );
    }

    switch (look.eyes) {
      case MascotEyes.dots:
        c.drawCircle(at, rr, _fill(ink));
        shine(at, rr * 0.32);
      case MascotEyes.round:
        // Big white eyes, pupils looking up a little.
        final white = rr * 1.95;
        c.drawCircle(at, white + k * 0.007, _fill(ink));
        c.drawCircle(at, white, _fill(Philosopher.white));
        final pupil = at + Offset(side * -rr * 0.15, -rr * 0.25);
        c.drawCircle(pupil, rr * 1.05, _fill(ink));
        shine(pupil, rr * 0.4);
      case MascotEyes.almond:
        // Kohl-lined, with a wing flicking up at the outer corner.
        final eye = Path()
          ..moveTo(at.dx - rr * 1.7, at.dy)
          ..quadraticBezierTo(at.dx, at.dy - rr * 1.6, at.dx + rr * 1.7, at.dy)
          ..quadraticBezierTo(at.dx, at.dy + rr * 1.4, at.dx - rr * 1.7, at.dy)
          ..close();
        c.drawPath(eye, _fill(white));
        c.drawCircle(at, rr * 0.85, _fill(ink));
        shine(at, rr * 0.28);
        c.drawPath(eye, _line(ink, k * 0.013));
        final corner = at + Offset(side * rr * 1.7, 0);
        c.drawPath(
          Path()
            ..moveTo(at.dx + side * rr * 0.2, at.dy - rr * 0.95)
            ..quadraticBezierTo(
              corner.dx,
              corner.dy - rr * 0.6,
              corner.dx + side * k * 0.022,
              corner.dy - k * 0.02,
            ),
          _line(ink, k * 0.016),
        );
      case MascotEyes.sleepy:
        c.drawCircle(at, rr, _fill(ink));
        shine(at, rr * 0.28);
        // A heavy lid over the top half and bags below.
        c.drawPath(
          Path()..addArc(
            Rect.fromCircle(center: at, radius: rr * 1.4),
            math.pi,
            math.pi,
          ),
          _fill(_skinShade),
        );
        c.drawLine(
          at + Offset(-rr * 1.45, 0),
          at + Offset(rr * 1.45, 0),
          _line(ink, k * 0.016),
        );
        c.drawArc(
          Rect.fromCenter(
            center: at + Offset(0, rr * 1.4),
            width: rr * 2.4,
            height: rr * 1.2,
          ),
          0.3,
          math.pi - 0.6,
          false,
          _line(_skinShade, k * 0.011),
        );
    }
    if (look.isWoman && !monochrome) {
      // Three bold lashes on the outer side.
      final lash = _line(ink, k * 0.012);
      final top = look.eyes == MascotEyes.round ? rr * 1.95 : rr * 1.05;
      for (final (a, len) in [(0.35, 0.02), (0.75, 0.024), (1.15, 0.02)]) {
        final dir = Offset(side * math.sin(a), -math.cos(a));
        final from = at + dir * top;
        c.drawLine(from, from + dir * (k * len), lash);
      }
    }
  }

  /// Hair drawn before the head: the afro's volume, long hair falling to
  /// the shoulders, the bun on the crown.
  void _hairBehind(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    switch (look.hair) {
      case MascotHair.curly:
        final centre = Offset(hx, hy - s(0.06));
        final puffs = <(double, double, double)>[
          (centre.dx, centre.dy, s(0.2)),
        ];
        for (var i = 0; i <= 10; i++) {
          final a = math.pi * (0.8 + i * 0.14);
          puffs.add((
            centre.dx + math.cos(a) * s(0.2),
            centre.dy + math.sin(a) * s(0.19),
            s(0.075),
          ));
        }
        _outlined(c, _blob(puffs), _hair);
        if (!monochrome) {
          for (final (x, y, r) in puffs.skip(1)) {
            c.drawArc(
              Rect.fromCircle(center: Offset(x, y), radius: r * 0.5),
              0.6,
              3.4,
              false,
              _line(_hairShade, s(0.012)),
            );
          }
        }
      case MascotHair.long:
        // Waves falling past the ears to the shoulders, ending in curls.
        final waves = <(double, double, double)>[(hx, hy - s(0.05), s(0.19))];
        for (final side in [-1.0, 1.0]) {
          for (final (x, y, r) in [
            (0.17, -0.02, 0.06),
            (0.19, 0.06, 0.06),
            (0.2, 0.14, 0.058),
            (0.2, 0.22, 0.055),
            (0.19, 0.29, 0.05),
          ]) {
            waves.add((hx + side * s(x), hy + s(y), s(r)));
          }
        }
        _outlined(c, _blob(waves), _hair);
        if (!monochrome) {
          for (final side in [-1.0, 1.0]) {
            for (final dx in [0.0, 0.035]) {
              c.drawPath(
                Path()
                  ..moveTo(hx + side * s(0.16 + dx), hy + s(0.02))
                  ..quadraticBezierTo(
                    hx + side * s(0.21 + dx),
                    hy + s(0.13),
                    hx + side * s(0.15 + dx),
                    hy + s(0.27),
                  ),
                _line(_hairShade, s(0.012)),
              );
            }
          }
        }
      case MascotHair.bun:
        // A big bun high on the crown, with a band round its base.
        final bun = Offset(hx, hy - s(0.235));
        _outlined(
          c,
          Path()..addOval(Rect.fromCircle(center: bun, radius: s(0.09))),
          _hair,
        );
        if (!monochrome) {
          c.drawArc(
            Rect.fromCircle(center: bun, radius: s(0.055)),
            3.5,
            2.6,
            false,
            _line(_hairShade, s(0.012)),
          );
        }
        c.drawLine(
          Offset(hx - s(0.06), hy - s(0.165)),
          Offset(hx + s(0.06), hy - s(0.165)),
          _line(ink, s(0.026) + outline),
        );
        c.drawLine(
          Offset(hx - s(0.06), hy - s(0.165)),
          Offset(hx + s(0.06), hy - s(0.165)),
          _line(look.isWoman ? lips : const Color(0xFF3E6FD8), s(0.026))
            ..blendMode = BlendMode.srcOver,
        );
      case MascotHair.tufts:
        break;
    }
  }

  /// Hair over the top of the head (none for the bald tufts).
  void _hairOnTop(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    Path cut(Path edge) =>
        Path.combine(PathOperation.intersect, _headOval(hx, hy, k, 0.03), edge);
    switch (look.hair) {
      case MascotHair.tufts:
        return;
      case MascotHair.curly:
        // Small curls along the hairline.
        final curls = <(double, double, double)>[];
        for (var i = 0; i <= 6; i++) {
          final a = math.pi * (1.1 + i * 0.133);
          curls.add((
            hx + math.cos(a) * s(0.125),
            hy - s(0.04) + math.sin(a) * s(0.13),
            s(0.045),
          ));
        }
        _outlined(c, _blob(curls), _hair);
        if (!monochrome) {
          for (final (x, y, r) in curls) {
            c.drawArc(
              Rect.fromCircle(center: Offset(x, y), radius: r * 0.5),
              0.4,
              3.6,
              false,
              _line(_hairShade, s(0.01)),
            );
          }
        }
      case MascotHair.long:
        // Straight-cut bangs across the forehead.
        final edge = Path()
          ..moveTo(hx - s(0.25), hy + s(0.03))
          ..lineTo(hx - s(0.15), hy + s(0.03))
          ..lineTo(hx - s(0.15), hy - s(0.06));
        for (var i = 0; i < 5; i++) {
          final x0 = -0.15 + i * 0.06;
          edge.quadraticBezierTo(
            hx + s(x0 + 0.03),
            hy - s(0.04),
            hx + s(x0 + 0.06),
            hy - s(0.065),
          );
        }
        edge
          ..lineTo(hx + s(0.15), hy + s(0.03))
          ..lineTo(hx + s(0.25), hy + s(0.03))
          ..lineTo(hx + s(0.25), hy - s(0.3))
          ..lineTo(hx - s(0.25), hy - s(0.3))
          ..close();
        _outlined(c, cut(edge), _hair);
        if (!monochrome) {
          for (final x in [-0.07, 0.0, 0.07]) {
            c.drawLine(
              Offset(hx + s(x), hy - s(0.17)),
              Offset(hx + s(x * 1.1), hy - s(0.08)),
              _line(_hairShade, s(0.01)),
            );
          }
        }
      case MascotHair.bun:
        // Hair pulled back smooth, parted in the middle.
        final edge = Path()
          ..moveTo(hx - s(0.25), hy + s(0.0))
          ..lineTo(hx - s(0.15), hy + s(0.0))
          ..quadraticBezierTo(hx - s(0.1), hy - s(0.115), hx, hy - s(0.12))
          ..quadraticBezierTo(
            hx + s(0.1),
            hy - s(0.115),
            hx + s(0.15),
            hy + s(0.0),
          )
          ..lineTo(hx + s(0.25), hy + s(0.0))
          ..lineTo(hx + s(0.25), hy - s(0.3))
          ..lineTo(hx - s(0.25), hy - s(0.3))
          ..close();
        _outlined(c, cut(edge), _hair);
        if (!monochrome) {
          c.drawLine(
            Offset(hx, hy - s(0.12)),
            Offset(hx, hy - s(0.19)),
            _line(_hairShade, s(0.012)),
          );
          for (final side in [-1.0, 1.0]) {
            c.drawPath(
              Path()
                ..moveTo(hx + side * s(0.03), hy - s(0.12))
                ..quadraticBezierTo(
                  hx + side * s(0.1),
                  hy - s(0.13),
                  hx + side * s(0.13),
                  hy - s(0.05),
                ),
              _line(_hairShade, s(0.01)),
            );
          }
        }
    }
  }

  /// The look's beard, with a few strands on the bigger ones.
  void _beard(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    Path circles(List<(double, double, double)> list) =>
        _blob([for (final (x, y, r) in list) (hx + s(x), hy + s(y), s(r))]);
    const full = [
      (-0.115, 0.09, 0.06),
      (0.115, 0.09, 0.06),
      (-0.1, 0.16, 0.07),
      (0.1, 0.16, 0.07),
      (-0.05, 0.23, 0.07),
      (0.05, 0.23, 0.07),
      (0.0, 0.28, 0.06),
      (0.0, 0.13, 0.08),
    ];
    final List<(double, double)> strands;
    switch (look.shownBeard) {
      case MascotBeard.none:
        return;
      case MascotBeard.full:
        _outlined(c, circles(full), _hair);
        strands = const [(-0.06, 0.2), (0.04, 0.24), (0.0, 0.17)];
      case MascotBeard.short:
        // Trimmed close along the jaw, square at the chin.
        final jaw = Path()
          ..moveTo(p(-0.145, 0.0).dx, p(-0.145, 0.0).dy)
          ..lineTo(p(-0.115, 0.0).dx, p(-0.115, 0.0).dy)
          ..quadraticBezierTo(
            p(-0.1, 0.11).dx,
            p(-0.1, 0.11).dy,
            p(-0.04, 0.13).dx,
            p(-0.04, 0.13).dy,
          )
          ..lineTo(p(0.04, 0.13).dx, p(0.04, 0.13).dy)
          ..quadraticBezierTo(
            p(0.1, 0.11).dx,
            p(0.1, 0.11).dy,
            p(0.115, 0.0).dx,
            p(0.115, 0.0).dy,
          )
          ..lineTo(p(0.145, 0.0).dx, p(0.145, 0.0).dy)
          ..quadraticBezierTo(
            p(0.15, 0.17).dx,
            p(0.15, 0.17).dy,
            p(0.06, 0.2).dx,
            p(0.06, 0.2).dy,
          )
          ..lineTo(p(-0.06, 0.2).dx, p(-0.06, 0.2).dy)
          ..quadraticBezierTo(
            p(-0.15, 0.17).dx,
            p(-0.15, 0.17).dy,
            p(-0.145, 0.0).dx,
            p(-0.145, 0.0).dy,
          )
          ..close();
        _outlined(c, jaw, _hair);
        strands = const [];
      case MascotBeard.goatee:
        // A pointed tuft on the chin only.
        final tuft = Path()
          ..moveTo(p(-0.05, 0.15).dx, p(-0.05, 0.15).dy)
          ..quadraticBezierTo(
            p(0, 0.135).dx,
            p(0, 0.135).dy,
            p(0.05, 0.15).dx,
            p(0.05, 0.15).dy,
          )
          ..quadraticBezierTo(
            p(0.045, 0.24).dx,
            p(0.045, 0.24).dy,
            p(0.0, 0.31).dx,
            p(0.0, 0.31).dy,
          )
          ..quadraticBezierTo(
            p(-0.045, 0.24).dx,
            p(-0.045, 0.24).dy,
            p(-0.05, 0.15).dx,
            p(-0.05, 0.15).dy,
          )
          ..close();
        _outlined(c, tuft, _hair);
        strands = const [(0.0, 0.18)];
      case MascotBeard.long:
        // A wizard's beard tapering to a point far below.
        final taper = Path()
          ..moveTo(p(-0.15, 0.12).dx, p(-0.15, 0.12).dy)
          ..quadraticBezierTo(
            p(-0.12, 0.42).dx,
            p(-0.12, 0.42).dy,
            p(0.0, 0.66).dx,
            p(0.0, 0.66).dy,
          )
          ..quadraticBezierTo(
            p(0.12, 0.42).dx,
            p(0.12, 0.42).dy,
            p(0.15, 0.12).dx,
            p(0.15, 0.12).dy,
          )
          ..close();
        _outlined(
          c,
          Path.combine(PathOperation.union, circles(full), taper),
          _hair,
        );
        strands = const [
          (-0.06, 0.2),
          (0.04, 0.26),
          (0.0, 0.17),
          (-0.03, 0.34),
          (0.03, 0.42),
          (0.0, 0.5),
        ];
    }
    if (monochrome) return;
    for (final (x, y) in strands) {
      c.drawPath(
        Path()
          ..moveTo(hx + s(x), hy + s(y))
          ..quadraticBezierTo(
            hx + s(x + 0.015),
            hy + s(y + 0.03),
            hx + s(x),
            hy + s(y + 0.055),
          ),
        _line(_hairShade, s(0.012)),
      );
    }
  }

  void _moustache(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    void stroke(Path path, double width) {
      c.drawPath(path, _line(ink, s(width) + outline * 2));
      c.drawPath(path, _line(_hair, s(width))..blendMode = BlendMode.srcOver);
    }

    switch (look.shownMoustache) {
      case MascotMoustache.none:
        return;
      case MascotMoustache.classic:
        _outlined(
          c,
          Path()
            ..moveTo(p(0, 0.07).dx, p(0, 0.07).dy)
            ..cubicTo(
              p(-0.03, 0.05).dx,
              p(-0.03, 0.05).dy,
              p(-0.09, 0.06).dx,
              p(-0.09, 0.06).dy,
              p(-0.1, 0.1).dx,
              p(-0.1, 0.1).dy,
            )
            ..cubicTo(
              p(-0.07, 0.095).dx,
              p(-0.07, 0.095).dy,
              p(-0.03, 0.11).dx,
              p(-0.03, 0.11).dy,
              p(0, 0.09).dx,
              p(0, 0.09).dy,
            )
            ..cubicTo(
              p(0.03, 0.11).dx,
              p(0.03, 0.11).dy,
              p(0.07, 0.095).dx,
              p(0.07, 0.095).dy,
              p(0.1, 0.1).dx,
              p(0.1, 0.1).dy,
            )
            ..cubicTo(
              p(0.09, 0.06).dx,
              p(0.09, 0.06).dy,
              p(0.03, 0.05).dx,
              p(0.03, 0.05).dy,
              p(0, 0.07).dx,
              p(0, 0.07).dy,
            )
            ..close(),
          _hair,
        );
      case MascotMoustache.pencil:
        // A thin line just above the lip, a gap in the middle.
        for (final d in [-1.0, 1.0]) {
          stroke(
            Path()
              ..moveTo(p(d * 0.012, 0.082).dx, p(d * 0.012, 0.082).dy)
              ..quadraticBezierTo(
                p(d * 0.04, 0.072).dx,
                p(d * 0.04, 0.072).dy,
                p(d * 0.075, 0.088).dx,
                p(d * 0.075, 0.088).dy,
              ),
            0.012,
          );
        }
      case MascotMoustache.handlebar:
        // Out wide, the tips curled up into loops.
        for (final d in [-1.0, 1.0]) {
          final tip = p(d * 0.15, 0.05);
          stroke(
            Path()
              ..moveTo(p(0, 0.078).dx, p(0, 0.078).dy)
              ..quadraticBezierTo(
                p(d * 0.07, 0.055).dx,
                p(d * 0.07, 0.055).dy,
                p(d * 0.13, 0.09).dx,
                p(d * 0.13, 0.09).dy,
              )
              ..quadraticBezierTo(
                p(d * 0.19, 0.1).dx,
                p(d * 0.19, 0.1).dy,
                p(d * 0.185, 0.05).dx,
                p(d * 0.185, 0.05).dy,
              )
              ..quadraticBezierTo(
                p(d * 0.175, 0.02).dx,
                p(d * 0.175, 0.02).dy,
                tip.dx,
                tip.dy,
              ),
            0.026,
          );
        }
      case MascotMoustache.walrus:
        // Thick and drooping over the mouth, down past its corners.
        _outlined(
          c,
          _blob([
            for (final (x, y, r) in const [
              (0.0, 0.085, 0.05),
              (-0.055, 0.09, 0.05),
              (0.055, 0.09, 0.05),
              (-0.1, 0.12, 0.042),
              (0.1, 0.12, 0.042),
              (-0.11, 0.16, 0.034),
              (0.11, 0.16, 0.034),
            ])
              (hx + s(x), hy + s(y), s(r)),
          ]),
          _hair,
        );
        if (!monochrome) {
          for (final x in [-0.09, -0.05, -0.015, 0.015, 0.05, 0.09]) {
            c.drawLine(
              p(x, 0.1),
              p(x * 1.15, 0.14),
              _line(_hairShade, s(0.01)),
            );
          }
        }
    }
  }

  void _glasses(Canvas c, double hx, double hy, double k) {
    if (look.glasses == MascotGlasses.none) return;
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    final lens = Paint()..color = white.withValues(alpha: 0.3);
    void temples(double x, double y, Paint frame) {
      for (final side in [-1.0, 1.0]) {
        c.drawLine(p(side * x, y), p(side * 0.145, y - 0.012), frame);
      }
    }

    switch (look.glasses) {
      case MascotGlasses.none:
        return;
      case MascotGlasses.round:
        // Thin gold wire.
        final wire = _line(const Color(0xFFB8871A), s(0.009));
        for (final side in [-1.0, 1.0]) {
          final at = p(side * 0.062, -0.005);
          c.drawCircle(at, s(0.04), lens);
          c.drawCircle(at, s(0.04), wire);
        }
        c.drawPath(
          Path()
            ..moveTo(p(-0.022, -0.01).dx, p(-0.022, -0.01).dy)
            ..quadraticBezierTo(
              p(0, -0.03).dx,
              p(0, -0.03).dy,
              p(0.022, -0.01).dx,
              p(0.022, -0.01).dy,
            ),
          wire,
        );
        temples(0.102, -0.01, wire);
      case MascotGlasses.square:
        // Thick black frames, wider than the eyes.
        final frame = _line(ink, s(0.024));
        for (final side in [-1.0, 1.0]) {
          final r = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p(side * 0.068, -0.008),
              width: s(0.106),
              height: s(0.078),
            ),
            Radius.circular(s(0.014)),
          );
          c.drawRRect(r, lens);
          c.drawRRect(r, frame);
        }
        c.drawLine(p(-0.016, -0.02), p(0.016, -0.02), frame);
        temples(0.12, -0.025, frame);
      case MascotGlasses.halfMoon:
        // Reading glasses low on the nose, on a cord round the neck.
        final frame = _line(ink, s(0.012));
        for (final side in [-1.0, 1.0]) {
          final half = Path()
            ..addArc(
              Rect.fromCircle(center: p(side * 0.062, 0.012), radius: s(0.04)),
              0,
              math.pi,
            )
            ..close();
          c.drawPath(half, lens);
          c.drawPath(half, frame);
          final cord = Path()
            ..moveTo(p(side * 0.102, 0.012).dx, p(side * 0.102, 0.012).dy)
            ..quadraticBezierTo(
              p(side * 0.2, 0.2).dx,
              p(side * 0.2, 0.2).dy,
              p(side * 0.1, 0.33).dx,
              p(side * 0.1, 0.33).dy,
            );
          c.drawPath(cord, _line(const Color(0xFFB0362F), s(0.009)));
        }
        c.drawLine(p(-0.022, 0.012), p(0.022, 0.012), frame);
      case MascotGlasses.sunglasses:
        // Aviators: teardrop lenses in a thin gold frame.
        final frame = _line(gold, s(0.01));
        for (final side in [-1.0, 1.0]) {
          final cx = side * 0.068;
          final drop = Path()
            ..moveTo(p(cx - 0.05, -0.03).dx, p(cx - 0.05, -0.03).dy)
            ..lineTo(p(cx + 0.05, -0.03).dx, p(cx + 0.05, -0.03).dy)
            ..quadraticBezierTo(
              p(cx + 0.058, 0.04).dx,
              p(cx + 0.058, 0.04).dy,
              p(cx + side * 0.01, 0.045).dx,
              p(cx + side * 0.01, 0.045).dy,
            )
            ..quadraticBezierTo(
              p(cx - 0.058, 0.04).dx,
              p(cx - 0.058, 0.04).dy,
              p(cx - 0.05, -0.03).dx,
              p(cx - 0.05, -0.03).dy,
            )
            ..close();
          c.drawPath(drop, _fill(const Color(0xFF243447)));
          c.drawPath(drop, frame);
          if (!monochrome) {
            c.drawLine(
              p(cx - 0.03, -0.012),
              p(cx - 0.005, -0.022),
              _line(white.withValues(alpha: 0.55), s(0.012)),
            );
          }
        }
        c.drawLine(p(-0.018, -0.028), p(0.018, -0.028), frame);
        temples(0.118, -0.025, frame);
      case MascotGlasses.monocle:
        final at = p(0.062, -0.005);
        c.drawCircle(at, s(0.046), lens);
        c.drawCircle(at, s(0.046), _line(ink, s(0.022)));
        c.drawCircle(at, s(0.046), _line(gold, s(0.012)));
        c.drawPath(
          Path()
            ..moveTo(p(0.098, 0.025).dx, p(0.098, 0.025).dy)
            ..quadraticBezierTo(
              p(0.18, 0.1).dx,
              p(0.18, 0.1).dy,
              p(0.15, 0.26).dx,
              p(0.15, 0.26).dy,
            ),
          _line(gold, s(0.009)),
        );
    }
  }

  void _hat(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    switch (look.hat) {
      case MascotHat.none:
        return;
      case MascotHat.fez:
        const red = Color(0xFFC8302E);
        const redShade = Color(0xFF9E2220);
        final fez = Path()
          ..moveTo(p(-0.108, -0.13).dx, p(-0.108, -0.13).dy)
          ..lineTo(p(-0.078, -0.3).dx, p(-0.078, -0.3).dy)
          ..quadraticBezierTo(
            p(0, -0.315).dx,
            p(0, -0.315).dy,
            p(0.078, -0.3).dx,
            p(0.078, -0.3).dy,
          )
          ..lineTo(p(0.108, -0.13).dx, p(0.108, -0.13).dy)
          ..quadraticBezierTo(
            p(0, -0.11).dx,
            p(0, -0.11).dy,
            p(-0.108, -0.13).dx,
            p(-0.108, -0.13).dy,
          )
          ..close();
        _outlined(c, fez, red);
        if (!monochrome) {
          c.drawLine(
            p(-0.103, -0.155),
            p(0.103, -0.155),
            _line(redShade, s(0.016)),
          );
        }
        // The tassel hangs from the top.
        c.drawPath(
          Path()
            ..moveTo(p(0, -0.305).dx, p(0, -0.305).dy)
            ..quadraticBezierTo(
              p(0.08, -0.31).dx,
              p(0.08, -0.31).dy,
              p(0.1, -0.22).dx,
              p(0.1, -0.22).dy,
            ),
          _line(ink, s(0.014)),
        );
        _outlined(
          c,
          Path()
            ..moveTo(p(0.1, -0.23).dx, p(0.1, -0.23).dy)
            ..lineTo(p(0.12, -0.17).dx, p(0.12, -0.17).dy)
            ..lineTo(p(0.08, -0.17).dx, p(0.08, -0.17).dy)
            ..close(),
          const Color(0xFF2B2B33),
        );
      case MascotHat.mortarboard:
        const navy = Color(0xFF2B3350);
        const gold = Color(0xFFFFC53D);
        final band = Path()
          ..moveTo(p(-0.12, -0.2).dx, p(-0.12, -0.2).dy)
          ..lineTo(p(0.12, -0.2).dx, p(0.12, -0.2).dy)
          ..lineTo(p(0.12, -0.13).dx, p(0.12, -0.13).dy)
          ..quadraticBezierTo(
            p(0, -0.1).dx,
            p(0, -0.1).dy,
            p(-0.12, -0.13).dx,
            p(-0.12, -0.13).dy,
          )
          ..close();
        _outlined(c, band, navy);
        final board = Path()
          ..moveTo(p(-0.23, -0.215).dx, p(-0.23, -0.215).dy)
          ..lineTo(p(0, -0.275).dx, p(0, -0.275).dy)
          ..lineTo(p(0.23, -0.215).dx, p(0.23, -0.215).dy)
          ..lineTo(p(0, -0.16).dx, p(0, -0.16).dy)
          ..close();
        _outlined(c, board, navy);
        c.drawPath(
          Path()
            ..moveTo(p(0, -0.218).dx, p(0, -0.218).dy)
            ..lineTo(p(0.17, -0.2).dx, p(0.17, -0.2).dy)
            ..lineTo(p(0.175, -0.1).dx, p(0.175, -0.1).dy),
          _line(gold, s(0.012))..blendMode = BlendMode.srcOver,
        );
        c.drawCircle(p(0, -0.218), s(0.016), _fill(gold));
        _outlined(
          c,
          Path()
            ..moveTo(p(0.175, -0.11).dx, p(0.175, -0.11).dy)
            ..lineTo(p(0.195, -0.055).dx, p(0.195, -0.055).dy)
            ..lineTo(p(0.155, -0.055).dx, p(0.155, -0.055).dy)
            ..close(),
          gold,
        );
      case MascotHat.beret:
        const wine = Color(0xFF7A2E3A);
        const wineShade = Color(0xFF5C1F2A);
        c.save();
        c.translate(p(0.03, -0.175).dx, p(0.03, -0.175).dy);
        c.rotate(-0.18);
        final beret = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: s(0.36),
              height: s(0.13),
            ),
          );
        _outlined(
          c,
          Path()..addOval(
            Rect.fromCircle(center: Offset(0, -s(0.075)), radius: s(0.014)),
          ),
          wine,
        );
        _outlined(c, beret, wine);
        if (!monochrome) {
          c.drawArc(
            Rect.fromCenter(
              center: Offset(0, s(0.01)),
              width: s(0.3),
              height: s(0.08),
            ),
            0.3,
            2.5,
            false,
            _line(wineShade, s(0.012)),
          );
        }
        c.restore();
    }
  }

  /// Arms in skin, outlined as one shape; drawn before the toga, which
  /// hides the shoulders. Points are relative to the head centre [h], in units of
  /// [k].
  void _arms(Canvas c, Offset h, double k, DayMood mood) {
    double s(double v) => v * k;
    Offset p(double x, double y) => h + Offset(s(x), s(y));
    const arm = 0.075;
    // Strokes (points, width) and round parts (centre, radius): fists,
    // the biceps.
    final strokes = <(List<Offset>, double)>[];
    final blobs = <(Offset, double)>[];
    switch (mood) {
      case DayMood.legend: // both arms flexing
        for (final d in [-1.0, 1.0]) {
          strokes.add((
            [p(d * 0.25, 0.42), p(d * 0.47, 0.36), p(d * 0.45, 0.13)],
            arm,
          ));
          blobs.add((p(d * 0.36, 0.345), s(0.058)));
          blobs.add((p(d * 0.45, 0.11), s(0.055)));
        }
      case DayMood.great: // a raised victory fist
        strokes.add(([p(0.22, 0.42), p(0.45, 0.4), p(0.43, 0.2)], arm));
        blobs.add((p(0.43, 0.15), s(0.062)));
      case DayMood.proud: // hands on the hips
        for (final d in [-1.0, 1.0]) {
          strokes.add((
            [p(d * 0.26, 0.4), p(d * 0.52, 0.5), p(d * 0.36, 0.64)],
            arm,
          ));
          blobs.add((p(d * 0.36, 0.665), s(0.05)));
        }
      case DayMood.unsure: // scratching his head
        strokes.add(([p(0.22, 0.42), p(0.42, 0.3), p(0.2, -0.1)], arm));
      case DayMood.down:
        return; // arms hang out of sight
    }
    // All outlines first, then all fills: the parts merge into one shape.
    for (final (pts, w) in strokes) {
      c.drawPath(_polyline(pts), _line(ink, s(w) + outline * 2));
    }
    for (final (at, r) in blobs) {
      c.drawCircle(at, r + outline, _fill(ink));
    }
    for (final (pts, w) in strokes) {
      c.drawPath(
        _polyline(pts),
        _line(_skin, s(w))..blendMode = BlendMode.srcOver,
      );
    }
    for (final (at, r) in blobs) {
      c.drawCircle(at, r, _fill(_skin));
    }
    if (!monochrome) {
      final fists = switch (mood) {
        DayMood.legend => [p(-0.45, 0.11), p(0.45, 0.11)],
        DayMood.great => [p(0.43, 0.15)],
        _ => const <Offset>[],
      };
      for (final f in fists) {
        for (final dy in [-0.022, 0.0, 0.022]) {
          c.drawLine(
            f + Offset(-s(0.03), s(dy)),
            f + Offset(s(0.012), s(dy)),
            _line(_skinShade, s(0.011)),
          );
        }
      }
    }
  }

  static Path _polyline(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    return path;
  }

  void _cheeks(Canvas c, double hx, double hy, double k, DayMood mood) {
    if (monochrome || mood == DayMood.down || mood == DayMood.unsure) return;
    for (final side in [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(hx + side * k * 0.088, hy + k * 0.035),
          width: k * 0.06,
          height: k * 0.036,
        ),
        Paint()..color = blush.withValues(alpha: 0.75),
      );
    }
  }

  /// Under the moustache, which is drawn over its top edge.
  void _mouth(Canvas c, double hx, double hy, double k, DayMood mood) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    Path curve(List<(double, double)> pts) {
      final path = Path()
        ..moveTo(p(pts[0].$1, pts[0].$2).dx, p(pts[0].$1, pts[0].$2).dy);
      for (var i = 1; i + 1 < pts.length; i += 2) {
        final ctrl = p(pts[i].$1, pts[i].$2);
        final end = p(pts[i + 1].$1, pts[i + 1].$2);
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      }
      return path;
    }

    switch (mood) {
      case DayMood.legend || DayMood.great:
        final half = mood == DayMood.legend ? 0.075 : 0.058;
        final depth = mood == DayMood.legend ? 0.215 : 0.17;
        final a = p(-half, 0.095), b = p(half, 0.095);
        final open = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, p(0, depth).dy, b.dx, p(0, depth).dy, b.dx, b.dy)
          ..close();
        _outlined(c, open, mouth);
        if (look.isWoman) c.drawPath(open, _line(lips, s(0.016)));
        if (!monochrome) {
          c.save();
          c.clipPath(open);
          c.drawOval(
            Rect.fromCenter(
              center: p(0, depth - 0.03),
              width: s(half * 1.3),
              height: s(0.07),
            ),
            Paint()..color = tongue,
          );
          c.restore();
        }
      case DayMood.proud: // a sly smile, higher on one side
        c.drawPath(
          curve([(-0.04, 0.125), (0.01, 0.15), (0.06, 0.112)]),
          _mouthLine(k),
        );
      case DayMood.unsure: // wavy
        c.drawPath(
          curve([
            (-0.045, 0.135),
            (-0.022, 0.115),
            (0, 0.135),
            (0.022, 0.155),
            (0.045, 0.135),
          ]),
          _mouthLine(k),
        );
      case DayMood.down: // frown
        c.drawPath(
          curve([(-0.045, 0.15), (0, 0.112), (0.045, 0.15)]),
          _mouthLine(k),
        );
    }
  }

  void _eyes(Canvas c, double hx, double hy, double k, DayMood mood) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    final eye = _line(ink, s(0.016));
    void brow(Offset a, Offset b, [double lift = 0]) => c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2,
          (a.dy + b.dy) / 2 - s(lift),
          b.dx,
          b.dy,
        ),
      _brow(k),
    );
    for (final side in [-1.0, 1.0]) {
      final centre = p(side * 0.062, -0.005);
      switch (mood) {
        case DayMood.legend || DayMood.great: // happy, squeezed shut
          c.drawPath(
            Path()..addArc(
              Rect.fromCenter(
                center: centre + Offset(0, s(0.012)),
                width: s(0.06),
                height: s(0.05),
              ),
              math.pi + 0.3,
              math.pi - 0.6,
            ),
            eye,
          );
          brow(p(side * 0.035, -0.075), p(side * 0.095, -0.085), 0.02);
        case DayMood.proud: // eyes closed, pleased with himself
          c.drawPath(
            Path()..addArc(
              Rect.fromCenter(center: centre, width: s(0.06), height: s(0.04)),
              0.2,
              math.pi - 0.4,
            ),
            eye,
          );
          brow(p(side * 0.032, -0.068), p(side * 0.098, -0.078), 0.018);
        case DayMood.unsure: // open eyes, one brow up
          _openEye(c, centre, k, 0.02, side);
          if (side < 0) {
            brow(p(-0.095, -0.055), p(-0.035, -0.052));
          } else {
            brow(p(0.032, -0.075), p(0.098, -0.085), 0.025);
          }
        case DayMood.down: // tired, sad brows
          c.drawPath(
            Path()..addArc(
              Rect.fromCenter(
                center: centre + Offset(0, s(0.006)),
                width: s(0.052),
                height: s(0.03),
              ),
              0.25,
              math.pi - 0.5,
            ),
            eye,
          );
          brow(p(side * 0.098, -0.04), p(side * 0.035, -0.07));
      }
    }
  }

  /// Arms for the duel's end (new poses, not the share card's).
  void _duelArms(Canvas c, Offset h, double k, DuelPose pose) {
    double s(double v) => v * k;
    Offset p(double x, double y) => h + Offset(s(x), s(y));
    const arm = 0.075;
    final strokes = <(List<Offset>, double)>[];
    final blobs = <(Offset, double)>[];
    switch (pose) {
      case DuelPose.champion:
        // Right arm: a flexed biceps. Left arm: a trophy held up high; the
        // hand grips its stem, so the cup is drawn first.
        _trophy(c, p(-0.43, -0.07), k);
        strokes.add(([p(0.24, 0.42), p(0.5, 0.38), p(0.48, 0.14)], arm));
        blobs.add((p(0.39, 0.32), s(0.068)));
        blobs.add((p(0.48, 0.11), s(0.056)));
        strokes.add(([p(-0.24, 0.42), p(-0.4, 0.16), p(-0.43, -0.05)], arm));
        blobs.add((p(-0.43, -0.07), s(0.05)));
      case DuelPose.defeated:
        // A white flag; its pole goes behind the hand that holds it.
        c.drawLine(p(0.42, 0.68), p(0.47, 0.06), _line(ink, s(0.03)));
        c.drawLine(p(0.42, 0.68), p(0.47, 0.06), _line(flagPole, s(0.016)));
        Offset q(double x, double y) => p(x, y);
        final cloth = Path()
          ..moveTo(q(0.47, 0.07).dx, q(0.47, 0.07).dy)
          ..quadraticBezierTo(
            q(0.57, 0.03).dx,
            q(0.57, 0.03).dy,
            q(0.67, 0.12).dx,
            q(0.67, 0.12).dy,
          )
          ..quadraticBezierTo(
            q(0.67, 0.2).dx,
            q(0.67, 0.2).dy,
            q(0.63, 0.27).dx,
            q(0.63, 0.27).dy,
          )
          ..quadraticBezierTo(
            q(0.55, 0.19).dx,
            q(0.55, 0.19).dy,
            q(0.46, 0.24).dx,
            q(0.46, 0.24).dy,
          )
          ..close();
        _outlined(c, cloth, white);
        strokes.add(([p(0.2, 0.45), p(0.35, 0.6), p(0.44, 0.5)], arm));
        blobs.add((p(0.445, 0.48), s(0.048)));
      case DuelPose.even:
        // A shrug: both palms up.
        for (final d in [-1.0, 1.0]) {
          strokes.add((
            [p(d * 0.24, 0.42), p(d * 0.42, 0.5), p(d * 0.56, 0.37)],
            arm,
          ));
          blobs.add((p(d * 0.58, 0.34), s(0.052)));
        }
    }
    for (final (pts, w) in strokes) {
      c.drawPath(_polyline(pts), _line(ink, s(w) + outline * 2));
    }
    for (final (at, r) in blobs) {
      c.drawCircle(at, r + outline, _fill(ink));
    }
    for (final (pts, w) in strokes) {
      c.drawPath(
        _polyline(pts),
        _line(_skin, s(w))..blendMode = BlendMode.srcOver,
      );
    }
    for (final (at, r) in blobs) {
      c.drawCircle(at, r, _fill(_skin));
    }
    if (!monochrome && pose == DuelPose.champion) {
      // The biceps' curve and the fist's knuckles.
      c.drawArc(
        Rect.fromCircle(center: p(0.39, 0.34), radius: s(0.04)),
        3.6,
        1.6,
        false,
        _line(_skinShade, s(0.011)),
      );
      final fist = p(0.48, 0.11);
      for (final dy in [-0.02, 0.0, 0.02]) {
        c.drawLine(
          fist + Offset(-s(0.028), s(dy)),
          fist + Offset(s(0.012), s(dy)),
          _line(_skinShade, s(0.011)),
        );
      }
    }
  }

  /// A gold cup whose stem is held at [grip].
  void _trophy(Canvas c, Offset grip, double k) {
    double s(double v) => v * k;
    Offset q(double x, double y) => grip + Offset(s(x), s(y));
    const gold = Color(0xFFFFC53D);
    const goldShade = Color(0xFFE09A1A);
    // The stem, held in the fist.
    _outlined(
      c,
      Path()..addRect(
        Rect.fromLTRB(
          q(-0.022, 0).dx,
          q(0, -0.12).dy,
          q(0.022, 0).dx,
          q(0, 0.05).dy,
        ),
      ),
      gold,
    );
    // Handles on both sides of the cup.
    for (final side in [-1.0, 1.0]) {
      final handle = Path()
        ..addArc(
          Rect.fromCenter(
            center: q(side * 0.085, -0.2),
            width: s(0.08),
            height: s(0.08),
          ),
          side < 0 ? math.pi * 0.5 : -math.pi * 0.5,
          math.pi,
        );
      c.drawPath(handle, _line(ink, s(0.026) + outline * 2));
      c.drawPath(handle, _line(gold, s(0.026)));
    }
    // The cup: wide rim, round bottom.
    final cup = Path()
      ..moveTo(q(-0.1, -0.27).dx, q(-0.1, -0.27).dy)
      ..lineTo(q(0.1, -0.27).dx, q(0.1, -0.27).dy)
      ..cubicTo(
        q(0.1, -0.16).dx,
        q(0.1, -0.16).dy,
        q(0.05, -0.11).dx,
        q(0.05, -0.11).dy,
        q(0, -0.11).dx,
        q(0, -0.11).dy,
      )
      ..cubicTo(
        q(-0.05, -0.11).dx,
        q(-0.05, -0.11).dy,
        q(-0.1, -0.16).dx,
        q(-0.1, -0.16).dy,
        q(-0.1, -0.27).dx,
        q(-0.1, -0.27).dy,
      )
      ..close();
    _outlined(c, cup, gold);
    if (!monochrome) {
      c.drawLine(
        q(-0.055, -0.245),
        q(-0.045, -0.165),
        _line(white.withValues(alpha: 0.7), s(0.016)),
      );
      // A star on the cup.
      c.drawCircle(q(0.02, -0.2), s(0.018), _fill(goldShade));
    }
  }

  void _duelMouth(Canvas c, double hx, double hy, double k, DuelPose pose) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    Path wave(List<(double, double)> pts) {
      final path = Path()
        ..moveTo(p(pts[0].$1, pts[0].$2).dx, p(pts[0].$1, pts[0].$2).dy);
      for (var i = 1; i + 1 < pts.length; i += 2) {
        final ctrl = p(pts[i].$1, pts[i].$2);
        final end = p(pts[i + 1].$1, pts[i + 1].$2);
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      }
      return path;
    }

    switch (pose) {
      case DuelPose.champion:
        // A wide grin showing the top teeth.
        final a = p(-0.08, 0.095), b = p(0.08, 0.095);
        final open = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, p(0, 0.2).dy, b.dx, p(0, 0.2).dy, b.dx, b.dy)
          ..close();
        _outlined(c, open, mouth);
        if (look.isWoman) c.drawPath(open, _line(lips, s(0.016)));
        if (!monochrome) {
          c.save();
          c.clipPath(open);
          c.drawRect(
            Rect.fromLTRB(a.dx, a.dy, b.dx, p(0, 0.128).dy),
            Paint()..color = white,
          );
          c.restore();
        }
      case DuelPose.defeated:
        // A trembling frown.
        c.drawPath(
          wave([
            (-0.05, 0.155),
            (-0.03, 0.118),
            (-0.01, 0.13),
            (0.01, 0.114),
            (0.03, 0.126),
            (0.05, 0.13),
            (0.055, 0.155),
          ]),
          _mouthLine(k),
        );
      case DuelPose.even:
        // Flat, a little crooked.
        c.drawLine(p(-0.04, 0.138), p(0.045, 0.13), _mouthLine(k));
    }
  }

  void _duelEyes(Canvas c, double hx, double hy, double k, DuelPose pose) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    final eye = _line(ink, s(0.016));
    void openEye(Offset at, double r) =>
        _openEye(c, at, k, r, at.dx < hx ? -1 : 1);

    void brow(Offset a, Offset b, double lift) => c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2,
          (a.dy + b.dy) / 2 - s(lift),
          b.dx,
          b.dy,
        ),
      _brow(k),
    );
    switch (pose) {
      case DuelPose.champion:
        // A wink: left eye shut, right eye open and bright.
        c.drawPath(
          Path()..addArc(
            Rect.fromCenter(
              center: p(-0.062, 0.007),
              width: s(0.06),
              height: s(0.05),
            ),
            math.pi + 0.3,
            math.pi - 0.6,
          ),
          eye,
        );
        openEye(p(0.062, -0.005), 0.022);
        brow(p(-0.095, -0.07), p(-0.035, -0.075), 0.015);
        brow(p(0.032, -0.085), p(0.098, -0.09), 0.03);
      case DuelPose.defeated:
        // Wet eyes, sad brows and tears running into the beard.
        for (final side in [-1.0, 1.0]) {
          openEye(p(side * 0.062, 0.0), 0.019);
          brow(p(side * 0.1, -0.035), p(side * 0.035, -0.07), -0.005);
          if (!monochrome) {
            final tear = Path()
              ..moveTo(p(side * 0.07, 0.025).dx, p(side * 0.07, 0.025).dy)
              ..quadraticBezierTo(
                p(side * 0.088, 0.06).dx,
                p(side * 0.088, 0.06).dy,
                p(side * 0.08, 0.1).dx,
                p(side * 0.08, 0.1).dy,
              );
            c.drawPath(tear, _line(drop, s(0.02)));
          }
        }
      case DuelPose.even:
        for (final side in [-1.0, 1.0]) {
          openEye(p(side * 0.062, -0.005), 0.02);
          brow(p(side * 0.035, -0.08), p(side * 0.098, -0.075), 0.02);
        }
    }
  }

  /// A laurel wreath around the top of the head, open at the crown.
  void _laurel(Canvas c, double hx, double hy, double k) {
    double s(double v) => v * k;
    final centre = Offset(hx, hy - s(0.02));
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 5; i++) {
        // Angle from straight up, towards the temples.
        final a = 0.25 + i * 0.3;
        final at =
            centre +
            Offset(side * math.sin(a) * s(0.16), -math.cos(a) * s(0.178));
        c.save();
        c.translate(at.dx, at.dy);
        c.rotate(side * (a + 0.9));
        final leaf = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: s(0.042),
              height: s(0.085),
            ),
          );
        _outlined(c, leaf, laurel);
        if (!monochrome) {
          c.drawLine(
            Offset(0, -s(0.03)),
            Offset(0, s(0.03)),
            _line(laurelShade, s(0.008)),
          );
        }
        c.restore();
      }
    }
  }

  /// A drop of sweat with its round bottom at [at], [size] tall.
  void _sweat(Canvas c, Offset at, double size) {
    final r = size * 0.38;
    _outlined(
      c,
      Path()
        ..moveTo(at.dx, at.dy - size)
        ..quadraticBezierTo(at.dx + r * 1.4, at.dy - r * 0.2, at.dx, at.dy + r)
        ..quadraticBezierTo(
          at.dx - r * 1.4,
          at.dy - r * 0.2,
          at.dx,
          at.dy - size,
        ),
      drop,
    );
  }

  /// A small grey cloud centred at [at] with a few drops falling.
  void _rainCloud(Canvas c, Offset at, double k) {
    double s(double v) => v * k;
    for (final (dx, dy) in [(-0.07, 0.08), (0.0, 0.11), (0.07, 0.08)]) {
      c.drawLine(
        at + Offset(s(dx), s(dy)),
        at + Offset(s(dx - 0.012), s(dy + 0.045)),
        _line(drop, s(0.016)),
      );
    }
    _outlined(
      c,
      _blob([
        (at.dx - s(0.09), at.dy + s(0.02), s(0.055)),
        (at.dx - s(0.03), at.dy - s(0.03), s(0.07)),
        (at.dx + s(0.05), at.dy - s(0.015), s(0.06)),
        (at.dx + s(0.1), at.dy + s(0.025), s(0.045)),
        (at.dx, at.dy + s(0.03), s(0.06)),
      ]),
      cloud,
    );
  }
}
