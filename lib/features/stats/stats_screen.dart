import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/stats.dart';
import '../../core/strings.dart';
import '../../data/question.dart';
import '../../data/stats_store.dart';
import '../../widgets/calibration_text.dart';
import '../../widgets/stat_tile.dart';
import 'calibration_chart.dart';

/// Daily totals, calibration over time, miss direction and per-category
/// hit rates. Everything comes from [StatsStore]; nothing leaves the device.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.stats, required this.today});

  final StatsStore stats;
  final int today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.stats)),
      body: SafeArea(
        child: stats.answered == 0
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    AppStrings.statsEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  _DailySection(stats: stats, today: today),
                  const SizedBox(height: 32),
                  _CalibrationSection(stats: stats),
                  if (stats.answerLog.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _CategorySection(log: stats.answerLog),
                  ],
                ],
              ),
      ),
    );
  }
}

class _DailySection extends StatelessWidget {
  const _DailySection({required this.stats, required this.today});

  final StatsStore stats;
  final int today;

  @override
  Widget build(BuildContext context) {
    final days = stats.completedDays;
    final summary = dailyScoreSummary([
      for (final d in days) totalPoints(stats.dailyResults(d)),
    ]);
    String orDash(int? v) => v == null ? AppStrings.noValue : '$v';
    return Column(
      children: [
        Row(
          children: [
            StatTile(label: AppStrings.gamesPlayed, value: '${summary.days}'),
            StatTile(
              label: AppStrings.streak,
              value: AppStrings.streakDays(stats.streak(today)),
            ),
            StatTile(
              label: AppStrings.longestStreak,
              value: AppStrings.streakDays(longestStreak(days)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            StatTile(
              label: AppStrings.averageScore,
              value: orDash(summary.average),
            ),
            StatTile(label: AppStrings.bestDay, value: orDash(summary.best)),
            StatTile(
              label: AppStrings.answeredCount,
              value: formatNumber(stats.answered),
            ),
          ],
        ),
      ],
    );
  }
}

class _CalibrationSection extends StatelessWidget {
  const _CalibrationSection({required this.stats});

  final StatsStore stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final log = stats.answerLog;
    final rates = hitRateBlocks(log);
    final misses = log.where((r) => r.outcome != Outcome.hit).length;
    final bias = switch (missBias(log)) {
      Outcome.tooHigh => AppStrings.missBiasHigh,
      Outcome.tooLow => AppStrings.missBiasLow,
      _ => AppStrings.missBiasNone,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.calibration, style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          calibrationSummary(stats.hits, stats.answered),
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        if (rates.isEmpty)
          Text(
            AppStrings.calibrationChartEmpty(calibrationBlockSize),
            style: textTheme.bodySmall,
          )
        else ...[
          CalibrationChart(rates: rates),
          const SizedBox(height: 8),
          Text(
            AppStrings.calibrationChartCaption(calibrationBlockSize),
            style: textTheme.bodySmall,
          ),
        ],
        if (misses >= minMissesForBias) ...[
          const SizedBox(height: 16),
          Text(bias, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.log});

  final List<AnswerRecord> log;

  static String _name(QuestionCategory c) => switch (c) {
    QuestionCategory.geography => AppStrings.categoryGeography,
    QuestionCategory.history => AppStrings.categoryHistory,
    QuestionCategory.turkey => AppStrings.categoryTurkey,
    QuestionCategory.science => AppStrings.categoryScience,
    QuestionCategory.sports => AppStrings.categorySports,
    QuestionCategory.everyday => AppStrings.categoryEveryday,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.byCategory, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final MapEntry(key: category, value: tally) in tallyByCategory(
          log,
        ).entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name(category),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      AppStrings.categoryTally(
                        formatPercent(tally.hits / tally.answered),
                        tally.answered,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: tally.hits / tally.answered,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
