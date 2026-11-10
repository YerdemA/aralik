import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../math/math_mode_screen.dart';
import '../../widgets/coach_tour.dart';
import '../../core/math/math_question.dart';
import '../../core/math/math_problem.dart';
import '../../core/daily.dart';
import '../../core/question_timer.dart';
import '../../core/free_play.dart';
import '../../core/invite_link.dart';
import '../../data/invite_links.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/answer_scale.dart';
import '../../core/app_update.dart';
import '../../data/duel_client.dart';
import '../../data/store_link.dart';
import '../../data/leaderboard.dart';
import '../../data/ranked_client.dart';
import '../../data/pending_match.dart';
import '../../data/question_repository.dart';
import '../../data/settings_store.dart';
import '../../data/sound.dart';
import '../../data/stats_store.dart';
import '../../data/tournament_client.dart';
import '../../widgets/mascot.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';
import '../duel/duel_lobby_screen.dart';
import '../duel/duel_screen.dart';
import '../tournament/tournament_screen.dart';
import '../tournament/tournament_entry_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../ranked/month_end_screen.dart';
import '../result/summary_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/user_name_sheet.dart';
import '../stats/stats_screen.dart';

/// The main card with the mascot, then streak, last score and calibration.
/// The main card is today's set; once it is done, today shrinks to a strip
/// with the score and share, and free play becomes the main card.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.stats,
    required this.settings,
    this.leaderboard,
    this.ranked,
    this.pending,
    this.latestAppBuild,
    this.openStore = openStorePage,
    this.scoringV2Day,
    this.scoringV3Day,
    this.invites,
  });

  /// Invite links the app was opened with (kabaca.app/d/KOD); each opens
  /// the duel or tournament screen with its code. Null in tests.
  final InviteLinks? invites;

  /// First day of the scaled scoring rule (content manifest), or null.
  final int? Function()? scoringV2Day;

  /// First day of the refined scoring rule (content manifest), or null.
  final int? Function()? scoringV3Day;

  final QuestionRepository repository;
  final StatsStore stats;
  final SettingsStore settings;

  /// Null hides the leaderboard.
  final LeaderboardStore? leaderboard;

  /// The monthly ranked duel tables (and the month-end recap); null in
  /// tests.
  final RankedService? ranked;

  /// A duel or tournament left mid-way (the app closed, or "Çık"): a card
  /// offers to go back to it while the room keeps the seat.
  final PendingMatchStore? pending;

  /// The newest build on Google Play (from the content manifest), or null.
  /// A newer one than this app's is offered once per launch.
  final int? Function()? latestAppBuild;

  /// Opens the Play Store page; replaceable in tests.
  final Future<bool> Function() openStore;

  /// The update notice is shown once per launch (tests reset it).
  @visibleForTesting
  static bool updateOffered = false;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _rng = math.Random();
  bool _loading = false;

  QuestionRepository get _repository => widget.repository;
  StatsStore get _stats => widget.stats;
  LeaderboardStore? get _leaderboard => widget.leaderboard;

  @override
  void initState() {
    super.initState();
    // A finished set that could not be sent earlier (offline) goes now.
    _leaderboard?.submitPending(_today);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerUpdate());
    // One name everywhere: an older app kept the leaderboard nickname
    // apart from the duel name; the account's wins.
    syncUserName(widget.settings, _leaderboard);
    _checkDevice();
    _checkPending();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstLaunchTour());
    _monthEnd();
    widget.invites?.addListener(_openInvite);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite());
  }

  @override
  void dispose() {
    widget.invites?.removeListener(_openInvite);
    super.dispose();
  }

  /// Opens the room of an invite link the app was opened with, on top of
  /// whatever is on screen (nothing in play is left).
  void _openInvite() {
    final invites = widget.invites;
    if (!mounted || invites == null || invites.pending == null) return;
    final invite = invites.take()!;
    if (_leaderboard?.isAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.inviteUnavailable(invite.code))),
      );
      return;
    }
    switch (invite.kind) {
      case InviteKind.duel:
        _openDuel(code: invite.code);
      case InviteKind.tournament:
        _openTournament(code: invite.code);
    }
  }

  /// A match left behind whose time to go back ran out while the app was
  /// closed: forget it, and say so for a duel (the opponent won).
  void _checkPending() {
    final pending = widget.pending;
    final match = pending?.current;
    if (match == null || match.isLive(DateTime.now())) return;
    pending!.clear();
    if (match.kind != PendingKind.duel) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.pendingDuelExpired)),
      );
    });
  }

  /// Back to the match left behind, with the player's secret.
  Future<void> _rejoin(PendingMatch match) async {
    final rule = _ruleOn(_today);
    final again = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => switch (match.kind) {
          PendingKind.duel => DuelScreen(
            service: _duels,
            repository: _repository,
            stats: _stats,
            code: match.code,
            name: match.name,
            rejoin: match.rejoin,
            pending: widget.pending,
            rule: rule,
          ),
          PendingKind.tournament => TournamentScreen(
            service: _tournaments,
            repository: _repository,
            stats: _stats,
            code: match.code,
            name: match.name,
            rejoin: match.rejoin,
            pending: widget.pending,
            rule: rule,
          ),
        },
      ),
    );
    if (again == true && mounted && match.kind == PendingKind.duel) {
      _openDuel();
    }
  }

  /// Gives the match up: a duel ends now with the opponent winning; a
  /// tournament goes on without the player.
  void _giveUp(PendingMatch match) {
    widget.pending?.clear(rejoin: match.rejoin);
    if (match.kind == PendingKind.duel) {
      _duels
          .resign(code: match.code, rejoin: match.rejoin, name: match.name)
          .ignore();
    }
  }

  /// A cleared app: the server may know this device's account and that
  /// today's set was already played here.
  Future<void> _checkDevice() async {
    final restored = await _leaderboard?.checkDevice(_today) ?? false;
    if (!restored) return;
    await syncUserName(widget.settings, _leaderboard);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.leaderboardRestored(_leaderboard!.account!.nickname),
        ),
      ),
    );
  }

  /// A month just ended in which the player played ranked duels: their
  /// card and the final table, once. Waits while something else is on
  /// screen (the tour, an update notice) and tries again next launch.
  Future<void> _monthEnd() async {
    final ranked = widget.ranked;
    if (ranked == null) return;
    final tables = await ranked.monthEndRecap();
    if (tables.isEmpty || !mounted) return;
    // Not over the first-launch tour, a dialog or another screen.
    final onTop = ModalRoute.of(context)?.isCurrent ?? false;
    if (!onTop || !widget.settings.tourSeen(TourPart.home)) return;
    await ranked.markRecapShown(tables.first.month);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MonthEndScreen(tables: tables, look: widget.settings.mascot),
      ),
    );
  }

  /// Today's set was played on this device before its data was cleared.
  bool _playedBefore(int day) =>
      _stats.dailyResults(day).isEmpty &&
      (_leaderboard?.playedOnDevice(day) ?? false);

  Future<void> _offerUpdate() async {
    if (HomeScreen.updateOffered || !mounted) return;
    if (!updateAvailable(widget.latestAppBuild?.call())) return;
    HomeScreen.updateOffered = true;
    final update = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded),
        title: const Text(AppStrings.updateTitle),
        content: const Text(AppStrings.updateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.updateLater),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.updateNow),
          ),
        ],
      ),
    );
    if (update != true || !mounted) return;
    if (!await widget.openStore() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.updateStoreMissing)),
      );
    }
  }

  /// The scoring rule of [day]'s daily set and duels, from the manifest's
  /// switch days (the leaderboard server reads the same).
  ScoreRule _ruleOn(int day) => ruleOn(
    day,
    v2Day: widget.scoringV2Day?.call(),
    v3Day: widget.scoringV3Day?.call(),
  );

  // Read on every build, so the screen rolls over at midnight on resume.
  int get _today => dayIndexFor(DateTime.now());

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
    if (_playedBefore(day)) return;
    final done = _stats.dailyResults(day).length;
    final remaining = (await _repository.dailySet(day)).skip(done).toList();
    if (!mounted || remaining.isEmpty) return;
    final answers = await Navigator.of(context).push<List<RoundAnswer>>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          settings: widget.settings,
          questions: remaining,
          rule: _ruleOn(day),
          alreadyAnswered: done,
          startQuestion: (position) =>
              _stats.startDailyQuestion(day, position, DateTime.now()),
          onLocked: (a) {
            _stats.recordAnswer(
              questionId: a.question.id,
              category: a.question.category,
              outcome: a.outcome,
              dailyDay: day,
              points: a.points,
            );
            // Kept on the device; sent only after joining the leaderboard.
            _leaderboard?.recordDailyInterval(day, (
              questionId: a.question.id,
              low: a.low,
              high: a.high,
            ));
          },
        ),
      ),
    );
    if (!mounted || answers == null || !_stats.isDayComplete(day)) return;
    _leaderboard?.submit(day).ignore();
    Sounds.play(Sfx.done);
    await _showDaySummary(day);
  });

  Future<void> _showDaySummary(int day) => Navigator.of(context).push(
    MaterialPageRoute<SummaryAction>(
      builder: (_) => SummaryScreen(
        mascot: widget.settings.mascot,
        results: _stats.dailyResults(day),
        hits: _stats.hits,
        answered: _stats.answered,
        dayIndex: day,
        onLeaderboard: _leaderboard?.isAvailable == true
            ? () => _openLeaderboard(day)
            : null,
      ),
    ),
  );

  void _openLeaderboard(int day) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LeaderboardScreen(
        store: _leaderboard!,
        settings: widget.settings,
        day: day,
        dayDone: _stats.isDayComplete(day),
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
            settings: widget.settings,
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
      Sounds.play(Sfx.done);
      final action = await Navigator.of(context).push<SummaryAction>(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            mascot: widget.settings.mascot,
            results: [for (final a in answers) (points: a.points, hit: a.hit)],
            hits: _stats.hits,
            answered: _stats.answered,
          ),
        ),
      );
      if (action != SummaryAction.newRound) return;
    }
  });

  /// Math mode: basic or further on, then rounds of five generated
  /// questions, 30 s each, until "Ana ekran". Answers count in math's own
  /// calibration only and may come again.
  Future<void> _playMath() => _guarded(() async {
    final tier = await Navigator.of(
      context,
    ).push<MathTier>(MaterialPageRoute(builder: (_) => const MathModeScreen()));
    if (tier == null) return;
    while (mounted) {
      final round = [
        for (final p in mathRound(_rng.nextInt(1 << 31), tiers: {tier}))
          mathQuestion(p),
      ];
      if (!mounted) return;
      final answers = await Navigator.of(context).push<List<RoundAnswer>>(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            settings: widget.settings,
            questions: round,
            startQuestion: (_) => DateTime.now(),
            timeLimit: mathTimeLimit,
            scale: mathScaleOf,
            minPoints: mathMinPoints,
            onLocked: (a) => _stats.recordMathAnswer(hit: a.hit),
          ),
        ),
      );
      if (!mounted || answers == null) return;
      Sounds.play(Sfx.done);
      final action = await Navigator.of(context).push<SummaryAction>(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            mascot: widget.settings.mascot,
            results: [for (final a in answers) (points: a.points, hit: a.hit)],
            hits: _stats.mathHits,
            answered: _stats.mathAnswered,
            roundLabel: AppStrings.mathRoundLabel,
            calibrationTitle: AppStrings.mathCalibration,
            math: true,
          ),
        ),
      );
      if (action != SummaryAction.newRound) return;
    }
  });

  late final _duels = DuelService(
    serviceUri: () => _leaderboard?.serviceUri,
    look: () => widget.settings.mascotCode,
    // Random opponents' duels count for the monthly table when joined.
    account: () => switch (_leaderboard?.account) {
      final a? => (id: a.id, token: a.token),
      null => null,
    },
  );
  late final _tournaments = TournamentService(
    serviceUri: () => _leaderboard?.serviceUri,
    look: () => widget.settings.mascotCode,
  );

  void _openTournament({String? code}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TournamentEntryScreen(
        code: code,
        service: _tournaments,
        repository: _repository,
        stats: _stats,
        settings: widget.settings,
        leaderboard: _leaderboard,
        pending: widget.pending,
        rule: _ruleOn(_today),
      ),
    ),
  );

  void _openDuel({bool math = false, String? code}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DuelLobbyScreen(
            code: code,
            math: math,
            service: _duels,
            repository: _repository,
            stats: _stats,
            settings: widget.settings,
            leaderboard: _leaderboard,
            ranked: widget.ranked,
            pending: widget.pending,
            rule: _ruleOn(_today),
          ),
        ),
      );

  Future<void> _openSettings() async {
    final replay = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          leaderboard: _leaderboard,
        ),
      ),
    );
    // "Tanıtımı yeniden oynat": settings closed itself for it.
    if (replay == true && mounted) await _tour();
  }

  final _tourDay = GlobalKey();
  final _tourDuel = GlobalKey();
  final _tourFree = GlobalKey();
  final _tourMath = GlobalKey();
  final _tourCup = GlobalKey();
  final _tourBoard = GlobalKey();
  final _tourStats = GlobalKey();
  final _tourSettings = GlobalKey();

  /// The first launch shows the home screen around, once. Players from
  /// before the tour (they have answers) are not shown it.
  Future<void> _firstLaunchTour() async {
    final settings = widget.settings;
    if (settings.tourSeen(TourPart.home)) return;
    if (_stats.answered > 0 || _stats.mathAnswered > 0) {
      await settings.markAllToursSeen();
      return;
    }
    await _tour();
  }

  Future<void> _tour() async {
    // After the screen's own entrance.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    // Something on top (the update notice): next launch then.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await widget.settings.markTourSeen(TourPart.home);
    if (!mounted) return;
    await showCoachTour(context, [
      const CoachStep(
        title: AppStrings.tourWelcomeTitle,
        body: AppStrings.tourWelcome,
      ),
      CoachStep(
        target: _tourDay,
        title: AppStrings.tourDayTitle,
        body: AppStrings.tourDay,
      ),
      CoachStep(
        target: _tourDuel,
        title: AppStrings.tourDuelTitle,
        body: AppStrings.tourDuel,
      ),
      CoachStep(
        target: _tourFree,
        title: AppStrings.tourFreeTitle,
        body: AppStrings.tourFree,
      ),
      CoachStep(
        target: _tourMath,
        title: AppStrings.tourMathTitle,
        body: AppStrings.tourMath,
      ),
      CoachStep(
        target: _tourCup,
        title: AppStrings.tourCupTitle,
        body: AppStrings.tourCup,
      ),
      CoachStep(
        target: _tourBoard,
        title: AppStrings.tourBoardTitle,
        body: AppStrings.tourBoard,
      ),
      CoachStep(
        target: _tourStats,
        title: AppStrings.tourStatsTitle,
        body: AppStrings.tourStats,
      ),
      CoachStep(
        target: _tourSettings,
        title: AppStrings.tourSettingsTitle,
        body: AppStrings.tourSettings,
      ),
    ]);
  }

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
          listenable: Listenable.merge([
            _stats,
            ?_leaderboard,
            ?widget.pending,
          ]),
          builder: (context, _) {
            final today = _today;
            final results = _stats.dailyResults(today);
            final finished = _stats.isDayComplete(today);
            final playedBefore = _playedBefore(today);
            final hasDuel = _leaderboard?.isAvailable == true;
            final streak = _stats.streak(today);
            final left = widget.pending?.current;
            final pending = left != null && left.isLive(DateTime.now())
                ? left
                : null;
            // Scrolls only when the screen is too short for everything;
            // otherwise the main card takes up the spare height.
            return LayoutBuilder(
              builder: (context, constraints) {
                final mascotSize = (constraints.maxHeight * 0.2).clamp(
                  96.0,
                  150.0,
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppStrings.appName,
                                          style: textTheme.headlineMedium
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -1,
                                                height: 1.1,
                                              ),
                                        ),
                                        Text(
                                          AppStrings.tagline,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_leaderboard?.isAvailable == true) ...[
                                  IconButton.filledTonal(
                                    key: _tourBoard,
                                    onPressed: () => _openLeaderboard(today),
                                    tooltip: AppStrings.leaderboard,
                                    icon: const Icon(
                                      Icons.emoji_events_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                IconButton.filledTonal(
                                  key: _tourStats,
                                  onPressed: _openStats,
                                  tooltip: AppStrings.stats,
                                  icon: const Icon(Icons.bar_chart_rounded),
                                ),
                                const SizedBox(width: 4),
                                IconButton.filledTonal(
                                  key: _tourSettings,
                                  onPressed: _openSettings,
                                  tooltip: AppStrings.settings,
                                  icon: const Icon(Icons.settings_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (pending != null) ...[
                              _PendingMatchCard(
                                match: pending,
                                onJoin: () => _rejoin(pending),
                                onGiveUp: () => _giveUp(pending),
                                onExpired: () => widget.pending?.clear(
                                  rejoin: pending.rejoin,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (finished) ...[
                              _TodayDoneStrip(
                                results: results,
                                streak: streak,
                                onShare: _loading
                                    ? null
                                    : () => _showDaySummary(today),
                              ),
                              const SizedBox(height: 12),
                              // Free play is the main card now; the duel
                              // sits below it.
                              Expanded(
                                key: _tourFree,
                                child: _FreePlayHero(
                                  mascotSize: mascotSize,
                                  onPlay: _loading ? null : _playFree,
                                ),
                              ),
                              if (hasDuel) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  key: _tourDuel,
                                  height: _ModeTile.height,
                                  child: _DuelTile(
                                    onTap: _loading ? null : _openDuel,
                                  ),
                                ),
                              ],
                            ] else ...[
                              Expanded(
                                key: _tourDay,
                                child: _TodayCard(
                                  results: results,
                                  today: today,
                                  streak: streak,
                                  mascotSize: mascotSize,
                                  playedBefore: playedBefore,
                                  onPlay: _loading || playedBefore
                                      ? null
                                      : _playDaily,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: _ModeTile.height,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (hasDuel) ...[
                                      Expanded(
                                        key: _tourDuel,
                                        child: _DuelTile(
                                          onTap: _loading ? null : _openDuel,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      key: _tourFree,
                                      child: _FreePlayTile(
                                        onTap: _loading ? null : _playFree,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Both tiles as tall as the taller one.
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    key: _tourMath,
                                    child: _MathTile(
                                      onTap: _loading ? null : _playMath,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    key: _tourCup,
                                    // Tournaments need the server, like duels.
                                    child: hasDuel
                                        ? _TournamentTile(
                                            onTap: _loading
                                                ? null
                                                : _openTournament,
                                          )
                                        : const _SoonTile(
                                            icon: Icons.military_tech_rounded,
                                            title: AppStrings.modeTournament,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A big card with the mascot peeking over its main button.
class _MascotCard extends StatelessWidget {
  const _MascotCard({
    required this.colors,
    required this.mascotSize,
    required this.children,
    required this.button,
    this.footer,
  });

  final List<Color> colors;
  final double mascotSize;

  /// Top of the card, never covered by the mascot.
  final List<Widget> children;

  /// Sits to the mascot's left, just above [button].
  final Widget? footer;
  final Widget button;

  static const _padding = 18.0;
  static const _buttonHeight = 58.0;
  static const _mascotOverlap = 10.0;
  static const _footerHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The toga ends behind the button.
          Positioned(
            right: 0,
            bottom: _padding + _buttonHeight - _mascotOverlap,
            child: Mascot(size: mascotSize),
          ),
          Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...children,
                const Spacer(),
                // Room for the mascot, so he never covers the text. His
                // bubble starts 16% down his square.
                SizedBox(
                  height: mascotSize * 0.84 - _mascotOverlap - _footerHeight,
                ),
                SizedBox(
                  height: _footerHeight,
                  child: Align(alignment: Alignment.topLeft, child: footer),
                ),
                SizedBox(width: double.infinity, child: button),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sunny main button of a [_MascotCard].
class _SunButton extends StatelessWidget {
  const _SunButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.sun,
        foregroundColor: Palette.onSun,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(label),
    );
  }
}

/// The screen's main action until today's set is done: the date, progress
/// and the button that plays or continues it.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.results,
    required this.today,
    required this.streak,
    required this.mascotSize,
    required this.onPlay,
    this.playedBefore = false,
  });

  final List<QuestionResult> results;
  final int today;
  final int streak;
  final double mascotSize;
  final VoidCallback? onPlay;

  /// Played on this device before its data was cleared: locked till
  /// tomorrow.
  final bool playedBefore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = results.length;
    return _MascotCard(
      colors: const [Palette.heroTop, Palette.heroBottom],
      mascotSize: mascotSize,
      footer: _ProgressPips(results: results),
      button: _SunButton(
        onPressed: onPlay,
        icon: playedBefore ? Icons.lock_rounded : Icons.play_arrow_rounded,
        label: playedBefore
            ? AppStrings.todayPlayedBefore
            : done == 0
            ? AppStrings.playToday
            : AppStrings.continueToday(done, questionsPerDay),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DayPill(label: dayLabelWithWeekday(dateOfDay(today))),
            _StreakPill(days: streak),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.todayTitle,
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          playedBefore
              ? AppStrings.todayPlayedBeforeHint
              : '${AppStrings.todayHint} '
                    '${AppStrings.timeLimitHint(dailyTimeLimit.inSeconds)}',
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: .85),
          ),
        ),
      ],
    );
  }
}

/// Today's set once it is done: a slim strip with the score and share.
class _TodayDoneStrip extends StatelessWidget {
  const _TodayDoneStrip({
    required this.results,
    required this.streak,
    required this.onShare,
  });

  final List<QuestionResult> results;
  final int streak;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
                  AppStrings.todayDone,
                  style: textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
                Text(
                  AppStrings.scoreOutOf(totalPoints(results), maxDailyPoints),
                  style: textTheme.headlineSmall?.copyWith(
                    color: Palette.sun,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _ProgressPips(results: results),
                const SizedBox(height: 10),
                _StreakPill(days: streak),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: Colors.white.withValues(alpha: .18),
              foregroundColor: Colors.white,
              textStyle: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text(AppStrings.share),
          ),
        ],
      ),
    );
  }
}

/// The date and puzzle number on today's card.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The streak on today's card: a flame and "3 gün seri".
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final on = days > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
      decoration: BoxDecoration(
        color: on
            ? Palette.sun.withValues(alpha: .2)
            : Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: on ? Palette.sun : Colors.white70,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppStrings.streakPill(days),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: on ? Palette.sun : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One pip per question of the day, coloured by result like the share
/// squares. The button's "2 / 5" says the same to screen readers.
class _ProgressPips extends StatelessWidget {
  const _ProgressPips({required this.results});

  final List<QuestionResult> results;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < questionsPerDay; i++)
              Container(
                width: 22,
                height: 8,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i < results.length
                      ? GameColors.dark.forTier(
                          ResultTier.of(
                            points: results[i].points,
                            hit: results[i].hit,
                          ),
                        )
                      : Colors.white.withValues(alpha: .22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Free play as the main card, once today's set is done.
class _FreePlayHero extends StatelessWidget {
  const _FreePlayHero({required this.mascotSize, required this.onPlay});

  final double mascotSize;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _MascotCard(
      colors: const [Palette.roundStart, Palette.roundEnd],
      mascotSize: mascotSize,
      button: _SunButton(
        onPressed: onPlay,
        icon: Icons.play_arrow_rounded,
        label: AppStrings.newRound,
      ),
      children: [
        Text(
          AppStrings.freePlay,
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.freePlayHint,
          style: textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// Free play: the whole tile starts a round.
class _FreePlayTile extends StatelessWidget {
  const _FreePlayTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _ModeTile(
    colors: const [Palette.roundStart, Palette.roundEnd],
    icon: Icons.all_inclusive_rounded,
    title: AppStrings.freePlay,
    hint: AppStrings.freePlayHint,
    onTap: onTap,
  );
}

/// The duel, in its players' colours: blue against red.
class _DuelTile extends StatelessWidget {
  const _DuelTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _ModeTile(
    colors: const [Palette.duelMe, Palette.duelOpponent],
    icon: Icons.bolt_rounded,
    title: AppStrings.duel,
    hint: AppStrings.duelHomeHint,
    onTap: onTap,
  );
}

/// A gradient tile whose whole surface is one button: icon and arrow on
/// top, title and hint below, the icon again large and faint in the
/// corner.
/// A duel or tournament left mid-way: go back to it, or give it up. A
/// duel counts down the time the room keeps the seat.
class _PendingMatchCard extends StatefulWidget {
  const _PendingMatchCard({
    required this.match,
    required this.onJoin,
    required this.onGiveUp,
    required this.onExpired,
  });

  final PendingMatch match;
  final VoidCallback onJoin;
  final VoidCallback onGiveUp;
  final VoidCallback onExpired;

  @override
  State<_PendingMatchCard> createState() => _PendingMatchCardState();
}

class _PendingMatchCardState extends State<_PendingMatchCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!widget.match.isLive(DateTime.now())) {
        _timer?.cancel();
        widget.onExpired();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = widget.match;
    final duel = match.kind == PendingKind.duel;
    final seconds = match.until
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 999);
    final color = duel ? Palette.duelOpponent : theme.colorScheme.tertiary;
    return Card(
      color: Color.alphaBlend(
        color.withValues(alpha: 0.12),
        theme.colorScheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  duel ? Icons.bolt_rounded : Icons.emoji_events_rounded,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    duel
                        ? AppStrings.pendingDuelTitle
                        : AppStrings.pendingTournamentTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              duel
                  ? AppStrings.pendingDuelBody(match.code, seconds)
                  : AppStrings.pendingTournamentBody(match.code),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onGiveUp,
                    child: Text(
                      duel
                          ? AppStrings.duelResign
                          : AppStrings.pendingLeaveTournament,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onJoin,
                    child: const Text(AppStrings.pendingJoin),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  /// Height of a row of tiles.
  static const double height = 150;

  final List<Color> colors;
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(24);
    return AnimatedOpacity(
      opacity: onTap == null ? .6 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    bottom: -22,
                    child: Icon(
                      icon,
                      size: 100,
                      color: Colors.white.withValues(alpha: .13),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white.withValues(
                                alpha: .22,
                              ),
                              foregroundColor: Colors.white,
                              child: Icon(icon, size: 22),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: .92),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
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

/// Tournaments: a small gradient tile the size of the [_SoonTile] beside it.
class _TournamentTile extends StatelessWidget {
  const _TournamentTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _SmallModeTile(
    onTap: onTap,
    icon: Icons.military_tech_rounded,
    title: AppStrings.tournament,
    hint: AppStrings.tournamentHomeHint,
    colors: const [Palette.cupStart, Palette.cupEnd],
  );
}

/// Math mode: basic or further on, 30 s a question.
class _MathTile extends StatelessWidget {
  const _MathTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _SmallModeTile(
    onTap: onTap,
    icon: Icons.calculate_rounded,
    title: AppStrings.categoryMath,
    hint: AppStrings.mathHomeHint,
    colors: const [Palette.mathStart, Palette.mathEnd],
  );
}

/// A small gradient tile under the main ones (tournament, math).
class _SmallModeTile extends StatelessWidget {
  const _SmallModeTile({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.hint,
    required this.colors,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String hint;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(20);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .92),
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

/// A mode that needs the server while its address is not known yet (a
/// first launch without internet): muted, not tappable.
class _SoonTile extends StatelessWidget {
  const _SoonTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: .8);
    return Semantics(
      enabled: false,
      label: '$title ${AppStrings.needsInternet}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.needsInternet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
