import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/strings.dart';
import '../../data/leaderboard.dart';
import 'nickname_sheet.dart';

/// Today's board: the best players, the player's own rank, and the one
/// thing to do next (join, finish the set, or retry sending).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.store,
    required this.day,
    required this.dayDone,
  });

  final LeaderboardStore store;
  final int day;

  /// Whether the player finished [day]'s set.
  final bool dayDone;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardBoard? _board;
  LeaderboardFailure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    await widget.store.submitPending(widget.day);
    try {
      final board = await widget.store.fetchBoard(widget.day);
      if (mounted) setState(() => _board = board);
    } on LeaderboardException catch (e) {
      if (mounted) setState(() => _failure = e.failure);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    if (!await showNicknameSheet(context, widget.store) || !mounted) return;
    final name = widget.store.account?.nickname ?? '';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppStrings.joinedAs(name))));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = _board;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.leaderboard)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _Header(day: widget.day, players: board?.players),
                    const SizedBox(height: 12),
                    if (board == null && _loading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (board == null)
                      _Message(
                        text: leaderboardFailureText(
                          _failure ?? LeaderboardFailure.server,
                        ),
                        icon: Icons.cloud_off_rounded,
                        action: OutlinedButton(
                          onPressed: _loading ? null : _load,
                          child: const Text(AppStrings.retry),
                        ),
                      )
                    else if (board.top.isEmpty)
                      const _Message(
                        text: AppStrings.leaderboardEmpty,
                        icon: Icons.emoji_events_outlined,
                      )
                    else
                      ..._rows(board),
                  ],
                ),
              ),
            ),
            ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) => _Footer(
                joined: widget.store.joined,
                dayDone: widget.dayDone,
                onBoard: board?.me != null,
                loaded: board != null,
                busy: _loading,
                onJoin: _join,
                onRetry: _load,
                textStyle: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(LeaderboardBoard board) {
    final nickname = widget.store.account?.nickname;
    final me = board.me;
    return [
      for (final e in board.top)
        _Row(entry: e, nickname: e.nickname ?? nickname ?? AppStrings.you),
      if (me != null && !board.meInTop) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Center(child: Icon(Icons.more_vert_rounded)),
        ),
        _Row(entry: me, nickname: nickname ?? AppStrings.you),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.day, required this.players});

  final int day;
  final int? players;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            dayLabel(dateOfDay(day)),
            if (players != null) AppStrings.leaderboardPlayers(players!),
          ].join(' · '),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          AppStrings.leaderboardResets,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The podium's frames: gold, silver and bronze for the first three.
enum Medal {
  gold(Color(0xFFFFE9A6), Color(0xFFF2C230), Color(0xFFA87A00)),
  silver(Color(0xFFF3F6FA), Color(0xFFC3CAD4), Color(0xFF6E7887)),
  bronze(Color(0xFFF8D6BA), Color(0xFFD38B52), Color(0xFF8A4A1C));

  const Medal(this.light, this.mid, this.dark);

  /// Shine, body and shadow of the metal.
  final Color light;
  final Color mid;
  final Color dark;

  /// The medal of [rank], or null from 4th place on.
  static Medal? ofRank(int rank) =>
      rank >= 1 && rank <= values.length ? values[rank - 1] : null;

  /// A metallic sweep, shine at the top left.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [light, mid, dark, mid],
    stops: const [0, .35, .75, 1],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.nickname});

  final LeaderboardEntry entry;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = Medal.ofRank(entry.rank);
    final isLight = theme.brightness == Brightness.light;
    final cardColor = theme.cardTheme.color ?? scheme.surfaceContainer;
    // The player's own row sits on primaryContainer: text to match.
    final onRow = entry.isMe ? scheme.onPrimaryContainer : null;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: medal == Medal.gold ? 14 : 10,
      ),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank, medal: medal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '$nickname (${AppStrings.you})' : nickname,
                  style: theme.textTheme.titleMedium?.copyWith(color: onRow),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppStrings.hitsOutOf(entry.hits, questionsPerDay),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        onRow?.withValues(alpha: .8) ?? scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.points}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: medal == null
                  ? onRow
                  : isLight
                  ? medal.dark
                  : medal.light,
            ),
          ),
        ],
      ),
    );
    if (medal == null) {
      return Card(
        color: entry.isMe ? scheme.primaryContainer : null,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      );
    }
    // A metal frame around a lightly tinted card; gold also glows.
    const radius = 18.0;
    final inner = entry.isMe ? scheme.primaryContainer : cardColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: EdgeInsets.all(medal == Medal.gold ? 3 : 2.5),
      decoration: BoxDecoration(
        gradient: medal.gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: medal.mid.withValues(alpha: medal == Medal.gold ? .45 : .25),
            blurRadius: medal == Medal.gold ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 2.5),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.alphaBlend(
                medal.mid.withValues(alpha: isLight ? .22 : .18),
                inner,
              ),
              inner,
            ],
          ),
        ),
        child: content,
      ),
    );
  }
}

/// The rank in a circle: a metal coin with a laurel for the podium, plain
/// grey for the rest.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.medal});

  final int rank;
  final Medal? medal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = this.medal;
    final size = medal == Medal.gold ? 44.0 : 38.0;
    final number = Text(
      '$rank',
      style: theme.textTheme.titleMedium?.copyWith(
        color: medal == null ? scheme.onSurface : Colors.white,
        fontWeight: FontWeight.w800,
        shadows: medal == null
            ? null
            : [Shadow(color: medal.dark, blurRadius: 3)],
      ),
    );
    if (medal == null) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHigh,
        ),
        child: number,
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: medal.gradient,
            border: Border.all(color: medal.dark, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                medal == Medal.gold
                    ? Icons.emoji_events_rounded
                    : Icons.workspace_premium_rounded,
                size: size * .78,
                color: medal.light.withValues(alpha: .45),
              ),
              number,
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon, this.action});

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            text,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// The screen's single next step.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.joined,
    required this.dayDone,
    required this.onBoard,
    required this.loaded,
    required this.busy,
    required this.onJoin,
    required this.onRetry,
    required this.textStyle,
  });

  final bool joined;
  final bool dayDone;
  final bool onBoard;
  final bool loaded;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onRetry;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final Widget? child;
    if (!joined) {
      child = FilledButton.icon(
        onPressed: busy ? null : onJoin,
        icon: const Icon(Icons.emoji_events_rounded),
        label: const Text(AppStrings.leaderboardJoin),
      );
    } else if (!dayDone) {
      child = Text(
        AppStrings.leaderboardFinishSet,
        style: textStyle,
        textAlign: TextAlign.center,
      );
    } else if (loaded && !onBoard) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.leaderboardSendFailed,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : onRetry,
            child: const Text(AppStrings.retry),
          ),
        ],
      );
    } else {
      child = null;
    }
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: child,
    );
  }
}
