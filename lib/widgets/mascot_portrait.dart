import 'package:flutter/material.dart';

import '../core/mascot_look.dart';
import 'philosopher.dart';

/// A player's mascot, head and shoulders, eyes open: the mascot editor and
/// the players' faces in duels and tournaments. Decorative, so screen
/// readers skip it.
class MascotPortrait extends StatelessWidget {
  const MascotPortrait({
    super.key,
    required this.look,
    required this.size,
    this.zoom = false,
  });

  final MascotLook look;
  final double size;

  /// Closer on the face (the editor's option tiles).
  final bool zoom;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: MascotPortraitPainter(look, zoom: zoom),
        ),
      ),
    );
  }
}

class MascotPortraitPainter extends CustomPainter {
  const MascotPortraitPainter(this.look, {this.zoom = false});

  final MascotLook look;
  final bool zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));
    // Long beards and hats need the room: the head a little below centre.
    Philosopher(look: look).paintPhilosopher(
      canvas,
      const Offset(0.5, 0.5),
      zoom ? 1.6 : 1.25,
      awake: true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(MascotPortraitPainter old) =>
      old.look != look || old.zoom != zoom;
}
