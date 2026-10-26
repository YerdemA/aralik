import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/calibration_text.dart';
import '../../widgets/count_up.dart';

enum SummaryAction { newRound, home }

/// End of a daily set (share) or a free-play round (new round).
/// Pops with the chosen [SummaryAction].
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.results,
    required this.hits,
    required this.answered,
    this.shareText,
  });

  /// Outcome per question, in order.
  final List<QuestionResult> results;

  /// All-time calibration counts.
  final int hits;
  final int answered;

  /// Set for the daily set: the main action becomes "Paylaş".
  final String? shareText;

  bool get _isDaily => shareText != null;

  /// Green when calibrated, amber when off, neutral without enough data.
  Color _calibrationColor(ThemeData theme) {
    final colors = theme.extension<GameColors>()!;
    return switch (calibrationFeedback(hits, answered)) {
      CalibrationFeedback.good => colors.good,
      CalibrationFeedback.notEnoughData => theme.colorScheme.primary,
      _ => colors.partial,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalPoints(results);
    final max = results.length * maxPointsPerQuestion;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                _isDaily ? AppStrings.daySummary : AppStrings.roundSummary,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  CountUp(
                    value: total,
                    duration: const Duration(milliseconds: 1000),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    ' / $max',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _TierRow(results: results),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.track_changes_rounded,
                        color: _calibrationColor(theme),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          calibrationSummary(hits, answered),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isDaily) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.comeBackTomorrow,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (_isDaily)
                FilledButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: shareText,
                      subject: AppStrings.shareSubject,
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text(AppStrings.share),
                )
              else
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(SummaryAction.newRound),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(AppStrings.newRound),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.home_rounded),
                label: const Text(AppStrings.backHome),
                onPressed: () => Navigator.of(context).pop(SummaryAction.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloured squares matching the share card, popping in one by one, with
/// each question's points below.
class _TierRow extends StatelessWidget {
  const _TierRow({required this.results});

  final List<QuestionResult> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<GameColors>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, r) in results.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                // Later squares take longer, so they land one after another.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 350 + 150 * i),
                  curve: Interval(
                    i / (results.length + 1),
                    1,
                    curve: Curves.easeOutBack,
                  ),
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.forTier(r.tier),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.points}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
