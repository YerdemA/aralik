// Renders the app icon to PNG files. Not part of the app or the test suite.
//
//   flutter test tools/icon/render_icon_test.dart
//
// Writes the Android launcher icons (legacy, round, adaptive layers and the
// Android 13 monochrome layer) into android/app/src/main/res/ and a 512 px
// Play Store icon into docs/store/icon-512.png.
//
// Design: a thinking philosopher (bald, white beard, eyes closed, one brow
// raised) in a terracotta toga on the app's navy, with a thought bubble
// holding a question mark.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// Legacy launcher icon size (48 dp) and adaptive layer size (108 dp) per density.
const _densities = {
  'mdpi': (48, 108),
  'hdpi': (72, 162),
  'xhdpi': (96, 216),
  'xxhdpi': (144, 324),
  'xxxhdpi': (192, 432),
};

const _ink = Color(0xFF1C2742);
const _navyTop = Color(0xFF34477D);
const _navyBottom = Color(0xFF22305A);
const _skin = Color(0xFFF2C29B);
const _skinShade = Color(0xFFDDA27A);
const _beard = Color(0xFFF7F3EC);
const _beardShade = Color(0xFFDCD5CB);
const _toga = Color(0xFFE0784A);
const _togaShade = Color(0xFFC25E33);
const _white = Color(0xFFFFFFFF);

/// Outline half-width, in design units (the visible icon is 1 × 1).
const double _outline = 0.016;

/// While painting the monochrome layer every shape is white and the ink
/// lines are cut out, so the face survives as line art when tinted.
bool _mono = false;

Paint _fill(Color c) => Paint()..color = _mono ? _white : c;

Paint _line(Color c, double width) => Paint()
  ..color = _mono ? _white : c
  ..blendMode = _mono ? BlendMode.clear : BlendMode.srcOver
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// A filled shape with a cartoon outline.
void _outlined(Canvas c, Path p, Color color) {
  c.drawPath(p, _line(_ink, _outline * 2));
  c.drawPath(p, _fill(color));
}

/// Union of circles (beard, hair, cloud) as one path.
Path _blob(List<(double, double, double)> circles) {
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

/// The design uses a unit square for the visible icon: Android shows at
/// least the central 72 of the 108 dp adaptive canvas (1024 px grid).
void _toDesignUnits(Canvas canvas) {
  canvas.translate(512, 512);
  canvas.scale(1024 * 72 / 108);
  canvas.translate(-0.5, -0.5);
}

void paintBackground(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1024, 1024),
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 1024), [
        _navyTop,
        _navyBottom,
      ]),
  );
}

void paintForeground(Canvas canvas, {bool monochrome = false}) {
  _mono = monochrome;
  canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
  canvas.save();
  _toDesignUnits(canvas);
  _philosopher(canvas, const Offset(0.4, 0.52), 1.25);
  // Inside the 66 dp safe circle (radius ≈ 0.46 here) every launcher shows.
  _thought(canvas, const Offset(0.6, 0.33), const Offset(0.71, 0.24), 0.14);
  canvas.restore();
  canvas.restore();
  _mono = false;
}

/// Thought bubble: two dots trailing from [from] to a cloud at [at].
void _thought(Canvas c, Offset from, Offset at, double size) {
  final dir = at - from;
  for (final (t, r) in [(0.0, 0.022), (0.28, 0.032)]) {
    _outlined(
      c,
      Path()..addOval(Rect.fromCircle(center: from + dir * t, radius: r)),
      _white,
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
    _white,
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
  c.drawPath(hook, _line(_ink, h * 0.15));
  c.drawCircle(
    Offset(cx, at.dy + h * 0.36),
    h * 0.085,
    Paint()
      ..color = _ink
      ..blendMode = _mono ? BlendMode.clear : BlendMode.srcOver,
  );
}

/// Bald head at [h], white beard, closed thinking eyes, toga; [k] scales.
void _philosopher(Canvas c, Offset h, double k) {
  double s(double v) => v * k;
  final hx = h.dx, hy = h.dy;
  const bottom = 1.3; // below the visible area: room for launcher parallax

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
    _toga,
  );
  if (!_mono) {
    c.drawPath(
      Path()
        ..moveTo(hx - s(0.27), hy + s(0.36))
        ..quadraticBezierTo(hx + s(0.02), hy + s(0.56), hx + s(0.3), bottom),
      _line(_togaShade, s(0.022)),
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
      _skin,
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
      _beard,
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
    _skin,
  );
  if (!_mono) {
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
      _line(_white.withValues(alpha: 0.7), s(0.016)),
    );
    c.drawPath(
      Path()
        ..moveTo(hx - s(0.05), hy - s(0.105))
        ..quadraticBezierTo(hx, hy - s(0.125), hx + s(0.05), hy - s(0.105)),
      _line(_skinShade, s(0.012)),
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
    _beard,
  );
  if (!_mono) {
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
        _line(_beardShade, s(0.012)),
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
    _beard,
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
    _skin,
  );

  // Closed eyes; the right brow raised in thought.
  final eye = _line(_ink, s(0.016));
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

enum _Layer {
  background,
  foreground,
  monochrome,
  monoPreview,
  full,
  round,
  store,
}

Future<void> _render(_Layer layer, int size, String path) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / 1024);

  switch (layer) {
    case _Layer.background:
      paintBackground(canvas);
    case _Layer.foreground:
      paintForeground(canvas);
    case _Layer.monochrome:
      paintForeground(canvas, monochrome: true);
    case _Layer.monoPreview:
      // How Android 13 themed icons tint the monochrome layer.
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()..color = const Color(0xFFD6E3FF),
      );
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
      paintForeground(canvas, monochrome: true);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()
          ..color = const Color(0xFF1B3A6B)
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    case _Layer.full || _Layer.round || _Layer.store:
      // Legacy icons show what the adaptive mask shows: the central 72 of
      // 108 dp.
      const zoom = 108 / 72;
      final clip = layer == _Layer.round
          ? (Path()..addOval(const Rect.fromLTWH(0, 0, 1024, 1024)))
          : (Path()..addRRect(
              RRect.fromLTRBR(0, 0, 1024, 1024, const Radius.circular(180)),
            ));
      if (layer != _Layer.store) canvas.clipPath(clip);
      canvas.translate(512, 512);
      canvas.scale(zoom);
      canvas.translate(-512, -512);
      paintBackground(canvas);
      paintForeground(canvas);
  }

  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render launcher icons', () async {
    for (final MapEntry(key: density, value: (legacy, adaptive))
        in _densities.entries) {
      final dir = '$_res/mipmap-$density';
      await _render(_Layer.full, legacy, '$dir/ic_launcher.png');
      await _render(_Layer.round, legacy, '$dir/ic_launcher_round.png');
      await _render(
        _Layer.background,
        adaptive,
        '$dir/ic_launcher_background.png',
      );
      await _render(
        _Layer.foreground,
        adaptive,
        '$dir/ic_launcher_foreground.png',
      );
      await _render(
        _Layer.monochrome,
        adaptive,
        '$dir/ic_launcher_monochrome.png',
      );
    }
    File('$_res/mipmap-anydpi-v26/ic_launcher.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(_adaptiveXml);
    File('$_res/mipmap-anydpi-v26/ic_launcher_round.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(_adaptiveXml);
    await _render(_Layer.store, 512, 'docs/store/icon-512.png');
    // Large previews for review (not shipped).
    await _render(_Layer.full, 1024, 'build/icon_preview/full.png');
    await _render(_Layer.round, 256, 'build/icon_preview/round-256.png');
    await _render(_Layer.full, 96, 'build/icon_preview/full-96.png');
    await _render(_Layer.monoPreview, 432, 'build/icon_preview/mono-432.png');
  });
}

const _adaptiveXml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';
