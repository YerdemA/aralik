import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/number_format.dart';
import '../../core/question_timer.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/tournament.dart';
import '../../data/duel_client.dart';
import '../../data/pending_match.dart';
import '../../data/question.dart';
import '../../data/question_repository.dart';
import '../../data/sound.dart';
import '../../data/stats_store.dart';
import '../../data/tournament_client.dart';
import '../game/answer_input.dart';
import '../game/game_controller.dart';
import '../leaderboard/leaderboard_screen.dart' show Medal;

/// A tournament room: the lobby (players, question count, start), then
/// the questions, each revealed with everyone's interval, then the
/// standings and back to the lobby.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({
    super.key,
    required this.service,
    required this.repository,
    required this.stats,
    required this.code,
    required this.name,
    this.scaled = true,
    this.now = DateTime.now,
    this.rejoin,
    this.pending,
  });

  /// This player's secret to go back to a match in room [code] they left.
  final String? rejoin;

  /// Where the match in progress is kept for going back to it after
  /// leaving the app; null keeps nothing (tests).
  final PendingMatchStore? pending;

  final TournamentService service;
  final QuestionRepository repository;
  final StatsStore stats;
  final String code;
  final String name;
  final bool scaled;

  /// The clock; replaceable in tests.
  final DateTime Function() now;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final _room = TournamentRoom();
  TournamentSession? _session;
  Map<String, Question> _bank = const {};

  /// The input of the current round, and the ids it was made for.
  GameController? _game;
  List<String>? _gameFor;

  final _left = ValueNotifier<Duration?>(null);
  Timer? _ticker;
  DateTime? _deadline;

  final _nextIn = ValueNotifier<int?>(null);
  Timer? _revealTicker;
  int _revealCounted = -1;

  /// Pressed "Devam" on the revealed question with this index.
  int _readyFor = -1;
  String? _localError;

  int _revealsHeard = 0;
  bool _startHeard = false;
  bool _endHeard = false;

  static const _tickEvery = Duration(milliseconds: 200);

  /// Keeps the match in [TournamentScreen.pending] while it runs.
  late final _keeper = PendingMatchKeeper(
    widget.pending,
    kind: PendingKind.tournament,
    now: widget.now,
  );

  @override
  void initState() {
    super.initState();
    _room.addListener(_onRoom);
    _connect();
  }

  /// Saves the match in progress (to go back to it after leaving the app)
  /// or forgets it once it is over.
  void _keep({bool now = false}) {
    final room = _room;
    final code = room.code;
    final rejoin = room.rejoin;
    final inMatch =
        (room.phase == TournamentPhase.question ||
            room.phase == TournamentPhase.reveal) &&
        !room.roundOver;
    if (inMatch && code != null && rejoin != null) {
      if (room.reconnecting) return;
      _keeper.playing(
        code: code,
        rejoin: rejoin,
        name: widget.name,
        window: tournamentRejoinWindow(room.questionsLeft),
        force: now,
      );
    } else if (room.phase != TournamentPhase.connecting &&
        !(room.phase == TournamentPhase.failed && room.error == 'offline')) {
      _keeper.over(rejoin: rejoin ?? widget.rejoin);
    }
  }

  @override
  void dispose() {
    // Left mid-match ("Çık"): the room keeps the player until the match
    // ends; the home screen offers to go back.
    _keep(now: true);
    _ticker?.cancel();
    _revealTicker?.cancel();
    _left.dispose();
    _nextIn.dispose();
    _room.removeListener(_onRoom);
    _session?.close();
    _game?.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final bank = await widget.repository.load();
      _bank = {for (final q in bank) q.id: q};
      final session = await widget.service.join(
        code: widget.code,
        name: widget.name,
        bankSize: bank.length,
        room: _room,
        rejoin: widget.rejoin,
      );
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
    } on DuelException catch (e) {
      if (mounted) {
        _room.handle(
          TournamentError(
            e.failure == DuelFailure.server ? 'unavailable' : 'offline',
          ),
        );
      }
    } on Object {
      if (mounted) _room.handle(const TournamentError('offline'));
    }
  }

  void _onRoom() {
    _keep();
    final room = _room;
    final ids = room.questionIds;
    // A new round: a fresh input for its questions.
    if (ids.isNotEmpty && !identical(ids, _gameFor)) {
      final questions = [for (final id in ids) ?_bank[id]];
      _game?.dispose();
      _game = null;
      _gameFor = ids;
      _readyFor = -1;
      _revealsHeard = 0;
      _startHeard = false;
      _endHeard = false;
      if (questions.length != ids.length) {
        _localError = AppStrings.duelMissingQuestions;
        _session?.close();
      } else {
        _game = GameController(questions, scaled: widget.scaled);
      }
    }
    final game = _game;
    if (game != null && room.phase == TournamentPhase.question) {
      _openQuestion(game, room.index);
    }
    if (room.phase != TournamentPhase.question) _stopClock();
    if (room.phase == TournamentPhase.reveal &&
        game != null &&
        !game.isLocked &&
        room.results.length > game.index) {
      // Revealed before this phone locked: keep the input in step.
      game.timeOut();
    }
    _countReveal();
    _playSounds();
    setState(() {});
  }

  void _playSounds() {
    final room = _room;
    if (!_startHeard && room.phase == TournamentPhase.question) {
      _startHeard = true;
      Sounds.play(Sfx.duelStart);
    }
    if (room.results.length > _revealsHeard &&
        room.phase == TournamentPhase.reveal) {
      _revealsHeard = room.results.length;
      final me = room.myResult(room.results.length - 1);
      if (me != null) {
        Sounds.play(Sfx.of(ResultTier.of(points: me.points, hit: me.hit)));
      }
    }
    if (!_endHeard && room.phase == TournamentPhase.standings) {
      _endHeard = true;
      Sounds.play(room.myRank == 1 ? Sfx.duelWin : Sfx.done);
    }
  }

  /// The room's clock this screen last started from ([TournamentRoom.clock]).
  int _clockSeen = -1;

  void _openQuestion(GameController game, int index) {
    if (_deadline != null &&
        game.index == index &&
        !game.isLocked &&
        _clockSeen == _room.clock) {
      return;
    }
    _clockSeen = _room.clock;
    while (game.index < index) {
      if (!game.isLocked) game.timeOut();
      game.next();
    }
    if (game.isLocked) return;
    _deadline = widget.now().add(_room.timeLeft);
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
    final left = deadline.difference(widget.now());
    final before = _left.value;
    _left.value = left.isNegative ? Duration.zero : left;
    if (before != null && before > timeWarning && left <= timeWarning) {
      HapticFeedback.lightImpact();
    }
    if (clockTicks(before, left)) Sounds.play(Sfx.tick);
    if (left <= Duration.zero) _lock(timedOut: true);
  }

  void _countReveal() {
    final total = _room.nextIn;
    if (_room.phase != TournamentPhase.reveal || total == null) {
      _revealTicker?.cancel();
      _revealTicker = null;
      _nextIn.value = null;
      return;
    }
    // Counted again when the room sets the clock again (on coming back).
    if (_revealCounted == _room.clock) return;
    _revealCounted = _room.clock;
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

  void _lock({required bool timedOut}) {
    final game = _game;
    if (game == null || game.isLocked) return;
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.mediumImpact();
    final answer = timedOut ? game.timeOut() : game.lock();
    if (!timedOut) Sounds.play(Sfx.lock);
    _session?.lock(_room.index, low: answer.low, high: answer.high);
    // Like duels: calibration, and never again in free play.
    widget.stats.recordAnswer(
      questionId: answer.question.id,
      category: answer.question.category,
      outcome: answer.outcome,
      points: answer.points,
    );
    setState(() {});
  }

  void _next() {
    setState(() => _readyFor = _room.index);
    _session?.next(_room.index);
  }

  Future<void> _kick(TournamentPlayer player) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.tournamentKickTitle(player.name)),
        content: const Text(AppStrings.tournamentKickBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.tournamentKick),
          ),
        ],
      ),
    );
    if (sure == true) _session?.kick(player.id);
  }

  Future<bool> _confirmQuit() async {
    final phase = _room.phase;
    if (phase != TournamentPhase.question && phase != TournamentPhase.reveal) {
      return true;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.tournamentQuitTitle),
        content: const Text(AppStrings.tournamentQuitBody),
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
    final room = _room;
    final game = _game;
    final error =
        _localError ??
        (room.phase == TournamentPhase.failed
            ? (widget.rejoin != null &&
                      const {
                        'no_room',
                        'expired',
                        'rejoin_over',
                      }.contains(room.error)
                  ? AppStrings.tournamentEnded
                  : AppStrings.tournamentErrorText(room.error ?? ''))
            : null);
    final Widget body;
    if (room.phase == TournamentPhase.kicked) {
      body = _Message(
        icon: Icons.block_rounded,
        text: AppStrings.tournamentKicked,
        button: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.next),
        ),
      );
    } else if (error != null) {
      body = _Message(
        icon: Icons.wifi_off_rounded,
        text: error,
        button: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.next),
        ),
      );
    } else if (room.phase == TournamentPhase.connecting) {
      body = const _Message(
        icon: Icons.sync_rounded,
        text: AppStrings.duelConnecting,
        busy: true,
      );
    } else if (room.phase == TournamentPhase.lobby) {
      body = _LobbyView(
        room: room,
        onCount: (n) => _session?.setCount(n),
        onKick: _kick,
        onStart: () => _session?.start(),
      );
    } else if (room.phase == TournamentPhase.standings) {
      body = _StandingsView(room: room, onBack: room.backToRoom);
    } else if (game == null) {
      body = const _Message(
        icon: Icons.sync_rounded,
        text: AppStrings.duelConnecting,
        busy: true,
      );
    } else if (room.phase == TournamentPhase.question) {
      body = _QuestionView(
        game: game,
        room: room,
        onLock: () => _lock(timedOut: false),
      );
    } else {
      final i = room.results.length - 1;
      body = _RevealView(
        question: game.questions[i],
        room: room,
        index: i,
        buttonLabel: room.roundOver
            ? AppStrings.tournamentSeeStandings
            : _readyFor == room.index
            ? AppStrings.duelWaitingOther
            : AppStrings.next,
        onNext: room.roundOver
            ? room.showStandings
            : _readyFor == room.index
            ? null
            : _next,
        nextIn: room.roundOver ? null : _nextIn,
      );
    }

    final inMatch =
        room.phase == TournamentPhase.question ||
        room.phase == TournamentPhase.reveal;
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
          title: Text(
            inMatch && room.index >= 0
                ? AppStrings.questionProgress(
                    room.index + 1,
                    room.questionIds.length,
                  )
                : AppStrings.tournament,
          ),
          actions: [
            ValueListenableBuilder(
              valueListenable: _left,
              builder: (context, left, _) => left == null
                  ? const SizedBox.shrink()
                  : Countdown(left: left, limit: room.questionTime),
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
                    key: ValueKey((room.phase, room.index)),
                    child: body,
                  ),
                ),
              ),
              if (room.reconnecting && error == null)
                const Positioned.fill(child: _ReconnectingCover()),
            ],
          ),
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

/// The room before a round: its code, the players with the host's crown,
/// the question count and the start button (host only).
class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.room,
    required this.onCount,
    required this.onKick,
    required this.onStart,
  });

  final TournamentRoom room;
  final ValueChanged<int> onCount;
  final ValueChanged<TournamentPlayer> onKick;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = room.code ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Palette.heroTop, Palette.heroBottom],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tournamentRoomCode,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: .85),
                      ),
                    ),
                    SelectableText(
                      code,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.duelShareCode,
                color: Colors.white,
                icon: const Icon(Icons.share_rounded),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: AppStrings.tournamentInvite(code)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(AppStrings.tournamentQuestions, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (room.isHost)
          SegmentedButton<int>(
            segments: [
              for (final n in tournamentQuestionCounts)
                ButtonSegment(
                  value: n,
                  label: Text(AppStrings.tournamentQuestionCount(n)),
                ),
            ],
            selected: {room.count},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onCount(s.single),
          )
        else
          Text(
            AppStrings.tournamentQuestionCount(room.count),
            style: theme.textTheme.titleMedium,
          ),
        const SizedBox(height: 16),
        Text(
          AppStrings.tournamentPlayers(room.players.length, room.maxPlayers),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final p in room.players)
                Card(
                  color: p.id == room.you ? scheme.primaryContainer : null,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.id == room.you
                          ? Palette.duelMe
                          : scheme.surfaceContainerHigh,
                      foregroundColor: p.id == room.you
                          ? Colors.white
                          : scheme.onSurface,
                      child: Text(p.name.characters.first.toUpperCase()),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.id == room.you
                                ? '${p.name} (${AppStrings.you})'
                                : p.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: p.id == room.you
                                  ? scheme.onPrimaryContainer
                                  : null,
                            ),
                          ),
                        ),
                        if (p.id == room.host) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: AppStrings.tournamentHost,
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              size: 22,
                              color: Medal.gold.dark,
                              semanticLabel: AppStrings.tournamentHost,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: room.isHost && p.id != room.you
                        ? IconButton(
                            tooltip: AppStrings.tournamentKick,
                            icon: const Icon(Icons.person_remove_rounded),
                            onPressed: () => onKick(p),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (room.isHost) ...[
          if (!room.canStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppStrings.tournamentNeedPlayers(room.minPlayers),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton.icon(
            onPressed: room.canStart ? onStart : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(AppStrings.tournamentStart),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              AppStrings.tournamentWaitHost,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.game,
    required this.room,
    required this.onLock,
  });

  final GameController game;
  final TournamentRoom room;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final active = room.matchPlayers.length;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionCard(question: game.question),
          Expanded(
            child: game.isLocked
                ? _Message(
                    icon: Icons.lock_rounded,
                    text:
                        '${AppStrings.tournamentLocked}\n'
                        '${AppStrings.tournamentLockedCount(room.locked.length, active)}',
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

/// The answer, then every player's interval, best points first.
class _RevealView extends StatelessWidget {
  const _RevealView({
    required this.question,
    required this.room,
    required this.index,
    required this.buttonLabel,
    required this.onNext,
    this.nextIn,
  });

  final Question question;
  final TournamentRoom room;
  final int index;
  final String buttonLabel;
  final VoidCallback? onNext;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              QuestionCard(question: question),
              const SizedBox(height: 12),
              Text(
                AppStrings.duelAnswer,
                style: theme.textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(answer, style: theme.textTheme.displaySmall),
              ),
              const SizedBox(height: 8),
              for (final r in room.ranked(index))
                _ResultRow(
                  name: room.nameOf(r.id),
                  me: r.id == room.you,
                  result: r,
                  question: question,
                ),
            ],
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// One player's interval on a revealed question: name, range, points, and
/// a green or grey mark for hit or miss.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.name,
    required this.me,
    required this.result,
    required this.question,
  });

  final String name;
  final bool me;
  final TournamentResult result;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.extension<GameColors>()!;
    final low = result.low, high = result.high;
    final tierColor = colors.forTier(
      ResultTier.of(points: result.points, hit: result.hit),
    );
    final onRow = me ? scheme.onPrimaryContainer : null;
    return Card(
      color: me ? scheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          children: [
            Icon(
              result.hit ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: tierColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me ? '$name (${AppStrings.you})' : name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(color: onRow),
                  ),
                  Text(
                    low == null || high == null
                        ? AppStrings.duelNoInterval
                        : formatRange(
                            low,
                            high,
                            unit: question.unit,
                            isYear: question.kind == QuestionKind.year,
                          ),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onRow ?? scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${result.points}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: onRow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round's standings: place, name, hits out of the questions, points;
/// the first three in gold, silver and bronze.
class _StandingsView extends StatelessWidget {
  const _StandingsView({required this.room, required this.onBack});

  final TournamentRoom room;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final standings = room.standings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.tournamentStandings,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (var k = 0; k < standings.length; k++)
                Builder(
                  builder: (context) {
                    final s = standings[k];
                    final medal = Medal.ofRank(k + 1);
                    final me = s.id == room.you;
                    final onRow = me ? scheme.onPrimaryContainer : null;
                    return Card(
                      color: me ? scheme.primaryContainer : null,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: medal == null
                          ? null
                          : RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: medal.mid, width: 2.5),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: medal?.gradient,
                                color: medal == null
                                    ? scheme.surfaceContainerHigh
                                    : null,
                              ),
                              child: Text(
                                '${k + 1}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: medal == null
                                      ? scheme.onSurface
                                      : Colors.white,
                                  shadows: medal == null
                                      ? null
                                      : [
                                          Shadow(
                                            color: medal.dark,
                                            blurRadius: 3,
                                          ),
                                        ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      me
                                          ? '${s.name} (${AppStrings.you})'
                                          : s.name,
                                      if (s.left)
                                        '· ${AppStrings.tournamentLeft}',
                                    ].join(' '),
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: onRow),
                                  ),
                                  Text(
                                    AppStrings.tournamentHits(
                                      s.hits,
                                      room.roundQuestions,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: onRow ?? scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${s.points}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: onRow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.meeting_room_rounded),
          label: const Text(AppStrings.tournamentBackToRoom),
        ),
      ],
    );
  }
}

/// Covers the room while this player's connection comes back; the others
/// play on meanwhile.
class _ReconnectingCover extends StatelessWidget {
  const _ReconnectingCover();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.reconnecting,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.tournamentReconnectingHint,
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
