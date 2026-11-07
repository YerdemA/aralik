import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../data/sound.dart';
import '../../widgets/mascot.dart';

/// A short intro on cold start that continues the Android launch screen
/// in place (same navy, the mascot in a 192 dp circle at the centre, also
/// as the window background, so there is no flash in between): the "?"
/// bubble wobbles and the name appears below to a short chime; then [next]
/// fades in. About 0.9 s; a tap skips it.
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

  @override
  void initState() {
    super.initState();
    Sounds.playIntro();
  }

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

  /// Soft, not plain white.
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
          painter: MascotPainter(
            wobble: _phase(0.0, 1.0, Curves.linear),
            circular: true,
          ),
        ),
        Transform.translate(
          offset: Offset(0, IntroScreen.iconSize / 2 + 52 + 12 * (1 - name)),
          child: Opacity(
            opacity: name,
            child: Text(
              AppStrings.appName,
              style: textTheme.displayMedium?.copyWith(
                color: _wordmark,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
