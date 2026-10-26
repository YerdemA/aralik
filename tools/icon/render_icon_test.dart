// Renders the app icon to PNG files. Not part of the app or the test suite.
//
//   flutter test tools/icon/render_icon_test.dart
//
// Writes the Android launcher icons (legacy, round, adaptive layers and the
// Android 13 monochrome layer) into android/app/src/main/res/ and a 512 px
// Play Store icon into docs/store/icon-512.png.
//
// Design: a small stick figure in front, a simple brain inside its head;
// behind it the kind of things the questions are about: mountains, a
// tower, a castle and a plain.

import 'dart:io';
import 'dart:math' as math;
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

// Palette.
const _skyTop = Color(0xFF8EC5FF);
const _skyBottom = Color(0xFFDDEFFF);
const _farMountain = Color(0xFF7D9CC7);
const _nearMountain = Color(0xFF5B7DB1);
const _snow = Color(0xFFF4F8FF);
const _tower = Color(0xFFD9825B);
const _towerRoof = Color(0xFF3E5683);
const _castle = Color(0xFFB08A63);
const _castleDark = Color(0xFF7A5C40);
const _plain = Color(0xFF8BCB72);
const _plainLight = Color(0xFFA9DA8F);
const _ink = Color(0xFF1C2742);
const _brain = Color(0xFFF6A5C6);
const _brainLine = Color(0xFFC0507E);

/// Everything is drawn on a 1024 × 1024 design grid that maps to the
/// 108 dp adaptive icon canvas. Android shows at least the central 72 dp
/// (a circle of radius ≈ 341 around the centre), so the figure stays there.
void paintBackground(Canvas canvas) {
  const full = Rect.fromLTWH(0, 0, 1024, 1024);
  canvas.drawRect(
    full,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, 760), [
        _skyTop,
        _skyBottom,
      ]),
  );

  Path triangle(Offset a, Offset b, Offset c) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();

  // Mountains: a far range and a big peak with snow.
  canvas.drawPath(
    triangle(
      const Offset(330, 820),
      const Offset(640, 300),
      const Offset(1060, 820),
    ),
    Paint()..color = _farMountain,
  );
  canvas.drawPath(
    triangle(
      const Offset(-20, 820),
      const Offset(380, 250),
      const Offset(760, 820),
    ),
    Paint()..color = _nearMountain,
  );
  canvas.drawPath(
    Path()
      ..moveTo(380, 250)
      ..lineTo(452, 357)
      ..lineTo(418, 340)
      ..lineTo(384, 372)
      ..lineTo(350, 338)
      ..lineTo(312, 351)
      ..close(),
    Paint()..color = _snow,
  );
  canvas.drawPath(
    Path()
      ..moveTo(640, 300)
      ..lineTo(700, 389)
      ..lineTo(668, 375)
      ..lineTo(640, 398)
      ..lineTo(612, 374)
      ..lineTo(580, 389)
      ..close(),
    Paint()..color = _snow,
  );

  // Tower (left): round body, conical roof, a few windows.
  canvas.drawRRect(
    RRect.fromLTRBR(222, 462, 298, 790, const Radius.circular(10)),
    Paint()..color = _tower,
  );
  canvas.drawRect(
    const Rect.fromLTRB(210, 450, 310, 478),
    Paint()..color = _tower,
  );
  canvas.drawPath(
    triangle(
      const Offset(202, 454),
      const Offset(260, 346),
      const Offset(318, 454),
    ),
    Paint()..color = _towerRoof,
  );
  for (final y in [510.0, 584.0, 658.0]) {
    canvas.drawRRect(
      RRect.fromLTRBR(249, y, 271, y + 34, const Radius.circular(11)),
      Paint()..color = _towerRoof,
    );
  }

  // Castle (right): wall, two towers, battlements, gate.
  final castle = Paint()..color = _castle;
  canvas.drawRect(const Rect.fromLTRB(722, 600, 822, 800), castle);
  canvas.drawRect(const Rect.fromLTRB(690, 530, 742, 800), castle);
  canvas.drawRect(const Rect.fromLTRB(802, 530, 854, 800), castle);
  for (final x in [690.0, 724.0, 802.0, 836.0]) {
    canvas.drawRect(Rect.fromLTWH(x, 508, 18, 26), castle);
  }
  for (final x in [748.0, 782.0]) {
    canvas.drawRect(Rect.fromLTWH(x, 580, 20, 24), castle);
  }
  canvas.drawPath(
    Path()
      ..moveTo(750, 800)
      ..lineTo(750, 728)
      ..arcToPoint(const Offset(794, 728), radius: const Radius.circular(22))
      ..lineTo(794, 800)
      ..close(),
    Paint()..color = _castleDark,
  );

  // Plain in front.
  canvas.drawPath(
    Path()
      ..moveTo(0, 760)
      ..quadraticBezierTo(300, 720, 560, 752)
      ..quadraticBezierTo(820, 784, 1024, 744)
      ..lineTo(1024, 1024)
      ..lineTo(0, 1024)
      ..close(),
    Paint()..color = _plain,
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, 860)
      ..quadraticBezierTo(360, 820, 700, 866)
      ..quadraticBezierTo(880, 890, 1024, 860)
      ..lineTo(1024, 1024)
      ..lineTo(0, 1024)
      ..close(),
    Paint()..color = _plainLight,
  );
}

/// The stick figure with a brain in its head. [monochrome] draws a single
/// colour silhouette for Android 13 themed icons.
void paintForeground(Canvas canvas, {bool monochrome = false}) {
  final ink = monochrome ? const Color(0xFFFFFFFF) : _ink;
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 30
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  const head = Offset(512, 372);
  const headRadius = 128.0;

  // Body, arms (one hand on the chin: thinking), legs.
  canvas.drawLine(const Offset(512, 500), const Offset(512, 690), line);
  canvas.drawPath(
    Path()
      ..moveTo(512, 560)
      ..lineTo(600, 600)
      ..lineTo(574, 506),
    line,
  );
  canvas.drawLine(const Offset(512, 560), const Offset(420, 650), line);
  canvas.drawLine(const Offset(512, 690), const Offset(444, 820), line);
  canvas.drawLine(const Offset(512, 690), const Offset(580, 820), line);

  // Head.
  if (!monochrome) {
    canvas.drawCircle(
      head,
      headRadius,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
  canvas.drawCircle(head, headRadius, line);

  // Brain: a bumpy cloud with a centre groove and a few folds.
  final brain = Path();
  const centre = Offset(512, 366);
  const bumps = 9;
  for (var i = 0; i <= bumps; i++) {
    final angle = 2 * math.pi * i / bumps;
    final point = centre + Offset(math.cos(angle) * 84, math.sin(angle) * 62);
    if (i == 0) {
      brain.moveTo(point.dx, point.dy);
    } else {
      final mid = 2 * math.pi * (i - 0.5) / bumps;
      final control = centre + Offset(math.cos(mid) * 112, math.sin(mid) * 86);
      brain.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
    }
  }
  if (monochrome) {
    canvas.drawPath(
      brain,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    return;
  }
  canvas.drawPath(brain, Paint()..color = _brain);
  final fold = Paint()
    ..color = _brainLine
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(brain, fold);
  canvas.drawPath(
    Path()
      ..moveTo(512, 300)
      ..quadraticBezierTo(498, 336, 514, 366)
      ..quadraticBezierTo(530, 398, 512, 432),
    fold,
  );
  canvas.drawPath(
    Path()
      ..moveTo(452, 334)
      ..quadraticBezierTo(474, 350, 462, 378),
    fold,
  );
  canvas.drawPath(
    Path()
      ..moveTo(570, 330)
      ..quadraticBezierTo(552, 352, 572, 380),
    fold,
  );
}

enum _Layer { background, foreground, monochrome, full, round, store }

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
  });
}

const _adaptiveXml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';
