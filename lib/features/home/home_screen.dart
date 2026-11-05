import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/question_timer.dart';
import '../../core/free_play.dart';
import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/app_update.dart';
import '../../data/duel_client.dart';
import '../../data/store_link.dart';
import '../../data/leaderboard.dart';
import '../../data/question_repository.dart';
import '../../data/settings_store.dart';
import '../../data/stats_store.dart';
import '../../widgets/calibration_text.dart';
import '../../widgets/mascot.dart';
import '../../widgets/stat_tile.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';
import '../duel/duel_lobby_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../result/summary_screen.dart';
import '../settings/settings_screen.dart';
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
    this.latestAppBuild,
    this.openStore = openStorePage,
  });

  final QuestionRepository repository;
  final StatsStore stats;
  final SettingsStore settings;

  /// Null hides the leaderboard.
  final LeaderboardStore? leaderboard;

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
  }

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
    final done = _stats.dailyResults(day).length;
    final remaining = (await _repository.dailySet(day)).skip(done).toList();
    if (!mounted || remaining.isEmpty) return;
    final answers = await Navigator.of(context).push<List<RoundAnswer>>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          questions: remaining,
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
    await _showDaySummary(day);
  });

  Future<void> _showDaySummary(int day) => Navigator.of(context).push(
    MaterialPageRoute<SummaryAction>(
      builder: (_) => SummaryScreen(
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

  late final _duels = DuelService(serviceUri: () => _leaderboard?.serviceUri);

  void _openDuel() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DuelLobbyScreen(
        service: _duels,
        repository: _repository,
        stats: _stats,
        settings: widget.settings,
        suggestedName: _leaderboard?.account?.nickname,
      ),
    ),
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          SettingsScreen(settings: widget.settings, leaderboard: _leaderboard),
    ),
  );

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
            final results = _stats.dailyResults(today);
            final finished = _stats.isDayComplete(today);
            // Between today's set and free play, when there is a server.
            final duelCard = [
              if (_leaderboard?.isAvailable == true) ...[
                const SizedBox(height: 12),
                _DuelCard(onTap: _loading ? null : _openDuel),
              ],
            ];
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
                                    onPressed: () => _openLeaderboard(today),
                                    tooltip: AppStrings.leaderboard,
                                    icon: const Icon(
                                      Icons.emoji_events_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                IconButton.filledTonal(
                                  onPressed: _openStats,
                                  tooltip: AppStrings.stats,
                                  icon: const Icon(Icons.bar_chart_rounded),
                                ),
                                const SizedBox(width: 4),
                                IconButton.filledTonal(
                                  onPressed: _openSettings,
                                  tooltip: AppStrings.settings,
                                  icon: const Icon(Icons.settings_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (finished) ...[
                              _TodayDoneStrip(
                                results: results,
                                onShare: _loading
                                    ? null
                                    : () => _showDaySummary(today),
                              ),
                              ...duelCard,
                              const SizedBox(height: 12),
                              Expanded(
                                child: _FreePlayHero(
                                  mascotSize: mascotSize,
                                  onPlay: _loading ? null : _playFree,
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: _TodayCard(
                                  results: results,
                                  today: today,
                                  mascotSize: mascotSize,
                                  onPlay: _loading ? null : _playDaily,
                                ),
                              ),
                              ...duelCard,
                              const SizedBox(height: 12),
                              _FreePlayCard(onTap: _loading ? null : _playFree),
                            ],
                            const SizedBox(height: 12),
                            _StatsCard(stats: _stats, today: today),
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
    required this.mascotSize,
    required this.onPlay,
  });

  final List<QuestionResult> results;
  final int today;
  final double mascotSize;
  final VoidCallback? onPlay;

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
        icon: Icons.play_arrow_rounded,
        label: done == 0
            ? AppStrings.playToday
            : AppStrings.continueToday(done, questionsPerDay),
      ),
      children: [
        _DayPill(label: dayLabelWithWeekday(dateOfDay(today))),
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
          '${AppStrings.todayHint} '
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
  const _TodayDoneStrip({required this.results, required this.onShare});

  final List<QuestionResult> results;
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

/// Free play: the whole card starts a round.
class _FreePlayCard extends StatelessWidget {
  const _FreePlayCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _RowCard(
    colors: const [Palette.roundStart, Palette.roundEnd],
    icon: Icons.all_inclusive_rounded,
    title: AppStrings.freePlay,
    hint: AppStrings.freePlayHint,
    onTap: onTap,
  );
}

/// The duel, in its players' colours: blue against red.
class _DuelCard extends StatelessWidget {
  const _DuelCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _RowCard(
    colors: const [Palette.duelMe, Palette.duelOpponent],
    icon: Icons.bolt_rounded,
    title: AppStrings.duel,
    hint: AppStrings.duelHomeHint,
    onTap: onTap,
  );
}

/// A gradient card whose whole surface is one button.
class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final List<Color> colors;
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(24);
    final circle = Colors.white.withValues(alpha: .2);
    return AnimatedOpacity(
      opacity: onTap == null ? .6 : 1,
      duration: const Duration(milliseconds: 150),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(colors: colors),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: circle,
                    foregroundColor: Colors.white,
                    child: Icon(icon, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          hint,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
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
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
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
