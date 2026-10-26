import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';

/// Hit rate per block of answers as bars, with a dashed 90% target line.
class CalibrationChart extends StatelessWidget {
  const CalibrationChart({super.key, required this.rates});

  /// Block hit rates (0–1), oldest first.
  final List<double> rates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppStrings.calibrationChartSemantics(
        rates.map(formatPercent).join(', '),
      ),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            rates: rates,
            bar: scheme.primary,
            track: scheme.surfaceContainerHighest,
            target: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.rates,
    required this.bar,
    required this.track,
    required this.target,
  });

  final List<double> rates;
  final Color bar;
  final Color track;
  final Color target;

  static const _gap = 6.0;
  static const _maxBarWidth = 28.0;
  static const _radius = Radius.circular(4);

  @override
  void paint(Canvas canvas, Size size) {
    if (rates.isEmpty) return;
    final width = ((size.width + _gap) / rates.length - _gap).clamp(
      2.0,
      _maxBarWidth,
    );
    final trackPaint = Paint()..color = track;
    final barPaint = Paint()..color = bar;
    for (var i = 0; i < rates.length; i++) {
      final left = i * (width + _gap);
      canvas.drawRRect(
        RRect.fromLTRBR(left, 0, left + width, size.height, _radius),
        trackPaint,
      );
      final top = size.height * (1 - rates[i].clamp(0.0, 1.0));
      if (top < size.height) {
        canvas.drawRRect(
          RRect.fromLTRBR(left, top, left + width, size.height, _radius),
          barPaint,
        );
      }
    }

    // Dashed target line across the bars.
    final y = size.height * (1 - calibrationTarget);
    final end = rates.length * (width + _gap) - _gap;
    final linePaint = Paint()
      ..color = target
      ..strokeWidth = 2;
    for (var x = 0.0; x < end; x += 10) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 6).clamp(0, end), y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.rates != rates ||
      old.bar != bar ||
      old.track != track ||
      old.target != target;
}
