import 'dart:math' as math;
import 'dart:ui';

import '../core/day_mood.dart';

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
class Philosopher {
  const Philosopher({this.monochrome = false});

  final bool monochrome;

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
  /// eyes. [sash] draws a band across the toga in a player's colour.
  void paintPhilosopher(
    Canvas c,
    Offset h,
    double k, {
    double bottom = 1.3,
    DayMood? mood,
    DuelPose? pose,
    Color? sash,
  }) {
    assert(mood == null || pose == null, 'a mood or a pose, not both');
    double s(double v) => v * k;
    final hx = h.dx;

    // Toga and shoulders, with a drape line. Proud puffs the chest out;
    // down slumps the shoulders and drops the head.
    final (shoulder, waist, top) = switch ((mood, pose)) {
      (DayMood.proud, _) || (_, DuelPose.champion) => (0.30, 0.44, 0.25),
      (DayMood.down, _) || (_, DuelPose.defeated) => (0.18, 0.31, 0.31),
      _ => (0.2, 0.36, 0.27),
    };
    final bodyY = h.dy;
    // Arms come out from behind the toga (the head-scratching hand is drawn
    // again over the head below).
    if (mood != null) _arms(c, h, k, mood);
    if (pose != null) _duelArms(c, h, k, pose);
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
    _outlined(c, togaPath, toga);
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
        _line(togaShade, s(0.022)),
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
            _line(togaShade, s(0.016)),
          );
        }
      }
    }

    final hy =
        h.dy +
        (mood == DayMood.down
            ? s(0.035)
            : pose == DuelPose.defeated
            ? s(0.05)
            : 0);

    // Ears and the white tufts above them.
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
        skin,
      );
    }
    for (final side in [-1.0, 1.0]) {
      _outlined(
        c,
        _blob([
          (hx + side * s(0.16), hy - s(0.045), s(0.05)),
          (hx + side * s(0.175), hy, s(0.045)),
          (hx + side * s(0.145), hy - s(0.08), s(0.04)),
        ]),
        beard,
      );
    }

    // Head, its shine and a thinking wrinkle.
    _outlined(
      c,
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(hx, hy - s(0.02)),
          width: s(0.29),
          height: s(0.33),
        ),
      ),
      skin,
    );
    if (mood != null) _cheeks(c, hx, hy, k, mood);
    if (pose == DuelPose.champion) _cheeks(c, hx, hy, k, DayMood.great);
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
      c.drawPath(
        Path()
          ..moveTo(hx - s(0.05), hy - s(0.105))
          ..quadraticBezierTo(hx, hy - s(0.125), hx + s(0.05), hy - s(0.105)),
        _line(skinShade, s(0.012)),
      );
    }

    // Beard with a few strands.
    _outlined(
      c,
      _blob([
        (hx - s(0.115), hy + s(0.09), s(0.06)),
        (hx + s(0.115), hy + s(0.09), s(0.06)),
        (hx - s(0.1), hy + s(0.16), s(0.07)),
        (hx + s(0.1), hy + s(0.16), s(0.07)),
        (hx - s(0.05), hy + s(0.23), s(0.07)),
        (hx + s(0.05), hy + s(0.23), s(0.07)),
        (hx, hy + s(0.28), s(0.06)),
        (hx, hy + s(0.13), s(0.08)),
      ]),
      beard,
    );
    if (!monochrome) {
      for (final (x, y) in [(-0.06, 0.2), (0.04, 0.24), (0.0, 0.17)]) {
        c.drawPath(
          Path()
            ..moveTo(hx + s(x), hy + s(y))
            ..quadraticBezierTo(
              hx + s(x + 0.015),
              hy + s(y + 0.03),
              hx + s(x),
              hy + s(y + 0.055),
            ),
          _line(beardShade, s(0.012)),
        );
      }
    }

    if (mood != null) _mouth(c, hx, hy, k, mood);
    if (pose != null) _duelMouth(c, hx, hy, k, pose);

    // Moustache, then the nose on top of it.
    _outlined(
      c,
      Path()
        ..moveTo(hx, hy + s(0.07))
        ..cubicTo(
          hx - s(0.03),
          hy + s(0.05),
          hx - s(0.09),
          hy + s(0.06),
          hx - s(0.1),
          hy + s(0.1),
        )
        ..cubicTo(
          hx - s(0.07),
          hy + s(0.095),
          hx - s(0.03),
          hy + s(0.11),
          hx,
          hy + s(0.09),
        )
        ..cubicTo(
          hx + s(0.03),
          hy + s(0.11),
          hx + s(0.07),
          hy + s(0.095),
          hx + s(0.1),
          hy + s(0.1),
        )
        ..cubicTo(
          hx + s(0.09),
          hy + s(0.06),
          hx + s(0.03),
          hy + s(0.05),
          hx,
          hy + s(0.07),
        )
        ..close(),
      beard,
    );
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
      skin,
    );

    if (mood != null) {
      _eyes(c, hx, hy, k, mood);
      if (mood == DayMood.unsure) {
        // The hand on top of his head.
        final hand = Offset(hx + s(0.17), hy - s(0.13));
        c.drawCircle(hand, s(0.055) + outline, _fill(ink));
        c.drawCircle(hand, s(0.055), _fill(skin));
        for (final dx in [-0.02, 0.012]) {
          c.drawLine(
            hand + Offset(s(dx), s(0.01)),
            hand + Offset(s(dx + 0.012), s(0.045)),
            _line(skinShade, s(0.01)),
          );
        }
        _sweat(c, Offset(hx - s(0.13), hy - s(0.1)), s(0.05));
      }
      if (mood == DayMood.down) _rainCloud(c, Offset(hx, hy - s(0.33)), k);
      return;
    }
    if (pose != null) {
      _duelEyes(c, hx, hy, k, pose);
      if (pose == DuelPose.champion) _laurel(c, hx, hy, k);
      return;
    }

    // Closed eyes; the right brow raised in thought.
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
    }
    c.drawLine(
      Offset(hx - s(0.095), hy - s(0.06)),
      Offset(hx - s(0.035), hy - s(0.055)),
      eye,
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
      eye,
    );
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
        _line(skin, s(w))..blendMode = BlendMode.srcOver,
      );
    }
    for (final (at, r) in blobs) {
      c.drawCircle(at, r, _fill(skin));
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
            _line(skinShade, s(0.011)),
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
          _line(ink, s(0.016)),
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
          _line(ink, s(0.015)),
        );
      case DayMood.down: // frown
        c.drawPath(
          curve([(-0.045, 0.15), (0, 0.112), (0.045, 0.15)]),
          _line(ink, s(0.016)),
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
      eye,
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
          c.drawCircle(centre, s(0.02), _fill(ink));
          if (!monochrome) {
            c.drawCircle(
              centre + Offset(-s(0.006), -s(0.007)),
              s(0.006),
              _fill(white),
            );
          }
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
        _line(skin, s(w))..blendMode = BlendMode.srcOver,
      );
    }
    for (final (at, r) in blobs) {
      c.drawCircle(at, r, _fill(skin));
    }
    if (!monochrome && pose == DuelPose.champion) {
      // The biceps' curve and the fist's knuckles.
      c.drawArc(
        Rect.fromCircle(center: p(0.39, 0.34), radius: s(0.04)),
        3.6,
        1.6,
        false,
        _line(skinShade, s(0.011)),
      );
      final fist = p(0.48, 0.11);
      for (final dy in [-0.02, 0.0, 0.02]) {
        c.drawLine(
          fist + Offset(-s(0.028), s(dy)),
          fist + Offset(s(0.012), s(dy)),
          _line(skinShade, s(0.011)),
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
          _line(ink, s(0.016)),
        );
      case DuelPose.even:
        // Flat, a little crooked.
        c.drawLine(p(-0.04, 0.138), p(0.045, 0.13), _line(ink, s(0.016)));
    }
  }

  void _duelEyes(Canvas c, double hx, double hy, double k, DuelPose pose) {
    double s(double v) => v * k;
    Offset p(double x, double y) => Offset(hx + s(x), hy + s(y));
    final eye = _line(ink, s(0.016));
    void openEye(Offset at, double r) {
      c.drawCircle(at, s(r), _fill(ink));
      if (!monochrome) {
        c.drawCircle(
          at + Offset(-s(r * 0.3), -s(r * 0.35)),
          s(r * 0.32),
          _fill(white),
        );
      }
    }

    void brow(Offset a, Offset b, double lift) => c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2,
          (a.dy + b.dy) / 2 - s(lift),
          b.dx,
          b.dy,
        ),
      eye,
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
