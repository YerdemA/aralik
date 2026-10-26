import 'dart:ui';

/// The Kabaca mascot: a thinking philosopher (bald, white beard, eyes
/// closed, one brow raised) in a terracotta toga, with a thought bubble
/// holding a question mark. Drawn with plain canvas calls so the app icon
/// (tools/icon/render_icon_test.dart) and the share card are the same.
///
/// Coordinates are in "design units": the icon's visible area is 1 × 1.
/// [monochrome] draws every shape white and cuts the ink lines out, so the
/// face survives as line art in Android 13 themed icons.
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

  /// Bald head centred at [h], white beard, closed thinking eyes and a toga
  /// reaching down to [bottom]; [k] scales.
  void paintPhilosopher(Canvas c, Offset h, double k, {double bottom = 1.3}) {
    double s(double v) => v * k;
    final hx = h.dx, hy = h.dy;

    // Toga and shoulders, with a drape line.
    _outlined(
      c,
      Path()
        ..moveTo(hx - s(0.36), bottom)
        ..cubicTo(
          hx - s(0.34),
          hy + s(0.34),
          hx - s(0.2),
          hy + s(0.27),
          hx,
          hy + s(0.27),
        )
        ..cubicTo(
          hx + s(0.2),
          hy + s(0.27),
          hx + s(0.34),
          hy + s(0.34),
          hx + s(0.36),
          bottom,
        )
        ..close(),
      toga,
    );
    if (!monochrome) {
      c.drawPath(
        Path()
          ..moveTo(hx - s(0.27), hy + s(0.36))
          ..quadraticBezierTo(hx + s(0.02), hy + s(0.56), hx + s(0.3), bottom),
        _line(togaShade, s(0.022)),
      );
    }

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
}
