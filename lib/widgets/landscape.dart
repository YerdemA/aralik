import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The app icon's scenery, drawn in code: sky, snowy mountains, a tower,
/// a castle and a green plain. A night version in the dark theme. The
/// mountains rise in once with a light implicit animation.
class Landscape extends StatelessWidget {
  const Landscape({super.key});

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _LandscapePainter(rise: t, night: night),
        ),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter({required this.rise, required this.night});

  /// 0 → 1 while the scene rises in.
  final double rise;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final clip = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.save();
    canvas.clipRRect(clip);

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? const [Palette.nightSkyTop, Palette.nightSkyBottom]
              : const [Palette.skyTop, Palette.skyBottom],
        ).createShader(rect),
    );

    // Sun or moon with stars.
    final sky = Offset(w * 0.86, h * 0.17);
    if (night) {
      final stars = Paint()..color = Palette.snow.withValues(alpha: .8 * rise);
      final rng = math.Random(7);
      for (var i = 0; i < 22; i++) {
        canvas.drawCircle(
          Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.5),
          rng.nextDouble() * 1.4 + 0.6,
          stars,
        );
      }
      canvas.drawCircle(sky, h * 0.09, Paint()..color = Palette.moon);
      canvas.drawCircle(
        sky.translate(h * 0.04, -h * 0.025),
        h * 0.08,
        Paint()..color = Palette.nightSkyTop,
      );
    } else {
      canvas.drawCircle(
        sky,
        h * 0.16,
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
      canvas.drawCircle(sky, h * 0.1, Paint()..color = const Color(0xFFFFF1C2));
    }

    // Everything below rises from the bottom.
    canvas.translate(0, (1 - rise) * h * 0.35);

    final far = night ? Palette.nightFarMountain : Palette.farMountain;
    final near = night ? Palette.nightNearMountain : Palette.nearMountain;
    final snow = night ? Palette.nightSnow : Palette.snow;

    _mountain(
      canvas,
      size,
      peak: Offset(w * 0.72, h * 0.3),
      base: 0.62,
      color: far,
      snow: snow,
    );
    _mountain(
      canvas,
      size,
      peak: Offset(w * 0.3, h * 0.18),
      base: 0.75,
      color: near,
      snow: snow,
    );

    _tower(canvas, size);
    _castle(canvas, size);

    // Plain.
    final plain = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.35, h * 0.7, w * 0.65, h * 0.78)
      ..quadraticBezierTo(w * 0.85, h * 0.83, w, h * 0.76)
      ..lineTo(w, h + 40)
      ..lineTo(0, h + 40)
      ..close();
    canvas.drawPath(
      plain,
      Paint()..color = night ? Palette.nightPlain : Palette.plain,
    );
    final front = Path()
      ..moveTo(0, h * 0.93)
      ..quadraticBezierTo(w * 0.5, h * 0.86, w, h * 0.95)
      ..lineTo(w, h + 40)
      ..lineTo(0, h + 40)
      ..close();
    canvas.drawPath(
      front,
      Paint()..color = night ? Palette.nightPlainLight : Palette.plainLight,
    );
    canvas.restore();
  }

  void _mountain(
    Canvas canvas,
    Size size, {
    required Offset peak,
    required double base,
    required Color color,
    required Color snow,
  }) {
    final h = size.height;
    final half = size.width * base;
    final body = Path()
      ..moveTo(peak.dx - half, h)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(peak.dx + half, h)
      ..close();
    canvas.drawPath(body, Paint()..color = color);

    // Snow cap: the top 22% of the slope, with a zig-zag edge.
    final capY = peak.dy + (h - peak.dy) * 0.22;
    final dx = half * (capY - peak.dy) / (h - peak.dy);
    final cap = Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(peak.dx + dx, capY)
      ..lineTo(peak.dx + dx * 0.4, capY - 8)
      ..lineTo(peak.dx, capY + 2)
      ..lineTo(peak.dx - dx * 0.4, capY - 8)
      ..lineTo(peak.dx - dx, capY)
      ..close();
    canvas.drawPath(cap, Paint()..color = snow);
  }

  void _tower(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final x = w * 0.1, top = h * 0.46, width = w * 0.075;
    final body = Rect.fromLTRB(x, top, x + width, h * 0.86);
    canvas.drawRect(
      body,
      Paint()..color = night ? const Color(0xFF8A5039) : Palette.tower,
    );
    final roof = Path()
      ..moveTo(x - width * 0.25, top)
      ..lineTo(x + width / 2, top - width * 1.3)
      ..lineTo(x + width * 1.25, top)
      ..close();
    canvas.drawPath(
      roof,
      Paint()..color = night ? const Color(0xFF1A2440) : Palette.roof,
    );
    final window = Paint()
      ..color = night ? const Color(0xFFFFD27A) : Palette.roof;
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + width / 2, top + width * (0.9 + i * 1.1)),
            width: width * 0.28,
            height: width * 0.55,
          ),
          Radius.circular(width * 0.14),
        ),
        window,
      );
    }
  }

  void _castle(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = w * 0.78, right = w * 0.95, top = h * 0.55;
    final color = Paint()
      ..color = night ? const Color(0xFF6B5541) : Palette.castle;
    canvas.drawRect(Rect.fromLTRB(left, top, right, h * 0.86), color);
    final tooth = (right - left) / 7;
    for (var i = 0; i < 7; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(left + i * tooth, top - tooth, tooth, tooth),
        color,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(
          left + tooth * 2.6,
          h * 0.72,
          left + tooth * 4.4,
          h * 0.86,
        ),
        topLeft: Radius.circular(tooth),
        topRight: Radius.circular(tooth),
      ),
      Paint()
        ..color = night ? const Color(0xFF3F3226) : const Color(0xFF7A5C40),
    );
  }

  @override
  bool shouldRepaint(_LandscapePainter old) =>
      old.rise != rise || old.night != night;
}
