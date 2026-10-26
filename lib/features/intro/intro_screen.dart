import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/philosopher.dart';

/// A short intro on cold start that continues the Android launch screen
/// in place (same navy, the mascot in a 192 dp circle at the centre, also
/// as the window background, so there is no flash in between): the "?"
/// bubble wobbles and the name appears below, styled like the home
/// screen's wordmark; then [next] fades in. About 0.9 s; a tap skips it.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.next});

  /// The screen shown afterwards (the home screen).
  final Widget next;

  /// Colour of the Android launch screen (res/values/colors.xml).
  static const navy = Color(0xFF2B3B6C);

  /// Visible size of the launch icon (192 dp, Android 12 splash icon
  /// without background).
  static const double iconSize = 192;

  static const duration = Duration(milliseconds: 650);
  static const fade = Duration(milliseconds: 250);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  bool _left = false;

  void _finish() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: IntroScreen.fade,
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: ColoredBox(
          color: IntroScreen.navy,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: IntroScreen.duration,
            onEnd: _finish,
            builder: (context, t, _) => _IntroFrame(t: t),
          ),
        ),
      ),
    );
  }
}

/// One frame of the intro at progress [t] (0 → 1).
class _IntroFrame extends StatelessWidget {
  const _IntroFrame({required this.t});

  final double t;

  /// The home wordmark's colour in the dark theme: soft, not plain white.
  static const _wordmark = Color(0xFFC9D8FF);

  /// [t] mapped into [begin, end] and eased.
  double _phase(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final name = _phase(0.0, 0.55);
    final textTheme = Theme.of(context).textTheme;
    // The mascot stays exactly where the launch screen left it.
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size.square(IntroScreen.iconSize),
          painter: _MascotPainter(wobble: _phase(0.0, 1.0, Curves.linear)),
        ),
        Transform.translate(
          offset: Offset(0, IntroScreen.iconSize / 2 + 52 + 12 * (1 - name)),
          child: Opacity(
            opacity: name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.appName,
                  style: textTheme.displayMedium?.copyWith(
                    color: _wordmark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                CustomPaint(
                  size: const Size(128, 14),
                  painter: _RangeMarkPainter(
                    open: _phase(0.2, 1.0, Curves.easeOutBack),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The launch icon's mascot, clipped to the same circle as the launch
/// screen; the thought bubble wobbles with [wobble] (0 → 1).
class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.wobble});

  final double wobble;

  // Where Philosopher.paintScene puts the bubble, in design units.
  static const _bubbleFrom = Offset(0.6, 0.33);
  static const _bubbleAt = Offset(0.71, 0.24);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.5), radius: 0.5)),
    );
    const mascot = Philosopher();
    mascot.paintPhilosopher(canvas, const Offset(0.4, 0.52), 1.25);

    // A damped wiggle with a little bounce in size; still at both ends.
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
  bool shouldRepaint(_MascotPainter old) => old.wobble != wobble;
}

/// The home screen's range mark on navy, its handles opening with [open].
class _RangeMarkPainter extends CustomPainter {
  _RangeMarkPainter({required this.open});

  final double open;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const thickness = 5.0;
    const r = Radius.circular(thickness / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        mid - thickness / 2,
        size.width,
        mid + thickness / 2,
        r,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    final half = size.width * (0.04 + 0.26 * open);
    final lo = size.width / 2 - half, hi = size.width / 2 + half;
    canvas.drawRRect(
      RRect.fromLTRBR(lo, mid - thickness / 2, hi, mid + thickness / 2, r),
      Paint()..color = Palette.terracotta,
    );
    final handle = Paint()..color = _IntroFrame._wordmark;
    canvas.drawCircle(Offset(lo, mid), size.height / 2, handle);
    canvas.drawCircle(Offset(hi, mid), size.height / 2, handle);
  }

  @override
  bool shouldRepaint(_RangeMarkPainter old) => old.open != open;
}
