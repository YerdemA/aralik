import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/coach_tour.dart';
import '../../data/settings_store.dart';
import '../../core/answer_scale.dart';
import '../../core/question_timer.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../data/question.dart';
import '../../data/sound.dart';
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
    this.rule = ScoreRule.refined,
    this.scale,
    this.minPoints = minPointsPerQuestion,
    this.settings,
  });

  /// For the first-question tour (shown once); null shows none.
  final SettingsStore? settings;

  /// Each question's scale by math mode's rule; see [GameController.scale].
  final AnswerScale Function(Question)? scale;

  /// The lowest a question scores; 0 in math mode.
  final int minPoints;

  /// The scoring rule of the round (answer_scale.dart).
  final ScoreRule rule;

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
    rule: widget.rule,
    scale: widget.scale,
    minPoints: widget.minPoints,
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
    _game.addListener(_onGame);
  }

  final _questionKey = GlobalKey();
  final _clockKey = GlobalKey();
  final _padKey = GlobalKey();
  final _rangeKey = GlobalKey();
  final _lockKey = GlobalKey();
  bool _touring = false;

  /// The first time ever: the guess is shown around before the clock
  /// starts (a daily question's start is recorded only then).
  Future<void> _begin() async {
    final settings = widget.settings;
    if (settings != null && !settings.tourSeen(TourPart.guess) && mounted) {
      await settings.markTourSeen(TourPart.guess);
      _touring = true;
      if (!mounted) return;
      // The clock shows its full time, still, while it is explained.
      if (widget.startQuestion != null) {
        _left.value = widget.timeLimit;
        await WidgetsBinding.instance.endOfFrame; // so it can be pointed at
        if (!mounted) return;
      }
      await showCoachTour(context, [
        CoachStep(
          target: _questionKey,
          title: AppStrings.tourQuestionTitle,
          body: AppStrings.tourQuestion,
        ),
        // Left out without a clock (free play): it has no size.
        CoachStep(
          target: _clockKey,
          title: AppStrings.tourClockTitle,
          body: AppStrings.tourClock,
        ),
        CoachStep(
          target: _padKey,
          title: AppStrings.tourPadTitle,
          body: AppStrings.tourPad,
        ),
      ]);
      _touring = false;
    }
    _startClock();
  }

  /// The first interval ever: the slider and the lock are shown around;
  /// the clock waits meanwhile.
  void _onGame() {
    final settings = widget.settings;
    if (settings == null ||
        _touring ||
        _game.phase != GamePhase.width ||
        settings.tourSeen(TourPart.range)) {
      return;
    }
    _touring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rangeTour(settings));
  }

  Future<void> _rangeTour(SettingsStore settings) async {
    await settings.markTourSeen(TourPart.range);
    if (!mounted) return;
    final running = _ticker != null;
    _ticker?.cancel();
    _ticker = null;
    final pausedAt = widget.now();
    // Let the interval step fade in before pointing at it.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await showCoachTour(context, [
      CoachStep(
        target: _rangeKey,
        title: AppStrings.tourRangeTitle,
        body: AppStrings.tourRange,
      ),
      CoachStep(
        target: _lockKey,
        title: AppStrings.tourLockTitle,
        body: AppStrings.tourLock,
      ),
    ]);
    _touring = false;
    if (!mounted || !running || _game.isLocked) return;
    // The time the tour took is given back.
    _startedAt = _startedAt?.add(widget.now().difference(pausedAt));
    _ticker = Timer.periodic(_tickEvery, (_) => _tick());
    _tick();
  }

  @override
  void dispose() {
    _game.removeListener(_onGame);
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
    if (clockTicks(before, left)) Sounds.play(Sfx.tick);
    if (left == Duration.zero) _finish(timedOut: true);
  }

  Future<void> _finish({required bool timedOut}) async {
    if (_game.isLocked) return;
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.mediumImpact();
    final answer = timedOut ? _game.timeOut() : _game.lock();
    if (!timedOut) Sounds.play(Sfx.lock);
    Sounds.play(Sfx.of(answer.tier));
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
            KeyedSubtree(
              key: _clockKey,
              child: ValueListenableBuilder(
                valueListenable: _left,
                builder: (context, left, _) => left == null
                    ? const SizedBox.shrink()
                    : Countdown(left: left, limit: widget.timeLimit),
              ),
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
                KeyedSubtree(
                  key: _questionKey,
                  child: QuestionCard(question: _game.question),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _game.phase == GamePhase.guess
                        ? GuessStep(
                            key: const ValueKey('guess'),
                            game: _game,
                            padKey: _padKey,
                          )
                        : WidthStep(
                            key: const ValueKey('width'),
                            game: _game,
                            onLock: _lock,
                            rangeKey: _rangeKey,
                            lockKey: _lockKey,
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
