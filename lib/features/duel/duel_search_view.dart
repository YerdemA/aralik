import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/question.dart';
import '../../core/duel.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// While the lobby looks for a random opponent: the player's blue badge
/// sends out radar rings and a red "?" circles around it, the wait is
/// counted, and a short note changes every [duelTipEvery].
class DuelSearchView extends StatefulWidget {
  const DuelSearchView({
    super.key,
    required this.name,
    this.firstTip,
    this.math = false,
  });

  /// Looking for a math duel's opponent (said above the title).
  final bool math;

  /// The player's display name; its first letter is on the badge.
  final String name;

  /// The note to start with; random when null.
  final int? firstTip;

  @override
  State<DuelSearchView> createState() => _DuelSearchViewState();
}

class _DuelSearchViewState extends State<DuelSearchView>
    with SingleTickerProviderStateMixin {
  late final _radar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final int _firstTip =
      widget.firstTip ?? math.Random().nextInt(AppStrings.duelTips.length);
  final _started = DateTime.now();
  Duration _waited = Duration.zero;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _waited = DateTime.now().difference(_started));
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tip = duelTipAt(
      _waited,
      first: _firstTip,
      count: AppStrings.duelTips.length,
    );
    final initial = widget.name.trim().isEmpty
        ? '?'
        : widget.name.trim().characters.first.toUpperCase();
    // The radar gives way on a short screen; the texts and the note keep
    // their size (about 380 dp with the gaps).
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: SizedBox.square(
              dimension: box.maxHeight.isFinite
                  ? (box.maxHeight - 380).clamp(120.0, 240.0)
                  : 240,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _radar,
                  builder: (context, child) => CustomPaint(
                    painter: _RadarPainter(t: _radar.value),
                    child: child,
                  ),
                  child: Center(child: _Badge(letter: initial)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(child: _ModePill(math: widget.math)),
          const SizedBox(height: 10),
          Text(
            AppStrings.duelSearching,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.duelSearchingHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Palette.duelMe.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                AppStrings.duelSearchElapsed(_waited),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Palette.duelMe,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const Spacer(),
          _TipCard(index: tip),
        ],
      ),
    );
  }
}

/// The player's letter in a blue coin.
class _Badge extends StatelessWidget {
  const _Badge({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B8FF5), Palette.duelMe],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Palette.duelMe.withValues(alpha: .4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Three blue rings that grow and fade from the centre, a faint orbit,
/// and a red "?" bubble travelling along it.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t});

  /// Progress of one cycle, 0 → 1.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    const minR = 42.0;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final r = minR + (maxR - minR) * Curves.easeOut.transform(p);
      canvas
        ..drawCircle(
          centre,
          r,
          Paint()..color = Palette.duelMe.withValues(alpha: .10 * (1 - p)),
        )
        ..drawCircle(
          centre,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Palette.duelMe.withValues(alpha: .45 * (1 - p)),
        );
    }
    final orbit = maxR * .78;
    canvas.drawCircle(
      centre,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.duelOpponent.withValues(alpha: .25),
    );
    final angle = -math.pi / 2 + 2 * math.pi * t;
    final at = centre + Offset(math.cos(angle), math.sin(angle)) * orbit;
    canvas
      ..drawCircle(
        at,
        19,
        Paint()..color = Palette.duelOpponent.withValues(alpha: .25),
      )
      ..drawCircle(at, 15, Paint()..color = Palette.duelOpponent);
    const icon = Icons.question_mark_rounded;
    final mark = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(canvas, at - Offset(mark.width / 2, mark.height / 2));
    mark.dispose();
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

/// "Beklerken": one note, a fade to the next, and a thin bar that fills
/// until it changes.
class _TipCard extends StatelessWidget {
  const _TipCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 20,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.duelTipTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  // Room for four lines, so the card does not jump.
                  height: 4 * 1.4 * (theme.textTheme.bodyLarge?.fontSize ?? 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      AppStrings.duelTips[index],
                      key: ValueKey(index),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            key: ValueKey(index),
            tween: Tween(begin: 0, end: 1),
            duration: duelTipEvery,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              color: scheme.tertiary,
              backgroundColor: scheme.tertiary.withValues(alpha: .12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which duel the search is for: "Bilgi düellosu" or "Matematik düellosu".
class _ModePill extends StatelessWidget {
  const _ModePill({required this.math});

  final bool math;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = math
        ? QuestionCategory.math.color(theme.brightness)
        : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            math ? Icons.calculate_rounded : Icons.lightbulb_rounded,
            size: 18,
            color: colour,
          ),
          const SizedBox(width: 6),
          Text(
            math ? AppStrings.mathDuelTitle : AppStrings.duelModeBank,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colour,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
