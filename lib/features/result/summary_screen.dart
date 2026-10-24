import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/calibration_text.dart';

enum SummaryAction { newRound, home }

/// End of a daily set (share) or a free-play round (new round).
/// Pops with the chosen [SummaryAction].
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.points,
    required this.hits,
    required this.answered,
    this.shareText,
  });

  /// Points per question, in order.
  final List<int> points;

  /// All-time calibration counts.
  final int hits;
  final int answered;

  /// Set for the daily set: the main action becomes "Paylaş".
  final String? shareText;

  bool get _isDaily => shareText != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = points.fold(0, (sum, p) => sum + p);
    final max = points.length * maxPointsPerQuestion;

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
              Text(
                '$total / $max',
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _TierRow(points: points),
              const SizedBox(height: 24),
              Text(
                calibrationSummary(hits, answered),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
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
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(SummaryAction.newRound),
                  child: const Text(AppStrings.newRound),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(SummaryAction.home),
                child: const Text(AppStrings.backHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloured squares matching the share card.
class _TierRow extends StatelessWidget {
  const _TierRow({required this.points});

  final List<int> points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<GameColors>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final p in points)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: '$p ${AppStrings.points}',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.forTier(ResultTier.fromPoints(p)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
