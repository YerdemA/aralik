import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/question.dart';
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  answer.hit
                      ? AppStrings.hit
                      : answer.points > 0
                      ? AppStrings.nearMiss
                      : AppStrings.miss,
                  style: theme.textTheme.headlineMedium?.copyWith(color: color),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${answer.points} ${AppStrings.points}',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(q.text, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                IntervalBar(
                  isYear: isYear,
                  low: answer.low,
                  high: answer.high,
                  answer: q.answer,
                  bandColor: color,
                ),
                const SizedBox(height: 12),
                _Row(label: AppStrings.answer, value: answerText),
                _Row(
                  label: AppStrings.yourInterval,
                  value: formatRange(
                    answer.low,
                    answer.high,
                    unit: q.unit,
                    isYear: isYear,
                  ),
                ),
                if (q.funFact != null) ...[
                  const SizedBox(height: 16),
                  Text(q.funFact!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.source}: ${q.source}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isLast ? AppStrings.finish : AppStrings.next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
