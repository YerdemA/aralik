import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/question_timer.dart';
import '../../core/strings.dart';
import '../../data/question.dart';
import '../result/result_screen.dart';
import 'answer_input.dart';
import 'game_controller.dart';

/// Plays [questions] in order: guess → width → lock → result, per question.
/// Pops with the list of [RoundAnswer]s when the round is finished.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.questions,
    this.onLocked,
    this.alreadyAnswered = 0,
    this.startQuestion,
    this.timeLimit = dailyTimeLimit,
    this.now = DateTime.now,
    this.scaled = true,
  });

  /// Intervals and points follow each question's scale (the current rule).
  final bool scaled;

  final List<Question> questions;

  /// Questions of the same set answered in an earlier session; only shifts
  /// the "Soru 3 / 5" counter when a daily set is resumed.
  final int alreadyAnswered;

  /// Called right after each lock, e.g. to persist stats.
  final ValueChanged<RoundAnswer>? onLocked;

  /// Turns the countdown on (daily set). Called when the question at
  /// `position` (counting [alreadyAnswered]) appears; returns when it was
  /// first shown, so a resumed question keeps its earlier start. Null
  /// means no time limit (free play).
  final DateTime Function(int position)? startQuestion;

  /// Time per question when [startQuestion] is set.
  final Duration timeLimit;

  /// Clock, replaceable in tests.
  final DateTime Function() now;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _game = GameController(
    widget.questions,
    scaled: widget.scaled,
  );

  /// Time left on the current question; null without a time limit.
  final _left = ValueNotifier<Duration?>(null);
  Timer? _ticker;
  DateTime? _startedAt;

  static const _tickEvery = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    // After the first frame: a resumed question may already be out of time,
    // and timing out opens the result screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startClock());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _left.dispose();
    _game.dispose();
    super.dispose();
  }

  void _startClock() {
    final start = widget.startQuestion;
    if (!mounted || start == null) return;
    _startedAt = start(widget.alreadyAnswered + _game.index);
    _ticker = Timer.periodic(_tickEvery, (_) => _tick());
    _tick();
  }

  void _tick() {
    final left = timeLeft(
      startedAt: _startedAt!,
      now: widget.now(),
      limit: widget.timeLimit,
    );
    final before = _left.value;
    _left.value = left;
    if (before != null && before > timeWarning && left <= timeWarning) {
      HapticFeedback.lightImpact();
    }
    if (left == Duration.zero) _finish(timedOut: true);
  }

  Future<void> _finish({required bool timedOut}) async {
    if (_game.isLocked) return;
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.mediumImpact();
    final answer = timedOut ? _game.timeOut() : _game.lock();
    widget.onLocked?.call(answer);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(answer: answer, isLast: _game.isLast),
      ),
    );
    if (!mounted) return;
    if (_game.isLast) {
      Navigator.of(context).pop(_game.answers);
    } else {
      _game.next();
      _startClock();
    }
  }

  Future<void> _lock() => _finish(timedOut: false);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.questionProgress(
              widget.alreadyAnswered + _game.index + 1,
              widget.alreadyAnswered + _game.questions.length,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: AppStrings.quit,
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            ValueListenableBuilder(
              valueListenable: _left,
              builder: (context, left, _) => left == null
                  ? const SizedBox.shrink()
                  : Countdown(left: left, limit: widget.timeLimit),
            ),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(12),
            child: _Progress(
              done: widget.alreadyAnswered + _game.answers.length,
              total: widget.alreadyAnswered + _game.questions.length,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionCard(question: _game.question),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _game.phase == GamePhase.guess
                        ? GuessStep(key: const ValueKey('guess'), game: _game)
                        : WidthStep(
                            key: const ValueKey('width'),
                            game: _game,
                            onLock: _lock,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment per question; locked ones fill in.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i < done
                      ? scheme.tertiary
                      : i == done
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
