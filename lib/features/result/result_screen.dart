import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/question.dart';
import '../../widgets/count_up.dart';
import '../../widgets/interval_bar.dart';
import '../game/game_controller.dart';

/// Outcome of one locked interval: hit/miss, points, where the answer fell
/// relative to the interval, fun fact and source.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.answer, required this.isLast});

  final RoundAnswer answer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<GameColors>()!;
    final q = answer.question;
    final isYear = q.kind == QuestionKind.year;
    final color = colors.forTier(answer.tier);
    final nearMiss = !answer.hit && answer.points > 0;
    final answerText = isYear
        ? formatYear(q.answer.round())
        : [
            formatNumber(q.answer, maxDecimals: 1),
            if (q.unit.isNotEmpty) q.unit,
          ].join(' ');

    return PopScope(
      canPop: false, // leave only through the main button
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  // Centred when it fits, scrolls when it doesn't.
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _Badge(
                              color: color,
                              icon: answer.hit
                                  ? Icons.check_rounded
                                  : nearMiss
                                  ? Icons.gps_not_fixed_rounded
                                  : Icons.close_rounded,
                              celebrate: answer.tier == ResultTier.good,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              answer.hit
                                  ? AppStrings.hit
                                  : nearMiss
                                  ? AppStrings.nearMiss
                                  : AppStrings.miss,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            CountUp(
                              value: answer.points,
                              format: (v) =>
                                  '${v > 0 ? '+' : ''}$v ${AppStrings.points}',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      q.text,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    IntervalBar(
                                      isYear: isYear,
                                      low: answer.low,
                                      high: answer.high,
                                      answer: q.answer,
                                      bandColor: color,
                                    ),
                                    const SizedBox(height: 12),
                                    _Row(
                                      label: AppStrings.answer,
                                      value: answerText,
                                      strong: true,
                                    ),
                                    _Row(
                                      label: AppStrings.yourInterval,
                                      value: formatRange(
                                        answer.low,
                                        answer.high,
                                        unit: q.unit,
                                        isYear: isYear,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (q.funFact != null) ...[
                              const SizedBox(height: 12),
                              _FunFact(text: q.funFact!),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              '${AppStrings.source}: ${q.source}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                  ),
                  label: Text(isLast ? AppStrings.finish : AppStrings.next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The outcome icon in a tinted circle that pops in. A good hit adds a
/// short burst of coloured dots.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.color,
    required this.icon,
    required this.celebrate,
  });

  final Color color;
  final IconData icon;
  final bool celebrate;

  static const double size = 96;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size * 2,
        height: size * 1.1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (celebrate)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: const Size.square(size * 2),
                  painter: _BurstPainter(t),
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: size * 0.66,
                    height: size * 0.66,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  /// 0 → 1 over the burst.
  final double t;

  static const _colors = [
    Palette.tower,
    Palette.brain,
    Palette.plain,
    Palette.skyTop,
    Color(0xFFF2C94C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final fade = (1 - t).clamp(0.0, 1.0);
    final rng = math.Random(3);
    for (var i = 0; i < 18; i++) {
      final angle = i / 18 * 2 * math.pi + rng.nextDouble() * 0.3;
      final distance =
          size.width * (0.24 + 0.24 * t) * (0.8 + rng.nextDouble() * 0.4);
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        p,
        3 + rng.nextDouble() * 3,
        Paint()..color = _colors[i % _colors.length].withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class _FunFact extends StatelessWidget {
  const _FunFact({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: scheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: strong
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
