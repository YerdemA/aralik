import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mascot_look.dart';
import '../core/reaction.dart';
import '../core/strings.dart';
import '../data/sound.dart';
import 'philosopher.dart';

/// Quick reactions in duels and tournaments (core/reaction.dart): a half
/// disc on the right edge ([ReactionButton] in a [ReactionDock]); hold it,
/// slide onto a face or a message in the fan that opens and let go (a tap
/// opens the same fan to tap on). What arrives, and what this player sends,
/// shows for a moment with its sound ([ReactionFeed], [ReactionStrip]).

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

/// A face's light motion, in its mood: the angry one shakes, the laughing
/// one bounces, the sad one sways and droops, the surprised one pulses.
/// Plays [cycles] times after [delay], again when [trigger] changes, then
/// rests (never a loop: nothing keeps the screen busy). Still when the
/// phone asks for less motion.
class ReactionMotion extends StatefulWidget {
  const ReactionMotion({
    super.key,
    required this.reaction,
    required this.child,
    this.trigger,
    this.cycles,
    this.delay = Duration.zero,
  });

  final Reaction reaction;
  final Widget child;
  final Object? trigger;

  /// How many times; by default as many as fill the time a reaction shows.
  final int? cycles;
  final Duration delay;

  /// One cycle of each face's motion.
  static Duration periodOf(Reaction r) => Duration(
    milliseconds: switch (r) {
      Reaction.angry => 520,
      Reaction.laugh => 560,
      Reaction.sad => 1500,
      _ => 1000,
    },
  );

  @override
  State<ReactionMotion> createState() => _ReactionMotionState();
}

class _ReactionMotionState extends State<ReactionMotion>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);

  Duration get _period => ReactionMotion.periodOf(widget.reaction);

  int get _cycles =>
      widget.cycles ??
      ((reactionShown.inMilliseconds - 600) ~/ _period.inMilliseconds).clamp(
        1,
        8,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(ReactionMotion old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _play();
  }

  void _play() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _c.duration = widget.delay + _period * _cycles;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final total = _c.duration?.inMicroseconds ?? 0;
      final elapsed = _c.value * total - widget.delay.inMicroseconds;
      if (!_c.isAnimating || elapsed <= 0) return child!;
      final cycles = elapsed / _period.inMicroseconds;
      final t = cycles - cycles.floor();
      // Fades out over the last cycle, so it never stops with a jerk.
      final left = (_cycles - cycles).clamp(0.0, 1.0);
      final wave = math.sin(2 * math.pi * t);
      return switch (widget.reaction) {
        // A quick shake, a little tilt.
        Reaction.angry => Transform.translate(
          offset: Offset(2.2 * math.sin(4 * math.pi * t) * left, 0),
          child: Transform.rotate(angle: 0.06 * wave * left, child: child),
        ),
        // Hops up, rocks side to side.
        Reaction.laugh => Transform.translate(
          offset: Offset(0, -3.5 * math.sin(math.pi * t).abs() * left),
          child: Transform.rotate(angle: 0.08 * wave * left, child: child),
        ),
        // Sways slowly and droops.
        Reaction.sad => Transform.translate(
          offset: Offset(0, 1.8 * (1 - math.cos(2 * math.pi * t)) * left),
          child: Transform.rotate(angle: 0.09 * wave * left, child: child),
        ),
        // A pulse.
        _ => Transform.scale(
          scale: 1 + 0.09 * math.sin(math.pi * t) * left,
          child: child,
        ),
      };
    },
  );
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
    Sounds.play(Sfx.ofReaction(shown.reaction));
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
        ? ReactionMotion(
            reaction: r,
            child: Container(
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

/// Places [ReactionButton] on the screen's right edge, a little above the
/// middle. A child of the screen's body [Stack]; lets every other touch
/// through.
class ReactionDock extends StatelessWidget {
  const ReactionDock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Align(alignment: const Alignment(1, -0.45), child: child),
  );
}

/// The edge tab: half a disc in the theme's colour stuck to the right edge
/// ([ReactionDock]). Hold it: a fan of two half rings opens from it, the
/// faces inside and the messages outside; slide onto one and let go.
/// Letting go anywhere else closes it. A tap opens the same fan to tap on.
/// Rests for [reactionCooldown] after each.
class ReactionButton extends StatefulWidget {
  const ReactionButton({
    super.key,
    required this.look,
    required this.onSelected,
  });

  /// This player's mascot, for the faces.
  final MascotLook look;
  final ValueChanged<Reaction> onSelected;

  /// The visible half disc.
  static const double radius = 24;

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  late final _fan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 160),
  );
  OverlayEntry? _entry;
  final _selected = ValueNotifier<Reaction?>(null);
  final _keys = {for (final r in Reaction.values) r: GlobalKey()};
  bool _resting = false;
  Timer? _rest;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _fan.dispose();
    _rest?.cancel();
    _selected.dispose();
    super.dispose();
  }

  void _open({required bool tapMode}) {
    if (_resting) return;
    if (_entry != null) {
      if (_fan.status != AnimationStatus.reverse) return;
      _remove();
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final center = box.localToGlobal(
      Offset(box.size.width, box.size.height / 2),
    );
    _selected.value = null;
    HapticFeedback.lightImpact();
    Sounds.play(Sfx.reactOpen);
    _entry = OverlayEntry(
      builder: (context) => _Fan(
        center: center,
        animation: _fan,
        look: widget.look,
        keys: _keys,
        selected: _selected,
        tapMode: tapMode,
        onPick: _pick,
        onDismiss: _close,
      ),
    );
    Overlay.of(context).insert(_entry!);
    _fan.forward(from: 0);
    setState(() {});
  }

  /// Folds the fan away, then takes it off the screen.
  void _close() {
    final entry = _entry;
    if (entry == null) return;
    _fan.reverse().whenComplete(() {
      if (_entry == entry) _remove();
    });
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
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
    const r = ReactionButton.radius;
    final open = _entry != null;
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
        onLongPressCancel: _close,
        // A little wider and taller than the disc, for the thumb.
        child: SizedBox(
          width: r + 10,
          height: 2 * r + 12,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              opacity: _resting ? 0.45 : 1,
              duration: const Duration(milliseconds: 200),
              child: AnimatedScale(
                scale: open ? 0.9 : 1,
                alignment: Alignment.centerRight,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: r,
                  height: 2 * r,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(r),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(-1, 2),
                        color: Color(0x33000000),
                      ),
                    ],
                  ),
                  alignment: const Alignment(0.2, 0),
                  child: Icon(
                    Icons.emoji_emotions_rounded,
                    size: 19,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The fan: two half rings around [center] (on the right edge), in colours
/// of its own for light and dark ([_FanPalette]). The inner ring holds the
/// faces, the outer one the messages. Opens softly from the tab, the outer
/// ring a moment later.
class _Fan extends StatelessWidget {
  const _Fan({
    required this.center,
    required this.animation,
    required this.look,
    required this.keys,
    required this.selected,
    required this.tapMode,
    required this.onPick,
    required this.onDismiss,
  });

  final Offset center;
  final Animation<double> animation;
  final MascotLook look;
  final Map<Reaction, GlobalKey> keys;
  final ValueNotifier<Reaction?> selected;
  final bool tapMode;
  final ValueChanged<Reaction> onPick;
  final VoidCallback onDismiss;

  /// Radii: where the faces sit, the inner ring's edge, where the messages
  /// sit, the outer ring's edge.
  static const double faceRing = 56;
  static const double inner = 80;
  static const double messageRing = 122;
  static const double outer = 166;
  static const double faceSize = 30;

  /// Angles from straight left, upwards negative.
  static const _faceAngles = [-60.0, -20.0, 20.0, 60.0];
  static const _messageAngles = {
    Reaction.easy: -50.0,
    Reaction.close: -16.0,
    Reaction.congrats: 16.0,
    // The long one, two lines: lowest, where the ring is widest.
    Reaction.lucky: 54.0,
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final p = _FanPalette.of(context);
    final lo = media.padding.top + outer + 8;
    final hi = media.size.height - media.padding.bottom - outer - 8;
    final c = Offset(
      center.dx,
      lo <= hi ? center.dy.clamp(lo, hi) : media.size.height / 2,
    );
    final first = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final second = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final faces = Reaction.values.where((r) => r.isFace).toList();
    return AnimatedBuilder(
      animation: animation,
      // Folding away: touches go through.
      builder: (context, child) => IgnorePointer(
        ignoring: animation.status == AnimationStatus.reverse,
        child: child,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: first,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: ColoredBox(color: p.scrim),
              ),
            ),
          ),
          _layer(
            c,
            outer,
            second,
            _HalfDisc(colors: p.outer, edge: p.edge, shadow: p.shadow),
            [
              for (final MapEntry(key: r, value: angle)
                  in _messageAngles.entries)
                (messageRing, angle, _message(context, p, r)),
            ],
          ),
          _layer(
            c,
            inner,
            first,
            _HalfDisc(colors: p.inner, edge: p.edge, shadow: p.shadow),
            [
              for (var i = 0; i < faces.length; i++)
                (faceRing, _faceAngles[i], _face(p, faces[i])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _layer(
    Offset c,
    double radius,
    Animation<double> anim,
    CustomPainter painter,
    List<(double, double, Widget)> items,
  ) => Positioned(
    left: c.dx - radius,
    top: c.dy - radius,
    width: radius,
    height: 2 * radius,
    child: FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.3, end: 1).animate(anim),
        alignment: Alignment.centerRight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: painter)),
            for (final (ring, angle, child) in items)
              Positioned(
                left: radius - ring * math.cos(angle * math.pi / 180),
                top: radius + ring * math.sin(angle * math.pi / 180),
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: child,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _item(Reaction r, Widget Function(bool on) child) => Semantics(
    button: true,
    label: r.label,
    child: GestureDetector(
      onTap: tapMode ? () => onPick(r) : null,
      child: ValueListenableBuilder(
        valueListenable: selected,
        builder: (context, sel, _) => child(sel == r),
      ),
    ),
  );

  Widget _face(_FanPalette p, Reaction r) => _item(
    r,
    (on) => AnimatedScale(
      key: keys[r],
      scale: on ? 1.25 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      // Once as the fan opens, again whenever the finger comes onto it.
      child: ReactionMotion(
        reaction: r,
        trigger: on,
        cycles: on ? 2 : 1,
        delay: on ? Duration.zero : const Duration(milliseconds: 220),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on ? _FanPalette.glow : null,
            color: on ? null : p.chip,
          ),
          child: ClipOval(
            child: ColoredBox(
              color: p.faceBack,
              child: ReactionFace(look: look, reaction: r, size: faceSize),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _message(BuildContext context, _FanPalette p, Reaction r) => _item(
    r,
    (on) => AnimatedScale(
      key: keys[r],
      scale: on ? 1.1 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(maxWidth: 98),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: on ? _FanPalette.glow : null,
          color: on ? null : p.chip,
        ),
        child: Text(
          r.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: on ? _FanPalette.onGlow : p.text,
          ),
        ),
      ),
    ),
  );
}

/// The left half of a disc whose centre is the box's right middle.
class _HalfDisc extends CustomPainter {
  const _HalfDisc({required this.colors, required this.edge, this.shadow});

  /// From the centre out.
  final List<Color> colors;

  /// The hairline on the curve.
  final Color edge;
  final Color? shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: size.width);
    final path = Path()
      ..moveTo(c.dx, 0)
      ..arcTo(rect, -math.pi / 2, -math.pi, false)
      ..close();
    final shadow = this.shadow;
    if (shadow != null) canvas.drawShadow(path, shadow, 10, false);
    canvas.drawPath(
      path,
      Paint()..shader = RadialGradient(colors: colors).createShader(rect),
    );
    // A hairline on the curve.
    canvas.drawArc(
      rect.deflate(0.5),
      -math.pi / 2,
      -math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  /// Touches go to the items, or through to close the fan.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_HalfDisc old) =>
      old.edge != edge || old.shadow != shadow || old.colors != colors;
}

/// The fan's own colours, one set for a light and one for a dark theme;
/// none of them the page's.
@immutable
class _FanPalette {
  const _FanPalette({
    required this.outer,
    required this.inner,
    required this.edge,
    required this.chip,
    required this.text,
    required this.faceBack,
    required this.scrim,
    required this.shadow,
  });

  /// Pearl white, a breath of lilac towards the edge.
  static const light = _FanPalette(
    outer: [Color(0xFFFFFFFF), Color(0xFFF2EEF9)],
    inner: [Color(0xFFF6F2FC), Color(0xFFE8E1F3)],
    edge: Color(0x141C1929),
    chip: Color(0x0F1C1929),
    text: Color(0xFF2A2440),
    faceBack: Color(0xFFFFFFFF),
    scrim: Color(0x14000000),
    shadow: Color(0x99000000),
  );

  /// Ink a step lighter than the dark page, so the fan stands out.
  static const dark = _FanPalette(
    outer: [Color(0xFF3A3552), Color(0xFF2A2640)],
    inner: [Color(0xFF4A4468), Color(0xFF3A3552)],
    edge: Color(0x38FFFFFF),
    chip: Color(0x17FFFFFF),
    text: Color(0xF0FFFFFF),
    faceBack: Color(0xFFF6EFE4),
    scrim: Color(0x40000000),
    shadow: Color(0xFF000000),
  );

  static _FanPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The chosen item, in both.
  static const glow = LinearGradient(
    colors: [Color(0xFFFFC960), Color(0xFFFF8A5B)],
  );
  static const onGlow = Color(0xFF1C1929);

  /// From the centre out.
  final List<Color> outer;
  final List<Color> inner;
  final Color edge;
  final Color chip;
  final Color text;
  final Color faceBack;
  final Color scrim;
  final Color shadow;
}
