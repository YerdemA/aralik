import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/free_play.dart';
import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/share_text.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/question_repository.dart';
import '../../data/stats_store.dart';
import '../../widgets/calibration_text.dart';
import '../../widgets/landscape.dart';
import '../../widgets/range_mark.dart';
import '../../widgets/stat_tile.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';
import '../result/summary_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

/// Today's set (play / continue / done + share), streak, last score,
/// calibration, and free play.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.stats});

  final QuestionRepository repository;
  final StatsStore stats;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _rng = math.Random();
  bool _loading = false;

  QuestionRepository get _repository => widget.repository;
  StatsStore get _stats => widget.stats;

  // Read on every build, so the screen rolls over at midnight on resume.
  int get _today => dayIndexFor(DateTime.now());

  String _shareText(int day) => dailyShareText(
    dayIndex: day,
    results: _stats.dailyResults(day),
    hits: _stats.hits,
    answered: _stats.answered,
  );

  Future<void> _guarded(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(AppStrings.loadError)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playDaily() => _guarded(() async {
    final day = _today;
    final done = _stats.dailyResults(day).length;
    final remaining = (await _repository.dailySet(day)).skip(done).toList();
    if (!mounted || remaining.isEmpty) return;
    final answers = await Navigator.of(context).push<List<RoundAnswer>>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          questions: remaining,
          alreadyAnswered: done,
          onLocked: (a) => _stats.recordAnswer(
            questionId: a.question.id,
            category: a.question.category,
            outcome: a.outcome,
            dailyDay: day,
            points: a.points,
          ),
        ),
      ),
    );
    if (!mounted || answers == null || !_stats.isDayComplete(day)) return;
    await _showDaySummary(day);
  });

  Future<void> _showDaySummary(int day) => Navigator.of(context).push(
    MaterialPageRoute<SummaryAction>(
      builder: (_) => SummaryScreen(
        results: _stats.dailyResults(day),
        hits: _stats.hits,
        answered: _stats.answered,
        shareText: _shareText(day),
      ),
    ),
  );

  Future<void> _playFree() => _guarded(() async {
    // Free play loops: round → summary → new round, until "Ana ekran".
    while (mounted) {
      final distance = await _repository.distanceQuestions();
      final round = buildFreeRound(
        bankPool: await _repository.freePlayPool(_today),
        generators: [
          (rng, accept) => distance.pick(rng, accept: (q, _, _) => accept(q)),
        ],
        seen: _stats.seenIds,
        rng: _rng,
      );
      if (!mounted) return;
      if (round.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.freePlayEmpty)));
        return;
      }
      final answers = await Navigator.of(context).push<List<RoundAnswer>>(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            questions: round,
            onLocked: (a) => _stats.recordAnswer(
              questionId: a.question.id,
              category: a.question.category,
              outcome: a.outcome,
              points: a.points,
            ),
          ),
        ),
      );
      if (!mounted || answers == null) return;
      final action = await Navigator.of(context).push<SummaryAction>(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            results: [for (final a in answers) (points: a.points, hit: a.hit)],
            hits: _stats.hits,
            answered: _stats.answered,
          ),
        ),
      );
      if (action != SummaryAction.newRound) return;
    }
  });

  void _openSettings() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  void _openStats() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StatsScreen(stats: _stats, today: _today),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _stats,
          builder: (context, _) {
            final today = _today;
            final number = puzzleNumber(today);
            // Scrolls only when the screen is too short for everything.
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _DayChip(
                                label: number > 0
                                    ? '#$number'
                                    : AppStrings.previewEdition,
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                onPressed: _openSettings,
                                tooltip: AppStrings.settings,
                                icon: const Icon(Icons.settings_rounded),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _openStats,
                                tooltip: AppStrings.stats,
                                icon: const Icon(Icons.bar_chart_rounded),
                              ),
                            ],
                          ),
                          Text(
                            AppStrings.appName,
                            style: textTheme.displayLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Center(child: RangeMark()),
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.tagline,
                            style: textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _StatsCard(stats: _stats, today: today),
                          const SizedBox(height: 16),
                          const Expanded(child: Landscape()),
                          const SizedBox(height: 16),
                          _TodayAction(
                            stats: _stats,
                            today: today,
                            loading: _loading,
                            onPlay: _playDaily,
                            onShowSummary: () => _showDaySummary(today),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _playFree,
                            icon: const Icon(Icons.all_inclusive_rounded),
                            label: const Text(AppStrings.freePlay),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.freePlayHint,
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "#42" (or "(deneme)") in a small pill.
class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onTertiaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The single main action for today's set.
class _TodayAction extends StatelessWidget {
  const _TodayAction({
    required this.stats,
    required this.today,
    required this.loading,
    required this.onPlay,
    required this.onShowSummary,
  });

  final StatsStore stats;
  final int today;
  final bool loading;
  final VoidCallback onPlay;
  final VoidCallback onShowSummary;

  @override
  Widget build(BuildContext context) {
    if (stats.isDayComplete(today)) {
      final total = totalPoints(stats.dailyResults(today));
      final good = Theme.of(context).extension<GameColors>()!.good;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: good),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${AppStrings.todayDone}: $total / $maxDailyPoints',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : onShowSummary,
            icon: const Icon(Icons.share_outlined),
            label: const Text(AppStrings.share),
          ),
        ],
      );
    }
    final done = stats.dailyResults(today).length;
    return FilledButton.icon(
      onPressed: loading ? null : onPlay,
      icon: const Icon(Icons.play_arrow_rounded, size: 28),
      label: Text(
        done == 0
            ? AppStrings.playToday
            : AppStrings.continueToday(done, questionsPerDay),
      ),
    );
  }
}

/// Streak, last score and calibration, with the calibration hint below.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.today});

  final StatsStore stats;
  final int today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<GameColors>()!;
    final last = stats.lastCompletedDay(today);
    final lastScore = last == null
        ? AppStrings.noValue
        : '${totalPoints(stats.dailyResults(last))}';
    final calibration = stats.answered == 0
        ? AppStrings.noValue
        : formatPercent(stats.hits / stats.answered);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        child: Column(
          children: [
            Row(
              children: [
                StatTile(
                  icon: Icons.local_fire_department_rounded,
                  color: colors.streak,
                  label: AppStrings.streak,
                  value: AppStrings.streakDays(stats.streak(today)),
                ),
                StatTile(
                  icon: Icons.emoji_events_rounded,
                  color: colors.partial,
                  label: AppStrings.lastScore,
                  value: lastScore,
                ),
                StatTile(
                  icon: Icons.track_changes_rounded,
                  color: colors.good,
                  label: AppStrings.calibration,
                  value: calibration,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              calibrationSummary(stats.hits, stats.answered),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
