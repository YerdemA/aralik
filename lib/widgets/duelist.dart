import 'package:flutter/material.dart';

import '../core/mascot_look.dart';
import 'philosopher.dart';

/// The philosopher at a duel's end, full figure, wearing a sash in the
/// player's colour. Decorative, so screen readers skip him.
class Duelist extends StatelessWidget {
  const Duelist({
    super.key,
    required this.pose,
    required this.sash,
    required this.size,
    this.look = MascotLook.philosopher,
  });

  final MascotLook look;
  final DuelPose pose;
  final Color sash;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: DuelistPainter(pose: pose, sash: sash, look: look),
        ),
      ),
    );
  }
}

class DuelistPainter extends CustomPainter {
  const DuelistPainter({
    required this.pose,
    required this.sash,
    this.look = MascotLook.philosopher,
  });

  final MascotLook look;

  final DuelPose pose;
  final Color sash;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));
    Philosopher(look: look).paintPhilosopher(
      canvas,
      const Offset(0.47, 0.38),
      0.64,
      bottom: 1.0,
      pose: pose,
      sash: sash,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DuelistPainter old) =>
      old.pose != pose || old.sash != sash || old.look != look;
}
