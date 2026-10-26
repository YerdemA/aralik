import 'package:flutter/material.dart';

/// The brand mark: a track with an interval band between two handles that
/// opens once, like the width slider.
class RangeMark extends StatelessWidget {
  const RangeMark({super.key, this.width = 160});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.05, end: 0.32),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.elasticOut,
        builder: (context, half, _) => CustomPaint(
          size: Size(width, 18),
          painter: _RangeMarkPainter(
            half: half,
            track: scheme.surfaceContainerHighest,
            band: scheme.tertiary,
            handle: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _RangeMarkPainter extends CustomPainter {
  _RangeMarkPainter({
    required this.half,
    required this.track,
    required this.band,
    required this.handle,
  });

  /// Half the band width as a share of the track.
  final double half;
  final Color track;
  final Color band;
  final Color handle;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const thickness = 6.0;
    final r = const Radius.circular(thickness / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        mid - thickness / 2,
        size.width,
        mid + thickness / 2,
        r,
      ),
      Paint()..color = track,
    );
    final lo = size.width * (0.5 - half), hi = size.width * (0.5 + half);
    canvas.drawRRect(
      RRect.fromLTRBR(lo, mid - thickness / 2, hi, mid + thickness / 2, r),
      Paint()..color = band,
    );
    final paint = Paint()..color = handle;
    canvas.drawCircle(Offset(lo, mid), size.height / 2, paint);
    canvas.drawCircle(Offset(hi, mid), size.height / 2, paint);
  }

  @override
  bool shouldRepaint(_RangeMarkPainter old) =>
      old.half != half || old.band != band || old.handle != handle;
}
