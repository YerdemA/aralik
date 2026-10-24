import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/free_play.dart';
import '../../core/strings.dart';
import '../../data/question.dart';
import '../../data/question_repository.dart';
import '../../data/stats_store.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';

/// Placeholder home screen: daily set + free play. The full one (streak,
/// calibration summary) is built on day 4.
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

  int get _today => dayIndexFor(DateTime.now());

  Future<void> _playDaily() => _play(() => widget.repository.dailySet(_today));

  Future<void> _playFree() => _play(() async {
    final repository = widget.repository;
    return buildFreeRound(
      pastBank: await repository.practicePool(_today),
      generator: await repository.distanceQuestions(),
      seen: widget.stats.seenIds,
      rng: _rng,
    );
  });

  Future<void> _play(Future<List<Question>> Function() load) async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final questions = await load();
      if (!mounted || questions.isEmpty) return;
      final answers = await navigator.push<List<RoundAnswer>>(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            questions: questions,
            onLocked: (a) => widget.stats.recordAnswer(
              questionId: a.question.id,
              hit: a.hit,
            ),
          ),
        ),
      );
      if (answers != null && answers.isNotEmpty) {
        final total = answers.fold(0, (sum, a) => sum + a.points);
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppStrings.roundTotal(total, answers.length * 100)),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.loadError)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.appName,
                style: textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.tagline,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _loading ? null : _playDaily,
                child: const Text(AppStrings.playToday),
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
        ),
      ),
    );
  }
}
