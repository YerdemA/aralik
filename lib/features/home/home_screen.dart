import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/free_play.dart';
import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/share_text.dart';
import '../../core/strings.dart';
import '../../data/question_repository.dart';
import '../../data/stats_store.dart';
import '../../widgets/calibration_text.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';
import '../result/summary_screen.dart';

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
    points: _stats.dailyPoints(day),
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
    final done = _stats.dailyPoints(day).length;
    final remaining = (await _repository.dailySet(day)).skip(done).toList();
    if (!mounted || remaining.isEmpty) return;
    final answers = await Navigator.of(context).push<List<RoundAnswer>>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          questions: remaining,
          alreadyAnswered: done,
          onLocked: (a) => _stats.recordAnswer(
            questionId: a.question.id,
            hit: a.hit,
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
        points: _stats.dailyPoints(day),
        hits: _stats.hits,
        answered: _stats.answered,
        shareText: _shareText(day),
      ),
    ),
  );

  Future<void> _playFree() => _guarded(() async {
    // Free play loops: round → summary → new round, until "Ana ekran".
    while (mounted) {
      final round = buildFreeRound(
        pastBank: await _repository.practicePool(_today),
        generator: await _repository.distanceQuestions(),
        seen: _stats.seenIds,
        rng: _rng,
      );
      if (!mounted || round.isEmpty) return;
      final answers = await Navigator.of(context).push<List<RoundAnswer>>(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            questions: round,
            onLocked: (a) =>
                _stats.recordAnswer(questionId: a.question.id, hit: a.hit),
          ),
        ),
      );
      if (!mounted || answers == null) return;
      final action = await Navigator.of(context).push<SummaryAction>(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            points: [for (final a in answers) a.points],
            hits: _stats.hits,
            answered: _stats.answered,
          ),
        ),
      );
      if (action != SummaryAction.newRound) return;
    }
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _stats,
          builder: (context, _) {
            final today = _today;
            final number = puzzleNumber(today);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    AppStrings.appName,
                    style: textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    number > 0 ? '#$number' : AppStrings.previewEdition,
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _StatsRow(stats: _stats, today: today),
                  const SizedBox(height: 16),
                  Text(
                    calibrationSummary(_stats.hits, _stats.answered),
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  _TodayAction(
                    stats: _stats,
                    today: today,
                    loading: _loading,
                    onPlay: _playDaily,
                    onShowSummary: () => _showDaySummary(today),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loading ? null : _playFree,
                    child: const Text(AppStrings.freePlay),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.freePlayHint,
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
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
      final total = stats.dailyPoints(today).fold(0, (sum, p) => sum + p);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${AppStrings.todayDone}: $total / $maxDailyPoints',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
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
    final done = stats.dailyPoints(today).length;
    return FilledButton(
      onPressed: loading ? null : onPlay,
      child: Text(
        done == 0
            ? AppStrings.playToday
            : AppStrings.continueToday(done, questionsPerDay),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.today});

  final StatsStore stats;
  final int today;

  @override
  Widget build(BuildContext context) {
    final last = stats.lastCompletedDay(today);
    final lastScore = last == null
        ? AppStrings.noValue
        : '${stats.dailyPoints(last).fold(0, (sum, p) => sum + p)}';
    final calibration = stats.answered == 0
        ? AppStrings.noValue
        : formatPercent(stats.hits / stats.answered);
    return Row(
      children: [
        _Stat(
          label: AppStrings.streak,
          value: AppStrings.streakDays(stats.streak(today)),
        ),
        _Stat(label: AppStrings.lastScore, value: lastScore),
        _Stat(label: AppStrings.calibration, value: calibration),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
