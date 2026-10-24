import 'package:flutter/material.dart';

import '../core/interval.dart';

/// Horizontal bar: the locked interval as a band, the answer as a marker.
/// The band grows in from the guess side with a light implicit animation.
class IntervalBar extends StatelessWidget {
  const IntervalBar({
    super.key,
    required this.isYear,
    required this.low,
    required this.high,
    required this.answer,
    required this.bandColor,
  });

  final bool isYear;
  final num low;
  final num high;
  final num answer;
  final Color bandColor;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = barPositions(
      isYear: isYear,
      low: low,
      high: high,
      answer: answer,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: const Size.fromHeight(height),
        painter: _BarPainter(
          low: p.low,
          high: p.high,
          answer: p.answer,
          reveal: t,
          track: scheme.surfaceContainerHighest,
          band: bandColor,
          marker: scheme.onSurface,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.low,
    required this.high,
    required this.answer,
    required this.reveal,
    required this.track,
    required this.band,
    required this.marker,
  });

  final double low;
  final double high;
  final double answer;
  final double reveal;
  final Color track;
  final Color band;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    const trackHeight = 12.0;
    final radius = const Radius.circular(trackHeight / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, midY - trackHeight / 2, size.width, trackHeight),
        radius,
      ),
      Paint()..color = track,
    );

    // The band opens from its centre; a zero-width interval stays visible.
    final centre = (low + high) / 2 * size.width;
    final half = ((high - low) / 2 * size.width * reveal).clamp(
      3.0,
      size.width,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          centre - half,
          midY - trackHeight / 2,
          centre + half,
          midY + trackHeight / 2,
        ),
        radius,
      ),
      Paint()..color = band,
    );

    final x = answer * size.width;
    canvas.drawLine(
      Offset(x, 2),
      Offset(x, size.height - 2),
      Paint()
        ..color = marker.withValues(alpha: reveal)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.reveal != reveal ||
      old.low != low ||
      old.high != high ||
      old.answer != answer ||
      old.band != band;
}
