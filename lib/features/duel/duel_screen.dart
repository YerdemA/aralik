import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/math/math_question.dart';
import '../../core/math/math_problem.dart';
import '../../core/answer_scale.dart';
import '../../core/duel.dart';
import '../../core/number_format.dart';
import '../../core/question_timer.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/moderation.dart';
import '../../data/duel_client.dart';
import '../../data/pending_match.dart';
import '../../data/question.dart';
import '../../data/question_repository.dart';
import '../../data/sound.dart';
import '../../data/stats_store.dart';
import '../../widgets/player_actions.dart';
import '../../widgets/duelist.dart';
import '../../widgets/interval_bar.dart';
import '../../widgets/philosopher.dart';
import '../../widgets/share_origin.dart';
import '../game/answer_input.dart';
import '../game/game_controller.dart';
import 'duel_search_view.dart';

/// One live duel in room [code]: waiting for the friend, five questions
/// against the clock, each revealed with both intervals, then the result.
/// Without a [code] it first finds a random opponent in the lobby. With
/// [rejoin] it goes back to a duel the player left (see [PendingMatch]).
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
    this.now = DateTime.now,
    this.rule = ScoreRule.refined,
    this.rejoin,
    this.pending,
    this.math = false,
  });

  /// A math duel: a random opponent is looked for in math's own lobby.
  /// (The questions tell math apart by their ids, also when coming back.)
  final bool math;

  /// This player's secret to go back to a duel in room [code] they left.
  final String? rejoin;

  /// Where the duel in progress is kept for going back to it after leaving
  /// the app; null keeps nothing (tests).
  final PendingMatchStore? pending;

  /// The scoring rule of today's duels; matches the room's.
  final ScoreRule rule;

  /// Clock, replaceable in tests.
  final DateTime Function() now;

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

  /// Seconds until the room moves on from a revealed question by itself.
  final _nextIn = ValueNotifier<int?>(null);
  Timer? _revealTicker;
  int _revealCounted = -1;

  /// Pressed "Sonucu gör" after the last reveal.
  bool _resultShown = false;

  /// While the opponent's connection is gone: when their time runs out.
  DateTime? _awayUntil;

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

  /// Keeps the duel in [DuelScreen.pending] while it runs.
  late final _keeper = PendingMatchKeeper(
    widget.pending,
    kind: PendingKind.duel,
    now: widget.now,
  );
  Timer? _keepTicker;

  /// Gave up: nothing to go back to.
  bool _gaveUp = false;

  /// The round this screen is showing ([DuelMatch.round]): a rematch starts
  /// a new one in the same room.
  int _roundSeen = 1;

  /// Questions of earlier rounds; disposed with the screen (the last view
  /// may still be fading out when a rematch starts).
  final List<GameController> _oldGames = [];

  /// The opponent's rematch request was felt already.
  bool _offerFelt = false;

  bool get _inPlay =>
      _match.phase == DuelPhase.question || _match.phase == DuelPhase.reveal;

  @override
  void initState() {
    super.initState();
    final code = widget.code;
    if (code != null) _match.expectCode(code);
    _match.addListener(_onMatch);
    _keepTicker = Timer.periodic(const Duration(seconds: 3), (_) => _keep());
    _connect();
  }

  /// Saves the duel in progress (to go back to it after leaving the app)
  /// or forgets it once it is over.
  void _keep({bool now = false}) {
    if (_gaveUp) return;
    final code = _match.code;
    final rejoin = _match.rejoin;
    if (_inPlay && code != null && rejoin != null) {
      // While the connection is gone the room's minute is running: the
      // saved deadline stays as it was.
      if (_match.reconnecting) return;
      _keeper.playing(
        code: code,
        rejoin: rejoin,
        name: widget.name,
        window: _match.awayBudget,
        force: now,
      );
    } else if (_match.phase == DuelPhase.over ||
        (_match.phase == DuelPhase.failed && _match.error != 'offline')) {
      _keeper.over(rejoin: rejoin ?? widget.rejoin);
    }
  }

  @override
  void dispose() {
    // Left mid-duel ("Çık"): the room keeps the seat for a minute; the home
    // screen offers to go back.
    _keep(now: true);
    _keepTicker?.cancel();
    _ticker?.cancel();
    _noShow?.cancel();
    _revealTicker?.cancel();
    _nextIn.dispose();
    _left.dispose();
    _match.removeListener(_onMatch);
    _search?.cancel();
    _session?.close();
    _game?.dispose();
    for (final game in _oldGames) {
      game.dispose();
    }
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
          math: widget.math,
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
        _match.expectCode(code);
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
        rejoin: widget.rejoin,
      );
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
    } on DuelRefused catch (e) {
      if (mounted) _match.handle(DuelError(e.code));
    } on DuelException catch (e) {
      if (mounted) {
        _match.handle(
          DuelError(
            e.failure == DuelFailure.server ? 'unavailable' : 'offline',
          ),
        );
      }
    } on Object {
      if (mounted) _match.handle(const DuelError('offline'));
    }
  }

  /// Sounds already played: the start, each reveal, the outcome.
  bool _startHeard = false;
  int _revealsHeard = 0;
  bool _outcomeHeard = false;

  /// The last reveal stays on screen after the room is over, until
  /// "Sonucu gör".
  bool get _showsLastReveal =>
      _match.phase == DuelPhase.over &&
      !_resultShown &&
      _match.results.isNotEmpty &&
      !_match.opponentLeft;

  void _playSounds() {
    final match = _match;
    if (!_startHeard && match.phase == DuelPhase.question) {
      _startHeard = true;
      Sounds.play(Sfx.duelStart);
    }
    // One sound per revealed question, for this player's own result.
    if (match.results.length > _revealsHeard &&
        (match.phase == DuelPhase.reveal || _showsLastReveal)) {
      _revealsHeard = match.results.length;
      final me = match.results.last.me;
      Sounds.play(Sfx.of(ResultTier.of(points: me.points, hit: me.hit)));
    }
    if (!_outcomeHeard && match.phase == DuelPhase.over && !_showsLastReveal) {
      _outcomeHeard = true;
      Sounds.play(switch (match.outcome ?? DuelOutcome.draw) {
        DuelOutcome.win => Sfx.duelWin,
        DuelOutcome.loss => Sfx.duelLoss,
        DuelOutcome.draw => Sfx.duelDraw,
      });
    }
  }

  /// A rematch: the same room starts again with new questions; everything
  /// this screen kept of the last duel goes.
  void _startRound() {
    if (_game case final game?) _oldGames.add(game);
    _game = null;
    _readyFor = -1;
    _resultShown = false;
    _startHeard = false;
    _revealsHeard = 0;
    _outcomeHeard = false;
    _offerFelt = false;
    _clockSeen = -1;
    _awayUntil = null;
    _gaveUp = false;
    _stopClock();
    _revealTicker?.cancel();
    _revealTicker = null;
    _revealCounted = -1;
    _nextIn.value = null;
  }

  void _onMatch() {
    if (_match.round != _roundSeen) {
      _roundSeen = _match.round;
      _startRound();
    }
    if (_match.rematch == RematchState.offered && !_offerFelt) {
      _offerFelt = true;
      HapticFeedback.mediumImpact();
      Sounds.play(Sfx.duelStart);
    }
    _keep();
    _playSounds();
    final ids = _match.questionIds;
    if (_game == null && ids.isNotEmpty) {
      // Math duels' questions are made from their ids, not looked up.
      final questions = [
        for (final id in ids)
          ?_bank[id] ??
              switch (mathProblemFromId(id)) {
                final p? => mathQuestion(p),
                null => null,
              },
      ];
      if (questions.length != ids.length) {
        _localError = AppStrings.duelMissingQuestions;
        _session?.close();
      } else {
        final math = questions.any((q) => q.category == QuestionCategory.math);
        _game = GameController(
          questions,
          rule: widget.rule,
          scale: math ? mathScaleOf : null,
          minPoints: math ? mathMinPoints : minPointsPerQuestion,
        );
      }
    }
    final game = _game;
    // Someone's connection dropped: the room stopped the clock, so does
    // the app; it starts again with the time the room gives back.
    if (_match.paused) {
      _stopClock();
    } else if (game != null && _match.phase == DuelPhase.question) {
      _openQuestion(game, _match.index);
      // Back after the app was closed, with this question already locked:
      // the input shows it as done (the room has the answer).
      if (_match.myLocked && !game.isLocked && game.index == _match.index) {
        _stopClock();
        game.timeOut();
      }
    }
    if (_match.phase != DuelPhase.question) _stopClock();
    if (_match.opponentAway) {
      _awayUntil ??= widget.now().add(_match.awayLeft);
    } else {
      _awayUntil = null;
    }
    _countReveal();
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

  /// The room's clock this screen last started from ([DuelMatch.clock]).
  int _clockSeen = -1;

  void _openQuestion(GameController game, int index) {
    // Same question, same clock: keep counting. A new clock (back after a
    // drop) takes the time the room says is left.
    if (_deadline != null &&
        game.index == index &&
        !game.isLocked &&
        _clockSeen == _match.clock) {
      return;
    }
    _clockSeen = _match.clock;
    while (game.index < index) {
      if (!game.isLocked) game.timeOut();
      game.next();
    }
    if (game.isLocked) return;
    _deadline = widget.now().add(_match.timeLeft);
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickEvery, (_) => _tick());
    _tick();
  }

  /// Counts down to the next question while a question is revealed.
  void _countReveal() {
    final total =
        _match.nextIn ?? (_match.isLastQuestion ? null : duelRevealWait);
    if (_match.phase != DuelPhase.reveal || total == null || _match.paused) {
      _revealTicker?.cancel();
      _revealTicker = null;
      _nextIn.value = null;
      _revealCounted = -1;
      return;
    }
    // Counted again when the room sets the clock again (after a pause).
    if (_revealCounted == _match.clock) return;
    _revealCounted = _match.clock;
    final until = widget.now().add(total);
    void tick() {
      final left = until.difference(widget.now());
      _nextIn.value = left.isNegative ? 0 : secondsShown(left);
    }

    _revealTicker?.cancel();
    _revealTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      tick();
    });
    tick();
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
    final left = deadline.difference(widget.now());
    final before = _left.value;
    _left.value = left.isNegative ? Duration.zero : left;
    if (before != null && before > timeWarning && left <= timeWarning) {
      HapticFeedback.lightImpact();
    }
    if (clockTicks(before, left)) Sounds.play(Sfx.tick);
    if (left <= Duration.zero) _lock(timedOut: true);
  }

  void _lock({required bool timedOut}) {
    final game = _game;
    if (game == null || game.isLocked) return;
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.mediumImpact();
    final answer = timedOut ? game.timeOut() : game.lock();
    if (!timedOut) Sounds.play(Sfx.lock);
    _session?.lock(_match.index, low: answer.low, high: answer.high);
    // Duel answers count like free play: calibration, and never again in
    // free play.
    if (answer.question.category == QuestionCategory.math) {
      // Math counts in its own calibration and may come again.
      widget.stats.recordMathAnswer(hit: answer.hit);
    } else {
      widget.stats.recordAnswer(
        questionId: answer.question.id,
        category: answer.question.category,
        outcome: answer.outcome,
        points: answer.points,
      );
    }
    setState(() {});
  }

  void _next() {
    setState(() => _readyFor = _match.index);
    _session?.next(_match.index);
  }

  Future<_Quit> _confirmQuit() async {
    if (!_inPlay) return _Quit.leave;
    final quit = await showDialog<_Quit>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.duelQuitTitle),
        content: const Text(AppStrings.duelQuitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Quit.stay),
            child: const Text(AppStrings.duelStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Quit.resign),
            child: const Text(AppStrings.duelResign),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Quit.leave),
            child: const Text(AppStrings.quit),
          ),
        ],
      ),
    );
    return quit ?? _Quit.stay;
  }

  Future<void> _quit() async {
    final choice = await _confirmQuit();
    if (!mounted || choice == _Quit.stay) return;
    if (choice == _Quit.resign && _inPlay) {
      _gaveUp = true;
      _keeper.over(rejoin: _match.rejoin);
      _session?.resign();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final Widget body;
    final error =
        _localError ??
        (_match.phase == DuelPhase.failed
            ? (widget.rejoin != null &&
                      const {
                        'no_room',
                        'room_closed',
                        'expired',
                      }.contains(_match.error)
                  ? AppStrings.duelEnded
                  : AppStrings.duelErrorText(_match.error ?? ''))
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
      body = DuelSearchView(name: widget.name, math: widget.math);
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
    } else if (_match.phase == DuelPhase.reveal || _showsLastReveal) {
      final over = _match.phase == DuelPhase.over;
      body = _RevealView(
        question: game.question,
        match: _match,
        buttonLabel: over || _match.isLastQuestion
            ? AppStrings.duelSeeResult
            : _readyFor == _match.index
            ? AppStrings.duelWaitingOther
            : AppStrings.next,
        onNext: over
            ? () {
                setState(() => _resultShown = true);
                _playSounds();
              }
            : _readyFor == _match.index
            ? null
            : _next,
        nextIn: over ? null : _nextIn,
      );
    } else {
      body = _ResultView(
        match: _match,
        onRematch: () => _session?.rematch(),
        onDecline: () => _session?.declineRematch(),
      );
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
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScoreLine(match: _match),
                    if (_match.index >= 0 &&
                        _resultShown == false &&
                        _match.phase != DuelPhase.over)
                      Text(
                        AppStrings.questionProgress(
                          _match.index + 1,
                          _match.questionIds.length,
                        ),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey((
                      _match.round,
                      _match.phase,
                      _match.index,
                      _resultShown,
                    )),
                    child: body,
                  ),
                ),
              ),
              // The opponent dropped during a question: it goes on; a note
              // says so without covering it.
              if (_match.opponentAway &&
                  !_match.paused &&
                  !_match.reconnecting &&
                  _match.phase == DuelPhase.question &&
                  error == null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: _AwayNote(
                    name: Moderation.instance.shown(_match.opponentName),
                  ),
                ),
              if ((_match.paused || _match.reconnecting) && error == null)
                Positioned.fill(
                  child: _PausedCover(
                    reconnecting: _match.reconnecting,
                    opponent: Moderation.instance.shown(_match.opponentName),
                    awayUntil: _awayUntil,
                    now: widget.now,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The close button mid-duel: stay, give up (the opponent wins now), or
/// leave (the room waits a minute; the home screen offers to go back).
enum _Quit { stay, resign, leave }

/// "Sen 120 · 85 Bora" in the app bar, each side in its player's colour.
class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.match});

  final DuelMatch match;

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(
      fontWeight: FontWeight.w800,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${AppStrings.duelYou} ${match.myTotal}',
              style: bold.copyWith(color: Palette.duelMe),
            ),
            const TextSpan(text: '  ·  '),
            TextSpan(
              text:
                  '${match.opponentTotal} ${Moderation.instance.shown(match.opponentName)}',
              style: bold.copyWith(color: Palette.duelOpponent),
            ),
          ],
        ),
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
  });

  final IconData icon;
  final String text;
  final Widget? button;
  final bool busy;

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
            ShareParams(
              text: AppStrings.duelInvite(code),
              sharePositionOrigin: shareOrigin(context),
            ),
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
    this.nextIn,
  });

  final Question question;
  final DuelMatch match;
  final String buttonLabel;

  /// Null while waiting for the opponent to go on.
  final VoidCallback? onNext;

  /// Seconds until the next question comes by itself; null to show none.
  final ValueListenable<int?>? nextIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isYear = question.kind == QuestionKind.year;
    final answer = isYear
        ? formatYear(question.answer.round())
        : [
            formatNumber(question.answer, maxDecimals: 3),
            if (question.unit.isNotEmpty) question.unit,
          ].join(' ');
    final last = match.results.last;
    // Everything but the button scrolls, so a long question fits a small
    // screen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 12),
                _PlayerResult(
                  name: AppStrings.duelYou,
                  colour: Palette.duelMe,
                  result: last.me,
                  question: question,
                ),
                const SizedBox(height: 10),
                _PlayerResult(
                  name: Moderation.instance.shown(match.opponentName),
                  colour: Palette.duelOpponent,
                  result: last.opponent,
                  question: question,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
        if (nextIn != null)
          ValueListenableBuilder<int?>(
            valueListenable: nextIn!,
            builder: (context, seconds, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                seconds == null ? '' : AppStrings.duelNextIn(seconds),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// One player's interval on a revealed question: framed in the player's
/// colour, filled green for a hit or grey for a miss, deeper the more the
/// points say (see [duelTintStrength]).
class _PlayerResult extends StatelessWidget {
  const _PlayerResult({
    required this.name,
    required this.colour,
    required this.result,
    required this.question,
  });

  final String name;
  final Color colour;
  final DuelResult result;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isYear = question.kind == QuestionKind.year;
    final low = result.low;
    final high = result.high;
    final fill = duelResultFill(
      scheme.surface,
      hit: result.hit,
      points: result.points,
    );
    final onFill = scheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colour, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onFill,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _HitChip(hit: result.hit),
              const SizedBox(width: 10),
              Text(
                '${result.points > 0 ? '+' : ''}${result.points}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onFill,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            low == null || high == null
                ? AppStrings.duelNoInterval
                : formatRange(low, high, unit: question.unit, isYear: isYear),
            style: theme.textTheme.bodyMedium?.copyWith(color: onFill),
          ),
          if (low != null && high != null) ...[
            const SizedBox(height: 6),
            IntervalBar(
              isYear: isYear || isLinearUnder(ScoreRule.refined, question),
              low: low,
              high: high,
              answer: question.answer,
              bandColor: colour,
            ),
          ],
        ],
      ),
    );
  }
}

/// "İsabet" or "Iska".
class _HitChip extends StatelessWidget {
  const _HitChip({required this.hit});

  final bool hit;

  @override
  Widget build(BuildContext context) {
    final colour = hit ? duelHitGreen : duelMissGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        hit ? AppStrings.duelHit : AppStrings.duelMiss,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Green of a hit and grey of a miss in the reveal.
const duelHitGreen = Color(0xFF2E9E4F);
const duelMissGrey = Color(0xFF7C8095);

/// The fill of a revealed interval's card on [surface]. A dark surface
/// gets stronger tints, so hits and misses stay apart.
Color duelResultFill(Color surface, {required bool hit, required int points}) {
  final strength = duelTintStrength(points: points, hit: hit);
  final dark = surface.computeLuminance() < 0.2;
  final amount = hit
      ? (dark ? 0.16 : 0.10) + (dark ? 0.42 : 0.32) * strength
      : (dark ? 0.10 : 0.06) + (dark ? 0.22 : 0.26) * strength;
  return Color.lerp(surface, hit ? duelHitGreen : duelMissGrey, amount)!;
}

/// The end: both philosophers, the winner on the higher step, the totals
/// and every question's points side by side.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.match,
    required this.onRematch,
    required this.onDecline,
  });

  final DuelMatch match;

  /// Asks for a rematch, or accepts the opponent's.
  final VoidCallback onRematch;

  /// No rematch: declines, or takes the request back.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = match.outcome ?? DuelOutcome.draw;
    final (title, mePose, opponentPose) = switch (outcome) {
      DuelOutcome.win => (
        AppStrings.duelWin,
        DuelPose.champion,
        DuelPose.defeated,
      ),
      DuelOutcome.loss => (
        AppStrings.duelLoss,
        DuelPose.defeated,
        DuelPose.champion,
      ),
      DuelOutcome.draw => (AppStrings.duelDraw, DuelPose.even, DuelPose.even),
    };
    return ListenableBuilder(
      listenable: Moderation.instance,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          // As wide as half the screen, but leave room for the rest.
          final rematchOpen = const {
            RematchState.available,
            RematchState.asked,
            RematchState.offered,
            RematchState.starting,
          }.contains(match.rematch);
          final figure = [
            box.maxWidth / 2 - 8,
            190.0,
            box.maxHeight - (match.rematch == RematchState.offered ? 568 : 488),
          ].reduce((a, b) => a < b ? a : b).clamp(80.0, 190.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: switch (outcome) {
                      DuelOutcome.win => Palette.duelMe,
                      DuelOutcome.loss => Palette.duelOpponent,
                      DuelOutcome.draw => theme.colorScheme.primary,
                    },
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                match.opponentLeft
                    ? AppStrings.duelOpponentLeft
                    : AppStrings.duelMargin(
                        (match.myTotal - match.opponentTotal).abs(),
                      ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Podium(
                      name: AppStrings.duelYou,
                      total: match.myTotal,
                      colour: Palette.duelMe,
                      pose: mePose,
                      figure: figure,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Podium(
                      name: Moderation.instance.shown(match.opponentName),
                      total: match.opponentTotal,
                      colour: Palette.duelOpponent,
                      pose: opponentPose,
                      figure: figure,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _QuestionStrip(match: match),
              if (match.opponentName.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    onPressed: () => showPlayerActions(
                      context,
                      name: match.opponentName,
                      place: ReportPlace.duel,
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text(AppStrings.reportOrBlockOpponent),
                  ),
                ),
              const Spacer(),
              _RematchArea(
                match: match,
                onRematch: onRematch,
                onDecline: onDecline,
              ),
              if (rematchOpen)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text(AppStrings.duelPlayAgain),
                )
              else
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(AppStrings.duelPlayAgain),
                ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(AppStrings.duelHome),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The rematch after the end: ask for one, wait for the answer, or answer
/// the opponent's; a short note once it is off the table.
class _RematchArea extends StatelessWidget {
  const _RematchArea({
    required this.match,
    required this.onRematch,
    required this.onDecline,
  });

  final DuelMatch match;
  final VoidCallback onRematch;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = Moderation.instance.shown(match.opponentName);
    Widget busy(String text) => FilledButton.icon(
      onPressed: null,
      icon: const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      label: Text(text),
    );
    Widget note(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final Widget? child = switch (match.rematch) {
      RematchState.available => FilledButton.icon(
        onPressed: onRematch,
        icon: const Icon(Icons.replay_rounded),
        label: const Text(AppStrings.duelRematch),
      ),
      RematchState.asked => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          busy(AppStrings.duelRematchSent),
          TextButton(
            onPressed: onDecline,
            child: const Text(AppStrings.duelRematchCancel),
          ),
        ],
      ),
      RematchState.offered => Card(
        margin: const EdgeInsets.only(bottom: 4),
        color: Palette.duelOpponent.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Palette.duelOpponent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.duelRematchOffer(name),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      child: const Text(AppStrings.duelRematchDecline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onRematch,
                      child: const Text(AppStrings.duelRematchAccept),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      RematchState.starting => busy(AppStrings.duelRematchStarting),
      RematchState.declined => note(AppStrings.duelRematchDeclined(name)),
      RematchState.gone => note(AppStrings.duelRematchGone(name)),
      RematchState.expired => note(AppStrings.duelRematchExpired),
      RematchState.noQuestions => note(AppStrings.duelRematchNoQuestions),
      RematchState.refused || RematchState.unavailable => null,
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }
}

/// A philosopher on a step: higher and with a trophy for the winner.
class _Podium extends StatelessWidget {
  const _Podium({
    required this.name,
    required this.total,
    required this.colour,
    required this.pose,
    required this.figure,
  });

  final String name;
  final int total;
  final Color colour;
  final DuelPose pose;
  final double figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = switch (pose) {
      DuelPose.champion => 86.0,
      DuelPose.even => 66.0,
      DuelPose.defeated => 50.0,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Transform.translate(
            offset: Offset(0, (1 - t) * 40),
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
          child: Duelist(pose: pose, sash: colour, size: figure),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: step,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: figure),
                  child: Text(
                    name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Every question's points, the player's above the opponent's, each
/// tinted like its card in the reveal.
class _QuestionStrip extends StatelessWidget {
  const _QuestionStrip({required this.match});

  final DuelMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    Widget cell(DuelResult r, Color colour) => Container(
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: duelResultFill(surface, hit: r.hit, points: r.points),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour, width: 2),
      ),
      child: Text(
        '${r.points}',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Row(
      children: [
        for (final r in match.results)
          Expanded(
            child: Column(
              children: [
                cell(r.me, Palette.duelMe),
                cell(r.opponent, Palette.duelOpponent),
              ],
            ),
          ),
      ],
    );
  }
}

/// Covers the duel while the clock is stopped: this player's connection
/// is coming back, or the opponent's is gone (with their time left).
/// The opponent's connection dropped mid-question: the question goes on.
class _AwayNote extends StatelessWidget {
  const _AwayNote({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 20,
              color: theme.colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.duelOpponentAwayQuestion(name),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PausedCover extends StatefulWidget {
  const _PausedCover({
    required this.reconnecting,
    required this.opponent,
    required this.awayUntil,
    required this.now,
  });

  final bool reconnecting;
  final String opponent;
  final DateTime? awayUntil;
  final DateTime Function() now;

  @override
  State<_PausedCover> createState() => _PausedCoverState();
}

class _PausedCoverState extends State<_PausedCover> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = widget.awayUntil;
    final left = until == null
        ? 0
        : secondsShown(until.difference(widget.now()));
    final title = widget.reconnecting
        ? AppStrings.reconnecting
        : AppStrings.duelOpponentAway(widget.opponent);
    final hint = widget.reconnecting
        ? AppStrings.duelReconnectingHint
        : AppStrings.duelOpponentAwayHint(left < 0 ? 0 : left);
    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: .88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.reconnecting
                      ? const CircularProgressIndicator()
                      : Icon(
                          Icons.wifi_off_rounded,
                          size: 44,
                          color: Palette.duelOpponent,
                        ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
