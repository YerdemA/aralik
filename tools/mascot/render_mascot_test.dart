// Draws the mascot's options and a few looks in every pose to
// build/mascot/ for a visual check:
//   flutter test tools/mascot/render_mascot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/core/day_mood.dart';
import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/widgets/philosopher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cell = 260.0;

Future<void> _save(String name, List<List<void Function(Canvas)>> rows) async {
  final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _cell * cols, _cell * rows.length),
    Paint()..color = const Color(0xFFFFF9F1),
  );
  for (final (y, row) in rows.indexed) {
    for (final (x, draw) in row.indexed) {
      canvas.save();
      canvas.translate(_cell * x, _cell * y);
      canvas.clipRect(const Rect.fromLTWH(0, 0, _cell, _cell));
      canvas.scale(_cell);
      draw(canvas);
      canvas.restore();
    }
  }
  final image = await recorder.endRecording().toImage(
    (_cell * cols).round(),
    (_cell * rows.length).round(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('build/mascot/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void Function(Canvas) _portrait(MascotLook look) =>
    (c) =>
        Philosopher(look: look)
            .paintPhilosopher(c, const Offset(0.5, 0.5), 1.25, awake: true);

void Function(Canvas) _posed(
  MascotLook look, {
  DayMood? mood,
  DuelPose? pose,
}) =>
    (c) => Philosopher(look: look).paintPhilosopher(
      c,
      const Offset(0.5, 0.42),
      0.75,
      bottom: 1.0,
      mood: mood,
      pose: pose,
    );

void main() {
  test('render mascot options', () async {
    const man = MascotLook.philosopher;
    const woman = MascotLook.woman;
    await _save('options', [
      [for (final v in MascotGender.values) _portrait(man.copyWith(gender: v))],
      [for (final v in MascotSkin.values) _portrait(man.copyWith(skin: v))],
      [for (final v in MascotSkin.values) _portrait(woman.copyWith(skin: v))],
      [
        for (final v in MascotBeard.values)
          _portrait(man.copyWith(beard: v, hairColor: MascotHairColor.brown)),
      ],
      [
        for (final v in MascotMoustache.values)
          _portrait(
            man.copyWith(
              moustache: v,
              beard: MascotBeard.none,
              hairColor: MascotHairColor.black,
            ),
          ),
      ],
      [
        for (final v in MascotHairColor.values)
          _portrait(man.copyWith(hairColor: v)),
      ],
      [
        for (final v in MascotHairColor.values)
          _portrait(woman.copyWith(hairColor: v)),
      ],
      [for (final v in MascotHair.values) _portrait(man.copyWith(hair: v))],
      [for (final v in MascotHair.values) _portrait(woman.copyWith(hair: v))],
      [for (final v in MascotHat.values) _portrait(man.copyWith(hat: v))],
      [for (final v in MascotHat.values) _portrait(woman.copyWith(hat: v))],
      [for (final v in MascotEyes.values) _portrait(man.copyWith(eyes: v))],
      [for (final v in MascotEyes.values) _portrait(woman.copyWith(eyes: v))],
      [
        for (final v in MascotGlasses.values)
          _portrait(man.copyWith(glasses: v)),
      ],
    ]);
  });

  test('render mascot poses', () async {
    final looks = [
      MascotLook.philosopher,
      MascotLook.woman.copyWith(
        skin: MascotSkin.dark,
        hat: MascotHat.beret,
        glasses: MascotGlasses.round,
      ),
      const MascotLook(
        skin: MascotSkin.light,
        beard: MascotBeard.goatee,
        moustache: MascotMoustache.handlebar,
        hair: MascotHair.curly,
        hat: MascotHat.fez,
        eyes: MascotEyes.round,
        glasses: MascotGlasses.monocle,
      ),
      MascotLook.woman.copyWith(
        hair: MascotHair.bun,
        hat: MascotHat.mortarboard,
        eyes: MascotEyes.sleepy,
        glasses: MascotGlasses.sunglasses,
      ),
    ];
    await _save('poses', [
      for (final look in looks)
        [
          _posed(look),
          for (final m in DayMood.values) _posed(look, mood: m),
          for (final p in DuelPose.values) _posed(look, pose: p),
        ],
    ]);
  });
}
