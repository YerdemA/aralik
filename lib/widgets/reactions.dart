import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mascot_look.dart';
import '../core/reaction.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'philosopher.dart';

/// Quick reactions in duels and tournaments (core/reaction.dart): a small
/// bubble button ([ReactionButton]); hold it, slide onto a face or a message
/// and let go (a tap opens the same panel to tap on). What arrives, and what
/// this player sends, shows for a moment ([ReactionFeed], [ReactionStrip]).

MascotFace _faceOf(Reaction r) => switch (r) {
  Reaction.angry => MascotFace.angry,
  Reaction.laugh => MascotFace.laugh,
  Reaction.sad => MascotFace.sad,
  _ => MascotFace.wow,
};

/// A player's mascot pulling a reaction's face.
class ReactionFace extends StatelessWidget {
  const ReactionFace({
    super.key,
    required this.look,
    required this.reaction,
    required this.size,
  });

  final MascotLook look;
  final Reaction reaction;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _FacePainter(look, _faceOf(reaction)),
      ),
    ),
  );
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.look, this.face);

  final MascotLook look;
  final MascotFace face;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));
    // Closer than the portrait: the face is the message.
    Philosopher(look: look)
        .paintPhilosopher(canvas, const Offset(0.5, 0.6), 1.75, face: face);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.look != look || old.face != face;
}

/// One reaction on screen.
@immutable
class ShownReaction {
  const ShownReaction({
    required this.reaction,
    required this.look,
    required this.color,
    this.name,
    this.mine = false,
  });

  final Reaction reaction;
  final MascotLook look;

  /// The player's colour (the ring around a face, the bubble's edge).
  final Color color;

  /// Shown above the bubble (tournaments; a duel has only two players).
  final String? name;
  final bool mine;
}

/// The reactions on screen now, each for [reactionShown]; at most [max].
class ReactionFeed extends ChangeNotifier {
  ReactionFeed({this.max = 3});

  final int max;
  final List<(int, ShownReaction)> _items = [];
  final List<Timer> _timers = [];
  int _serial = 0;
  bool _disposed = false;

  List<(int, ShownReaction)> get items => List.unmodifiable(_items);

  void add(ShownReaction shown) {
    if (_disposed) return;
    final key = _serial++;
    _items.add((key, shown));
    if (_items.length > max) _items.removeAt(0);
    _timers.add(
      Timer(reactionShown, () {
        if (_disposed) return;
        _items.removeWhere((e) => e.$1 == key);
        notifyListeners();
      }),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

/// The feed as a band of fixed height ([ReactionStrip.height]): this
/// player's newest reaction on the left, the others' newest on the right.
/// It never grows or covers anything, and lets touches through.
class ReactionStrip extends StatelessWidget {
  const ReactionStrip({super.key, required this.feed, this.others = 1});

  final ReactionFeed feed;

  /// How many of the others' reactions show at once (2 in tournaments).
  final int others;

  static const double height = 52;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      height: height,
      child: ListenableBuilder(
        listenable: feed,
        builder: (context, _) {
          final items = feed.items;
          final mine = [
            for (final e in items)
              if (e.$2.mine) e,
          ];
          final theirs = [
            for (final e in items)
              if (!e.$2.mine) e,
          ];
          Widget pop((int, ShownReaction) e) => _Pop(
            key: ValueKey(e.$1),
            child: _Bubble(shown: e.$2),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (mine.isNotEmpty) pop(mine.last),
              const Spacer(),
              for (final e in theirs.skip(
                theirs.length > others ? theirs.length - others : 0,
              )) ...[const SizedBox(width: 6), pop(e)],
            ],
          );
        },
      ),
    ),
  );
}

/// Pops in, then fades out just before the feed drops it.
class _Pop extends StatefulWidget {
  const _Pop({super.key, required this.child});

  final Widget child;

  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> {
  bool _in = false;
  bool _out = false;
  Timer? _fade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
    _fade = Timer(reactionShown - const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _out = true);
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _in && !_out ? 1 : 0,
    duration: const Duration(milliseconds: 250),
    child: AnimatedScale(
      scale: _in ? 1 : 0.6,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.shown});

  final ShownReaction shown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = shown.reaction;
    final body = r.isFace
        ? Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
              border: Border.all(color: shown.color, width: 2.5),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Color(0x26000000)),
              ],
            ),
            child: ClipOval(
              child: ReactionFace(
                look: shown.look,
                reaction: r,
                size: shown.name == null ? 44 : 34,
              ),
            ),
          )
        : Container(
            constraints: const BoxConstraints(maxWidth: 170),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: shown.color, width: 2),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Color(0x26000000)),
              ],
            ),
            child: Text(
              r.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          );
    final name = shown.name;
    return Semantics(
      liveRegion: true,
      label: name == null ? r.label : '$name: ${r.label}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: shown.mine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 1, left: 4, right: 4),
                child: Text(
                  name,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: shown.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// The small bubble button. Hold it, slide onto a reaction and let go; or
/// tap it and tap one. Rests for [reactionCooldown] after each.
class ReactionButton extends StatefulWidget {
  const ReactionButton({
    super.key,
    required this.look,
    required this.onSelected,
  });

  /// This player's mascot, for the faces.
  final MascotLook look;
  final ValueChanged<Reaction> onSelected;

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  OverlayEntry? _entry;
  final _selected = ValueNotifier<Reaction?>(null);
  final _keys = {for (final r in Reaction.values) r: GlobalKey()};
  bool _resting = false;
  Timer? _rest;

  @override
  void dispose() {
    _close();
    _rest?.cancel();
    _selected.dispose();
    super.dispose();
  }

  void _open({required bool tapMode}) {
    if (_resting || _entry != null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    _selected.value = null;
    HapticFeedback.selectionClick();
    _entry = OverlayEntry(
      builder: (context) => _Panel(
        anchor: origin & box.size,
        look: widget.look,
        keys: _keys,
        selected: _selected,
        tapMode: tapMode,
        onPick: _pick,
        onDismiss: _close,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  Reaction? _hit(Offset global) {
    for (final MapEntry(:key, :value) in _keys.entries) {
      final box = value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.inflate(4).contains(global)) return key;
    }
    return null;
  }

  void _slide(Offset global) {
    final hit = _hit(global);
    if (hit != _selected.value) {
      _selected.value = hit;
      if (hit != null) HapticFeedback.selectionClick();
    }
  }

  void _pick(Reaction reaction) {
    _close();
    widget.onSelected(reaction);
    setState(() => _resting = true);
    _rest = Timer(reactionCooldown, () {
      if (mounted) setState(() => _resting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppStrings.reactionButton,
      hint: AppStrings.reactionHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(tapMode: true),
        onLongPressStart: (d) => _open(tapMode: false),
        onLongPressMoveUpdate: (d) => _slide(d.globalPosition),
        onLongPressEnd: (d) {
          final pick = _hit(d.globalPosition);
          if (pick != null) {
            _pick(pick);
          } else {
            _close();
          }
        },
        child: SizedBox(
          width: 36,
          height: 48,
          child: Center(
            child: AnimatedOpacity(
              opacity: _resting ? 0.4 : 1,
              duration: const Duration(milliseconds: 200),
              // Like the app bar's other small chips (the opponent's
              // hourglass): a pale circle in the theme's colour.
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_reaction_outlined,
                  size: 17,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The eight reactions under the button: faces in a row, messages below.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.anchor,
    required this.look,
    required this.keys,
    required this.selected,
    required this.tapMode,
    required this.onPick,
    required this.onDismiss,
  });

  final Rect anchor;
  final MascotLook look;
  final Map<Reaction, GlobalKey> keys;
  final ValueNotifier<Reaction?> selected;
  final bool tapMode;
  final ValueChanged<Reaction> onPick;
  final VoidCallback onDismiss;

  static const double width = 248;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final left = (anchor.right - width).clamp(8.0, screen.width - width - 8);
    Widget item(
      Reaction r,
      Widget Function(bool on) child, {
      required bool round,
    }) => ValueListenableBuilder(
      valueListenable: selected,
      builder: (context, sel, _) {
        final on = sel == r;
        return GestureDetector(
          onTap: tapMode ? () => onPick(r) : null,
          child: AnimatedScale(
            key: keys[r],
            scale: on ? (round ? 1.15 : 1.05) : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: on ? Palette.sun : scheme.surfaceContainerHigh,
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round ? null : BorderRadius.circular(14),
                border: Border.all(
                  color: on ? Palette.onSun : Colors.transparent,
                  width: 2,
                ),
              ),
              child: child(on),
            ),
          ),
        );
      },
    );
    return Stack(
      children: [
        // Outside the panel: closes it (only reached when tapping).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: anchor.bottom + 4,
          width: width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final r in Reaction.values.where((r) => r.isFace))
                        Semantics(
                          button: true,
                          label: r.label,
                          child: item(
                            r,
                            (_) => ClipOval(
                              child: ReactionFace(
                                look: look,
                                reaction: r,
                                size: 44,
                              ),
                            ),
                            round: true,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final r in Reaction.values.where((r) => !r.isFace))
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: item(
                        r,
                        (on) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            r.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: on ? Palette.onSun : null,
                                ),
                          ),
                        ),
                        round: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
