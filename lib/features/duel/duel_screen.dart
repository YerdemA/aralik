import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/duel.dart';
import '../../core/number_format.dart';
import '../../core/question_timer.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/duel_client.dart';
import '../../data/question.dart';
import '../../data/question_repository.dart';
import '../../data/stats_store.dart';
import '../../widgets/interval_bar.dart';
import '../game/answer_input.dart';
import '../game/game_controller.dart';

/// One live duel in room [code]: waiting for the friend, five questions
/// against the clock, each revealed with both intervals, then the result.
/// Without a [code] it first finds a random opponent in the lobby.
///
/// Pops with true for "Yeni düello", otherwise with null.
class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    required this.service,
    required this.repository,
    required this.stats,
    required this.code,
    required this.name,
  });

  final DuelService service;
  final QuestionRepository repository;
  final StatsStore stats;

  /// The friend's room; null for a random opponent.
  final String? code;
  final String name;

  bool get isRandom => code == null;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  final _match = DuelMatch();
  DuelSession? _session;
  Map<String, Question> _bank = const {};
  GameController? _game;

  /// Time left on the open question, counted down here from the room's
  /// "question" message.
  final _left = ValueNotifier<Duration?>(null);
  Timer? _ticker;
  DateTime? _deadline;

  /// Pressed "Devam" on the revealed question with this index.
  int _readyFor = -1;

  /// Pressed "Sonucu gör" after the last reveal.
  bool _resultShown = false;

  /// Set when the room's questions are missing from this app's bank, or the
  /// search or the opponent did not work out.
  String? _localError;

  /// The lobby search while looking for a random opponent.
  DuelSearch? _search;
  bool _searching = false;

  /// A random opponent who was matched but never came to the room.
  Timer? _noShow;
  static const _noShowAfter = Duration(seconds: 20);

  static const _tickEvery = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    final code = widget.code;
    if (code != null) _match.expectCode(code);
    _match.addListener(_onMatch);
    _connect();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noShow?.cancel();
    _left.dispose();
    _match.removeListener(_onMatch);
    _search?.cancel();
    _session?.close();
    _game?.dispose();
    _match.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final bank = await widget.repository.load();
      _bank = {for (final q in bank) q.id: q};
      var code = widget.code;
      if (code == null) {
        setState(() => _searching = true);
        final search = await widget.service.findOpponent(
          name: widget.name,
          bankSize: bank.length,
        );
        if (!mounted) {
          await search.cancel();
          return;
        }
        _search = search;
        code = await search.code;
        if (!mounted) return;
        setState(() => _searching = false);
        _noShow = Timer(_noShowAfter, () {
          if (mounted && _match.phase == DuelPhase.waiting) {
            _session?.close();
            setState(() => _localError = AppStrings.duelNoShow);
          }
        });
      }
      final session = await widget.service.join(
        code: code,
        name: widget.name,
        bankSize: bank.length,
        match: _match,
      );
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
    } on DuelRefused catch (e) {
      if (mounted) _match.handle(DuelError(e.code));
    } on Object {
      if (mounted) _match.handle(const DuelError('offline'));
    }
  }

  void _onMatch() {
    final ids = _match.questionIds;
    if (_game == null && ids.isNotEmpty) {
      final questions = [for (final id in ids) ?_bank[id]];
      if (questions.length != ids.length) {
        _localError = AppStrings.duelMissingQuestions;
        _session?.close();
      } else {
        _game = GameController(questions);
      }
    }
    final game = _game;
    if (game != null && _match.phase == DuelPhase.question) {
      _openQuestion(game, _match.index);
    }
    if (_match.phase != DuelPhase.question) _stopClock();
    if (_match.phase == DuelPhase.reveal || _match.phase == DuelPhase.over) {
      // Revealed before this phone locked (late or lost message): keep the
      // input in step without sending anything.
      if (game != null &&
          !game.isLocked &&
          _match.results.length > game.index) {
        game.timeOut();
      }
    }
    setState(() {});
  }

  void _openQuestion(GameController game, int index) {
    if (_deadline != null && game.index == index && !game.isLocked) return;
    while (game.index < index) {
      if (!game.isLocked) game.timeOut();
      game.next();
    }
    if (game.isLocked) return;
    _deadline = DateTime.now().add(_match.timeLeft);
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickEvery, (_) => _tick());
    _tick();
  }

  void _stopClock() {
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    _left.value = null;
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final left = deadline.difference(DateTime.now());
    final before = _left.value;
    _left.value = left.isNegative ? Duration.zero : left;
    if (before != null && before > timeWarning && left <= timeWarning) {
      HapticFeedback.lightImpact();
    }
    if (left <= Duration.zero) _lock(timedOut: true);
  }

  void _lock({required bool timedOut}) {
    final game = _game;
    if (game == null || game.isLocked) return;
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.mediumImpact();
    final answer = timedOut ? game.timeOut() : game.lock();
    _session?.lock(_match.index, low: answer.low, high: answer.high);
    // Duel answers count like free play: calibration, and never again in
    // free play.
    widget.stats.recordAnswer(
      questionId: answer.question.id,
      category: answer.question.category,
      outcome: answer.outcome,
      points: answer.points,
    );
    setState(() {});
  }

  void _next() {
    setState(() => _readyFor = _match.index);
    _session?.next(_match.index);
  }

  Future<bool> _confirmQuit() async {
    final phase = _match.phase;
    if (phase != DuelPhase.question && phase != DuelPhase.reveal) return true;
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.duelQuitTitle),
        content: const Text(AppStrings.duelQuitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.duelStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.quit),
          ),
        ],
      ),
    );
    return quit ?? false;
  }

  Future<void> _quit() async {
    if (await _confirmQuit() && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final Widget body;
    final error =
        _localError ??
        (_match.phase == DuelPhase.failed
            ? AppStrings.duelErrorText(_match.error ?? '')
            : null);
    if (error != null) {
      body = _Message(
        icon: Icons.wifi_off_rounded,
        text: error,
        button: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.next),
        ),
      );
    } else if (_searching) {
      body = const _Message(
        icon: Icons.person_search_rounded,
        text: AppStrings.duelSearching,
        busy: true,
        hint: AppStrings.duelSearchingHint,
      );
    } else if (_match.phase == DuelPhase.connecting ||
        (widget.isRandom && _match.phase == DuelPhase.waiting)) {
      body = _Message(
        icon: Icons.sync_rounded,
        text: widget.isRandom
            ? AppStrings.duelFound
            : AppStrings.duelConnecting,
        busy: true,
      );
    } else if (_match.phase == DuelPhase.waiting) {
      body = _WaitingRoom(code: _match.code ?? widget.code ?? '');
    } else if (game == null) {
      body = const _Message(
        icon: Icons.sync_rounded,
        text: AppStrings.duelConnecting,
        busy: true,
      );
    } else if (_match.phase == DuelPhase.question) {
      body = _QuestionView(game: game, onLock: () => _lock(timedOut: false));
    } else if (_match.phase == DuelPhase.reveal ||
        (_match.phase == DuelPhase.over &&
            !_resultShown &&
            _match.results.isNotEmpty &&
            !_match.opponentLeft)) {
      final over = _match.phase == DuelPhase.over;
      body = _RevealView(
        question: game.question,
        match: _match,
        buttonLabel: over || _match.isLastQuestion
            ? AppStrings.duelSeeResult
            : AppStrings.next,
        onNext: over
            ? () => setState(() => _resultShown = true)
            : _readyFor == _match.index
            ? null
            : _next,
      );
    } else {
      body = _ResultView(match: _match);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: AppStrings.quit,
            onPressed: _quit,
          ),
          title: _match.questionIds.isEmpty
              ? const Text(AppStrings.duel)
              : _ScoreLine(match: _match),
          actions: [
            if (_match.phase == DuelPhase.question)
              _OpponentStatus(locked: _match.opponentLocked),
            ValueListenableBuilder(
              valueListenable: _left,
              builder: (context, left, _) => left == null
                  ? const SizedBox.shrink()
                  : Countdown(left: left, limit: _match.questionTime),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey((_match.phase, _match.index, _resultShown)),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Sen 120 · 85 Bora" in the app bar.
class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.match});

  final DuelMatch match;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${AppStrings.duelYou} ${match.myTotal}  ·  '
        '${match.opponentTotal} ${match.opponentName}',
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.button,
    this.busy = false,
    this.hint,
  });

  final IconData icon;
  final String text;
  final Widget? button;
  final bool busy;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        if (busy)
          const Center(child: CircularProgressIndicator())
        else
          Icon(icon, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          text,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const Spacer(),
        ?button,
      ],
    );
  }
}

/// The room code, big, with the share button.
class _WaitingRoom extends StatelessWidget {
  const _WaitingRoom({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          AppStrings.duelCodeLabel,
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Palette.heroTop, Palette.heroBottom],
            ),
          ),
          child: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.duelWaiting,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.duelWaitingHint,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: AppStrings.duelInvite(code)),
          ),
          icon: const Icon(Icons.share_rounded),
          label: const Text(AppStrings.duelShareCode),
        ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.game, required this.onLock});

  final GameController game;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionCard(question: game.question),
          Expanded(
            child: game.isLocked
                ? const _Message(
                    icon: Icons.lock_rounded,
                    text: AppStrings.duelWaitingOpponent,
                    busy: true,
                  )
                : game.phase == GamePhase.guess
                ? GuessStep(key: const ValueKey('guess'), game: game)
                : WidthStep(
                    key: const ValueKey('width'),
                    game: game,
                    onLock: onLock,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The opponent's state as a small icon: thinking, or locked.
class _OpponentStatus extends StatelessWidget {
  const _OpponentStatus({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: locked
          ? AppStrings.duelOpponentLocked
          : AppStrings.duelOpponentThinking,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (locked ? scheme.tertiary : scheme.outline).withValues(
            alpha: .14,
          ),
        ),
        child: Icon(
          locked ? Icons.lock_rounded : Icons.hourglass_top_rounded,
          size: 18,
          color: locked ? scheme.tertiary : scheme.outline,
        ),
      ),
    );
  }
}

/// The answer and both intervals of the question just revealed.
class _RevealView extends StatelessWidget {
  const _RevealView({
    required this.question,
    required this.match,
    required this.buttonLabel,
    required this.onNext,
  });

  final Question question;
  final DuelMatch match;
  final String buttonLabel;

  /// Null while waiting for the opponent to go on.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isYear = question.kind == QuestionKind.year;
    final answer = isYear
        ? formatYear(question.answer.round())
        : [
            formatNumber(question.answer, maxDecimals: 1),
            if (question.unit.isNotEmpty) question.unit,
          ].join(' ');
    final last = match.results.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionCard(question: question),
        const SizedBox(height: 16),
        Text(
          AppStrings.duelAnswer,
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(answer, style: theme.textTheme.displayMedium),
        ),
        const SizedBox(height: 16),
        _PlayerResult(
          name: AppStrings.duelYou,
          result: last.me,
          question: question,
        ),
        const SizedBox(height: 12),
        _PlayerResult(
          name: match.opponentName,
          result: last.opponent,
          question: question,
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onNext,
          icon: onNext == null
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: Text(buttonLabel),
        ),
      ],
    );
  }
}

class _PlayerResult extends StatelessWidget {
  const _PlayerResult({
    required this.name,
    required this.result,
    required this.question,
  });

  final String name;
  final DuelResult result;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.extension<GameColors>()!.forTier(
      ResultTier.of(points: result.points, hit: result.hit),
    );
    final isYear = question.kind == QuestionKind.year;
    final low = result.low;
    final high = result.high;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${result.points > 0 ? '+' : ''}${result.points}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              low == null || high == null
                  ? AppStrings.duelNoInterval
                  : formatRange(low, high, unit: question.unit, isYear: isYear),
              style: theme.textTheme.bodyMedium,
            ),
            if (low != null && high != null) ...[
              const SizedBox(height: 6),
              IntervalBar(
                isYear: isYear,
                low: low,
                high: high,
                answer: question.answer,
                bandColor: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Win, loss or draw, with both totals.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.match});

  final DuelMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = match.outcome;
    final title = switch (outcome) {
      DuelOutcome.win => AppStrings.duelWin,
      DuelOutcome.loss => AppStrings.duelLoss,
      _ => AppStrings.duelDraw,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(
          outcome == DuelOutcome.win
              ? Icons.emoji_events_rounded
              : Icons.sports_score_rounded,
          size: 72,
          color: outcome == DuelOutcome.win
              ? Palette.sun
              : theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        if (match.opponentLeft) ...[
          const SizedBox(height: 6),
          Text(
            AppStrings.duelOpponentLeft,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _Total(name: AppStrings.duelYou, points: match.myTotal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Total(
                name: match.opponentName,
                points: match.opponentTotal,
              ),
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.replay_rounded),
          label: const Text(AppStrings.duelPlayAgain),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.duelHome),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.name, required this.points});

  final String name;
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              name,
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('$points', style: theme.textTheme.displaySmall),
          ],
        ),
      ),
    );
  }
}
