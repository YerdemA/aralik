// Draws the duel's end poses to build/duelists/ for a visual check:
//   flutter test tools/duel/render_duelists_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/core/theme.dart';
import 'package:aralik/widgets/duelist.dart';
import 'package:aralik/widgets/philosopher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render duelists', () async {
    const size = 480.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size * 3, size),
      Paint()..color = const Color(0xFFFFF9F1),
    );
    for (final (i, pose) in DuelPose.values.indexed) {
      canvas.save();
      canvas.translate(size * i, 0);
      DuelistPainter(
        pose: pose,
        sash: i.isEven ? Palette.duelMe : Palette.duelOpponent,
      ).paint(canvas, const Size.square(size));
      canvas.restore();
    }
    final image = await recorder.endRecording().toImage(
      (size * 3).round(),
      size.round(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/duelists/poses.png')..createSync(recursive: true);
    out.writeAsBytesSync(png!.buffer.asUint8List());
  });
}
