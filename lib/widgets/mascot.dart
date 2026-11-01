import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'philosopher.dart';

/// The philosopher on screen; his "?" bubble wobbles once when he appears.
/// Decorative, so screen readers skip him.
class Mascot extends StatelessWidget {
  const Mascot({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          // The toga runs past the square; keep it inside.
          builder: (context, wobble, _) => ClipRect(
            child: CustomPaint(
              size: Size.square(size),
              painter: MascotPainter(wobble: wobble),
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon's composition in a square; the bubble wobbles with [wobble]
/// (0 → 1, still at both ends). [circular] clips to the launch icon's circle.
class MascotPainter extends CustomPainter {
  const MascotPainter({required this.wobble, this.circular = false});

  final double wobble;
  final bool circular;

  // Where Philosopher.paintScene puts the bubble, in design units.
  static const _bubbleFrom = Offset(0.6, 0.33);
  static const _bubbleAt = Offset(0.71, 0.24);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    if (circular) {
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCircle(center: const Offset(0.5, 0.5), radius: 0.5),
        ),
      );
    }
    const mascot = Philosopher();
    mascot.paintPhilosopher(canvas, const Offset(0.4, 0.52), 1.25);

    // A damped wiggle with a little bounce in size.
    final angle = math.sin(wobble * math.pi * 3) * (1 - wobble) * 0.25;
    final scale = 1 + math.sin(wobble * math.pi) * 0.1;
    canvas.translate(_bubbleAt.dx, _bubbleAt.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.translate(-_bubbleAt.dx, -_bubbleAt.dy);
    mascot.paintThought(canvas, _bubbleFrom, _bubbleAt, 0.14);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MascotPainter old) =>
      old.wobble != wobble || old.circular != circular;
}
