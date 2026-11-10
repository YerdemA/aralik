part of 'share_card.dart';

/// Renders a duel or tournament result card as PNG bytes.
Future<Uint8List> renderMatchShareCard(MatchShare data) async {
  final recorder = ui.PictureRecorder();
  paintMatchShareCard(Canvas(recorder), data);
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

/// The daily card's look for a duel or a tournament: the mode in the pill,
/// the outcome as headline, the philosophers (a duel: both, on the duel
/// screen's podium poses; a tournament: this player, in the mood of the
/// place) and a cream panel with the scores.
void paintMatchShareCard(Canvas c, MatchShare data) {
  const w = 1080.0;
  final mood = data.isDuel
      ? switch (data.outcome) {
          MatchOutcome.win => DayMood.great,
          MatchOutcome.draw => DayMood.proud,
          MatchOutcome.loss => DayMood.down,
        }
      : switch (data.rank) {
          1 => DayMood.legend,
          2 => DayMood.great,
          3 => DayMood.proud,
          _ => DayMood.unsure,
        };

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
  _text(
    c,
    AppStrings.tagline,
    const Offset(w / 2, 196),
    38,
    Colors.white.withValues(alpha: 0.8),
    centred: true,
  );
  _pill(
    c,
    data.kind.label,
    const Offset(w / 2, 300),
    fill: Colors.white.withValues(alpha: 0.18),
    text: Colors.white,
  );
  _text(
    c,
    data.headline,
    const Offset(w / 2, 362),
    104,
    mood == DayMood.down ? Palette.sky : Palette.sun,
    weight: FontWeight.w800,
    letterSpacing: -2,
    centred: true,
  );
  _text(
    c,
    data.isDuel
        ? (data.opponentLeft
              ? AppStrings.duelOpponentLeft
              : AppStrings.duelMargin(
                  (data.me.points - data.opponent.points).abs(),
                ))
        : AppStrings.shareTournamentOf(data.rows.length),
    const Offset(w / 2, 492),
    42,
    Colors.white.withValues(alpha: 0.9),
    weight: FontWeight.w500,
    centred: true,
  );

  if (data.isDuel) {
    _duelFigures(c, data);
    _duelPanel(c, data, w);
  } else {
    final top = _tournamentPanelTop(data.rows.length);
    // The philosopher shrinks as the list grows.
    final room = math.min(1.0, (top - 560) / (1290 - 560));
    final scale = 560 * room, headY = 560 + 290 * room;
    c.save();
    c.translate(w / 2, headY);
    c.scale(scale);
    const Philosopher().paintPhilosopher(
      c,
      Offset.zero,
      1.25,
      bottom: (top + 80 - headY) / scale,
      mood: mood,
    );
    c.restore();
    _tournamentPanel(c, data, w, top);
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

/// Both duelists in their end poses, in their sashes.
void _duelFigures(Canvas c, MatchShare data) {
  final (me, them) = switch (data.outcome) {
    MatchOutcome.win => (DuelPose.champion, DuelPose.defeated),
    MatchOutcome.loss => (DuelPose.defeated, DuelPose.champion),
    MatchOutcome.draw => (DuelPose.even, DuelPose.even),
  };
  const size = 520.0, top = 600.0;
  for (final (x, pose, sash) in [
    (20.0, me, Palette.duelMe),
    (540.0, them, Palette.duelOpponent),
  ]) {
    c.save();
    c.translate(x, top);
    DuelistPainter(pose: pose, sash: sash).paint(c, const Size.square(size));
    c.restore();
  }
}

RRect _creamPanel(Canvas c, double w, double top) {
  final panel = RRect.fromLTRBR(
    64,
    top,
    w - 64,
    1760,
    const Radius.circular(56),
  );
  c.drawRRect(
    panel.shift(const Offset(0, 20)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
  );
  c.drawRRect(panel, Paint()..color = _cream);
  return panel;
}

/// Two lines: the name in the player's colour, the total, the squares.
void _duelPanel(Canvas c, MatchShare data, double w) {
  const top = 1150.0;
  _creamPanel(c, w, top);
  const tiers = GameColors.light;
  for (final (k, (row, colour)) in [
    (data.me, Palette.duelMe),
    (data.opponent, Palette.duelOpponent),
  ].indexed) {
    final y = top + 50 + k * 290;
    final name = row.label;
    c.drawCircle(Offset(134, y + 32), 18, Paint()..color = colour);
    _text(
      c,
      name,
      Offset(170, y),
      52,
      colour,
      weight: FontWeight.w800,
      width: 560,
    );
    final total = _paragraph(
      '${row.points}',
      88,
      _indigoText,
      FontWeight.w800,
      -2,
      400,
      TextAlign.right,
    );
    c.drawParagraph(total, Offset(w - 120 - 400, y - 18));
    const square = 104.0, gap = 26.0;
    final n = row.tiers.length;
    final x0 = (w - n * square - (n - 1) * gap) / 2;
    for (final (i, t) in row.tiers.indexed) {
      final x = x0 + i * (square + gap);
      c.drawRRect(
        RRect.fromLTRBR(
          x,
          y + 110,
          x + square,
          y + 110 + square,
          const Radius.circular(28),
        ),
        Paint()..color = tiers.forTier(t),
      );
    }
  }
}

double _tournamentPanelTop(int rows) => 1760 - (150 + rows * 76.0);

/// The standings: place (gold, silver, bronze), name, points; this
/// player's line tinted.
void _tournamentPanel(Canvas c, MatchShare data, double w, double top) {
  _creamPanel(c, w, top);
  _text(
    c,
    AppStrings.shareMatchStandings,
    Offset(120, top + 40),
    38,
    _grey,
    weight: FontWeight.w600,
  );
  for (final (k, row) in data.rows.indexed) {
    final y = top + 110 + k * 76.0;
    if (row.me) {
      c.drawRRect(
        RRect.fromLTRBR(96, y - 6, w - 96, y + 70, const Radius.circular(24)),
        Paint()..color = Palette.duelMe.withValues(alpha: 0.12),
      );
    }
    final medal = Medal.ofRank(k + 1);
    c.drawCircle(
      Offset(150, y + 32),
      28,
      Paint()..color = medal?.mid ?? const Color(0xFFE6E1F0),
    );
    _text(
      c,
      '${k + 1}',
      Offset(150, y + 10),
      34,
      medal == null ? _indigoText : Colors.white,
      weight: FontWeight.w800,
      centred: true,
      width: 80,
    );
    final name = [
      row.label,
      if (row.left) '· ${AppStrings.tournamentLeft}',
    ].join(' ');
    _text(
      c,
      name,
      Offset(204, y + 6),
      44,
      row.left ? _grey : _indigoText,
      weight: row.me ? FontWeight.w800 : FontWeight.w600,
      width: 560,
    );
    final points = _paragraph(
      '${row.points}',
      48,
      _indigoText,
      FontWeight.w800,
      0,
      300,
      TextAlign.right,
    );
    c.drawParagraph(points, Offset(w - 124 - 300, y + 4));
  }
}
