part of 'share_card.dart';

/// What the month-end card shows: one table's month and mode, and the
/// player's own line in it.
@immutable
class RankedCardData {
  const RankedCardData({
    required this.month,
    required this.math,
    required this.players,
    required this.me,
    required this.look,
  });

  final int month;
  final bool math;
  final int players;
  final RankedRow me;
  final MascotLook look;

  /// The first does a victory dance; the top three celebrate; the top half
  /// is pleased; the rest scratch their heads.
  DayMood get mood => switch (me.rank) {
    1 => DayMood.legend,
    2 || 3 => DayMood.great,
    _ when me.rank * 2 <= players => DayMood.proud,
    _ => DayMood.unsure,
  };

  String get shareText => AppStrings.monthEndShareText(
    rankedMonthLabel(month),
    math,
    me.rank,
    me.rating,
    me.played,
    me.won,
  );

  String get fileName => AppStrings.monthEndFileName(month, math);
}

/// Renders the month-end card as PNG bytes.
Future<Uint8List> renderRankedCard(RankedCardData data) async {
  final recorder = ui.PictureRecorder();
  paintRankedCard(Canvas(recorder), data);
  final image = await recorder.endRecording().toImage(
    shareCardSize.width.toInt(),
    shareCardSize.height.toInt(),
  );
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// The share card's look for a month of ranked duels: month and mode in
/// the pill, the place as headline, the player's mascot in the mood of the
/// place, and a cream panel with the rating and the month's numbers.
void paintRankedCard(Canvas c, RankedCardData data) {
  const w = 1080.0;
  final mood = data.mood;
  final medal = Medal.ofRank(data.me.rank);
  _background(c, w, shareCardSize.height);
  if (mood == DayMood.legend || mood == DayMood.great) {
    _confetti(c, dense: mood == DayMood.legend);
  }
  _text(
    c,
    AppStrings.appName,
    const Offset(w / 2, 64),
    104,
    Colors.white,
    weight: FontWeight.w800,
    letterSpacing: -3,
    centred: true,
  );
  _pill(
    c,
    '${rankedMonthLabel(data.month)} · '
    '${AppStrings.rankedModeTitle(data.math)}',
    const Offset(w / 2, 232),
    fill: Colors.white.withValues(alpha: 0.18),
    text: Colors.white,
  );
  // The place, in its medal's colour for the first three.
  _text(
    c,
    '${data.me.rank}.',
    const Offset(w / 2, 290),
    190,
    medal?.mid ?? Palette.sun,
    weight: FontWeight.w800,
    letterSpacing: -6,
    centred: true,
  );
  _text(
    c,
    AppStrings.monthEndPlace(data.me.rank, data.players),
    const Offset(w / 2, 520),
    44,
    Colors.white.withValues(alpha: 0.92),
    weight: FontWeight.w500,
    centred: true,
  );

  const headY = 830.0, scale = 470.0, panelTop = 1180.0;
  c.save();
  c.translate(w / 2, headY);
  c.scale(scale);
  Philosopher(look: data.look).paintPhilosopher(
    c,
    Offset.zero,
    1.25,
    bottom: (panelTop + 80 - headY) / scale,
    mood: mood,
  );
  c.restore();

  // The panel: the rating large, then four numbers.
  const panel = Rect.fromLTWH(70, panelTop, w - 140, 560);
  c.drawRRect(
    RRect.fromRectAndRadius(panel, const Radius.circular(56)),
    Paint()..color = _cream,
  );
  _text(
    c,
    AppStrings.rankedRating.toUpperCase(),
    const Offset(w / 2, panelTop + 44),
    34,
    _grey,
    weight: FontWeight.w700,
    letterSpacing: 4,
    centred: true,
  );
  _text(
    c,
    '${data.me.rating}',
    const Offset(w / 2, panelTop + 90),
    150,
    _indigoText,
    weight: FontWeight.w800,
    letterSpacing: -5,
    centred: true,
  );
  final stats = [
    (AppStrings.rankedPlayed, '${data.me.played}'),
    (AppStrings.rankedWon, '${data.me.won}'),
    (AppStrings.rankedAverage, '${data.me.average}'),
    (AppStrings.rankedHitRate, AppStrings.rankedPercent(data.me.hitRate)),
  ];
  const colWidth = (w - 140) / 4;
  for (final (i, (label, value)) in stats.indexed) {
    final x = 70 + colWidth * i + colWidth / 2;
    _text(
      c,
      value,
      Offset(x, panelTop + 320),
      78,
      _indigoText,
      weight: FontWeight.w800,
      centred: true,
      width: colWidth,
    );
    _text(
      c,
      label,
      Offset(x, panelTop + 420),
      34,
      _grey,
      weight: FontWeight.w600,
      centred: true,
      width: colWidth,
    );
  }

  _pill(
    c,
    AppStrings.shareCardInvite,
    const Offset(w / 2, 1838),
    fill: Palette.sun,
    text: Palette.onSun,
    size: 46,
    padX: 64,
    padY: 30,
  );
}
