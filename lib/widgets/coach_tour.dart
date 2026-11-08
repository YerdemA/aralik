import 'package:flutter/material.dart';

import '../core/strings.dart';

/// One step of a guided tour: a widget to light up ([target], or none for a
/// card in the middle) and what to say about it.
class CoachStep {
  const CoachStep({this.target, required this.title, required this.body});

  /// The widget to point at; null for a card on its own (a welcome).
  final GlobalKey? target;
  final String title;
  final String body;
}

/// Whether the tour was seen to the end or left with "Tanıtımdan çık".
enum CoachOutcome { finished, skipped }

/// Shows [steps] one by one over the current screen: the screen dims, the
/// step's widget stays lit in a rounded hole that glides to the next one,
/// with a card saying what it is, "2 / 9", "Geç" and "Tanıtımdan çık".
/// Steps whose widget is not on screen are left out. No package.
Future<CoachOutcome> showCoachTour(
  BuildContext context,
  List<CoachStep> steps,
) async {
  final shown = [
    for (final s in steps)
      if (s.target == null || _rectOf(s.target!) != null) s,
  ];
  if (shown.isEmpty) return CoachOutcome.finished;
  final outcome = await showGeneralDialog<CoachOutcome>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _CoachOverlay(steps: shown),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  return outcome ?? CoachOutcome.skipped;
}

/// Where [key]'s widget is on screen, or null when it is not there.
Rect? _rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  if (box.size.isEmpty) return null; // there, but nothing to see
  return box.localToGlobal(Offset.zero) & box.size;
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps});

  final List<CoachStep> steps;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _index = 0;

  static const _gap = 8.0;
  static const _radius = 20.0;

  void _next() {
    if (_index == widget.steps.length - 1) {
      Navigator.of(context).pop(CoachOutcome.finished);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final step = widget.steps[_index];
    final target = step.target == null ? null : _rectOf(step.target!);
    // No widget: a hole of nothing in the middle (the card sits there).
    final hole =
        target?.inflate(_gap) ??
        Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(CoachOutcome.skipped);
      },
      child: Material(
        type: MaterialType.transparency,
        child: TweenAnimationBuilder<Rect?>(
          tween: RectTween(end: hole),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, rect, _) {
            final r = rect ?? hole;
            return Stack(
              children: [
                // Taps on the dim area do nothing: the buttons lead.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: CustomPaint(
                      painter: _DimPainter(
                        hole: r,
                        radius: target == null ? 0 : _radius,
                      ),
                    ),
                  ),
                ),
                _placeCard(
                  size: size,
                  hole: target == null ? null : r,
                  child: _CoachCard(
                    key: ValueKey(_index),
                    step: step,
                    index: _index,
                    count: widget.steps.length,
                    onNext: _next,
                    onSkip: () =>
                        Navigator.of(context).pop(CoachOutcome.skipped),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Below the hole when it is in the upper half, above it otherwise; in
  /// the middle without one.
  Widget _placeCard({
    required Size size,
    required Rect? hole,
    required Widget child,
  }) {
    const side = 16.0;
    if (hole == null) {
      return Positioned(
        left: side,
        right: side,
        top: 0,
        bottom: 0,
        child: Center(child: child),
      );
    }
    final padding = MediaQuery.paddingOf(context);
    if (hole.center.dy < size.height / 2) {
      return Positioned(
        left: side,
        right: side,
        top: hole.bottom + 14,
        child: child,
      );
    }
    return Positioned(
      left: side,
      right: side,
      bottom: size.height - hole.top + 14,
      child: Padding(
        padding: EdgeInsets.only(top: padding.top),
        child: child,
      ),
    );
  }
}

/// The dim screen with a rounded hole.
class _DimPainter extends CustomPainter {
  _DimPainter({required this.hole, required this.radius});

  final Rect hole;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .66));
    if (radius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole, Radius.circular(radius)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: .9),
      );
    }
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.hole != hole || old.radius != radius;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = index == count - 1;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        // The dim around sets it apart; a shadow would only blacken it.
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.tourCounter(index + 1, count),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  step.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(step.body, style: theme.textTheme.bodyLarge),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // The app's buttons are full width; these share a row.
                  Flexible(
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                      ),
                      child: const Text(AppStrings.tourSkip),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(104, 48),
                    ),
                    child: Text(
                      last ? AppStrings.tourDone : AppStrings.tourNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
