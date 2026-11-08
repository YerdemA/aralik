import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/day_mood.dart';
import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/share_text.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/philosopher.dart';

/// What the daily share card shows.
@immutable
class ShareCardData {
  const ShareCardData({
    this.dayIndex,
    required this.results,
    required this.hits,
    required this.answered,
  });

  /// The daily set's day; null for a free-play round.
  final int? dayIndex;
  final List<QuestionResult> results;

  /// All-time calibration counts.
  final int hits;
  final int answered;

  int get total => totalPoints(results);

  bool get isRound => dayIndex == null;

  /// Out of: 500 for a day; a round that ran short has fewer questions.
  int get max =>
      isRound ? results.length * maxPointsPerQuestion : maxDailyPoints;

  /// The mood thresholds are for five questions: a shorter round counts
  /// as if it had five.
  DayMood get mood => DayMood.of(
    isRound && results.isNotEmpty && results.length != questionsPerDay
        ? (total * questionsPerDay / results.length).round()
        : total,
  );
}

/// Story / status size (9:16).
const Size shareCardSize = Size(1080, 1920);

/// Renders the card as PNG bytes.
Future<Uint8List> renderShareCard(ShareCardData data) async {
  final recorder = ui.PictureRecorder();
  paintShareCard(Canvas(recorder), data);
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

const _cream = Color(0xFFFFF9F1);
const _indigoText = Palette.heroBottom;
const _grey = Color(0xFF6B6680);

/// Headline and line under it for each mood.
(String, String) _moodText(DayMood mood, {required bool round}) =>
    switch (mood) {
      DayMood.great when round => (
        AppStrings.moodGreat,
        AppStrings.moodGreatRoundLine,
      ),
      DayMood.down when round => (
        AppStrings.moodDownRound,
        AppStrings.moodDownRoundLine,
      ),
      _ => _dayMoodText(mood),
    };

(String, String) _dayMoodText(DayMood mood) => switch (mood) {
  DayMood.legend => (AppStrings.moodLegend, AppStrings.moodLegendLine),
  DayMood.great => (AppStrings.moodGreat, AppStrings.moodGreatLine),
  DayMood.proud => (AppStrings.moodProud, AppStrings.moodProudLine),
  DayMood.unsure => (AppStrings.moodUnsure, AppStrings.moodUnsureLine),
  DayMood.down => (AppStrings.moodDown, AppStrings.moodDownLine),
};

/// Paints the card on a [shareCardSize] canvas, in the home screen's
/// colours: the wordmark and the date, a headline and the philosopher in
/// the mood of the day's score, and a cream score panel with the squares.
void paintShareCard(Canvas c, ShareCardData data) {
  const w = 1080.0, h = 1920.0;
  final mood = data.mood;

  _background(c, w, h);
  if (mood == DayMood.legend || mood == DayMood.great) {
    _confetti(c, dense: mood == DayMood.legend);
  }

  // Wordmark, tagline and the date.
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
    shareLabel(data.dayIndex),
    const Offset(w / 2, 300),
    fill: Colors.white.withValues(alpha: 0.18),
    text: Colors.white,
  );

  // The mood in words.
  final (headline, line) = _moodText(mood, round: data.isRound);
  _text(
    c,
    headline,
    const Offset(w / 2, 362),
    104,
    mood == DayMood.down ? Palette.sky : Palette.sun,
    weight: FontWeight.w800,
    letterSpacing: -2,
    centred: true,
  );
  _text(
    c,
    line,
    const Offset(w / 2, 492),
    42,
    Colors.white.withValues(alpha: 0.9),
    weight: FontWeight.w500,
    centred: true,
  );

  // The philosopher, his toga running behind the score panel.
  const headY = 850.0, scale = 560.0, panelTop = 1290.0;
  c.save();
  c.translate(w / 2, headY);
  c.scale(scale);
  const Philosopher().paintPhilosopher(
    c,
    Offset.zero,
    1.25,
    bottom: (panelTop + 80 - headY) / scale,
    mood: mood,
  );
  c.restore();
  if (mood == DayMood.legend) {
    for (final (x, y, r) in const [
      (190.0, 860.0, 30.0),
      (890.0, 840.0, 36.0),
      (250.0, 1010.0, 20.0),
      (840.0, 1000.0, 22.0),
    ]) {
      _sparkle(c, Offset(x, y), r, Palette.sun);
    }
  }

  _panel(c, data, w, panelTop);

  // The invitation, like the home screen's main button.
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

void _background(Canvas c, double w, double h) {
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), const [
        Palette.heroTop,
        Palette.heroBottom,
      ]),
  );
  // Soft light circles, like out-of-focus lights.
  for (final (x, y, r, a) in const [
    (960.0, 260.0, 320.0, 0.07),
    (60.0, 760.0, 260.0, 0.06),
    (1000.0, 1180.0, 200.0, 0.05),
  ]) {
    c.drawCircle(
      Offset(x, y),
      r,
      Paint()..color = Colors.white.withValues(alpha: a),
    );
  }
  // Faint "≈" marks: kabaca means "roughly".
  for (final (x, y, size) in const [
    (110.0, 330.0, 90.0),
    (950.0, 600.0, 110.0),
    (90.0, 1150.0, 80.0),
  ]) {
    _text(
      c,
      '≈',
      Offset(x, y),
      size,
      Colors.white.withValues(alpha: 0.1),
      weight: FontWeight.w800,
      centred: true,
      width: 200,
    );
  }
}

/// Little paper bits in the palette, around the philosopher.
void _confetti(Canvas c, {required bool dense}) {
  const colours = [
    Palette.sun,
    Palette.pink,
    Palette.green,
    Palette.sky,
    Palette.terracotta,
  ];
  final rng = math.Random(7);
  final count = dense ? 34 : 18;
  for (var i = 0; i < count; i++) {
    // Keep clear of the text in the middle top and of the face.
    final left = i.isEven;
    final x = left ? 40 + rng.nextDouble() * 220 : 820 + rng.nextDouble() * 220;
    final y = 560 + rng.nextDouble() * 700;
    c.save();
    c.translate(x, y);
    c.rotate(rng.nextDouble() * math.pi);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: 14 + rng.nextDouble() * 12,
          height: 26 + rng.nextDouble() * 12,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = colours[i % colours.length],
    );
    c.restore();
  }
}

/// A four-pointed twinkle.
void _sparkle(Canvas c, Offset at, double r, Color colour) {
  final p = Path()..moveTo(at.dx, at.dy - r);
  for (var i = 1; i <= 4; i++) {
    final a = -math.pi / 2 + i * math.pi / 2;
    final mid = a - math.pi / 4;
    p.quadraticBezierTo(
      at.dx + math.cos(mid) * r * 0.18,
      at.dy + math.sin(mid) * r * 0.18,
      at.dx + math.cos(a) * r,
      at.dy + math.sin(a) * r,
    );
  }
  c.drawPath(p..close(), Paint()..color = colour);
}

/// The cream panel: label and calibration, the total, the day's squares.
void _panel(Canvas c, ShareCardData data, double w, double top) {
  const tiers = GameColors.light;
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

  _text(
    c,
    data.isRound
        ? AppStrings.shareCardRoundLabel
        : AppStrings.shareCardScoreLabel,
    Offset(120, top + 40),
    38,
    _grey,
    weight: FontWeight.w600,
  );
  final rate = data.answered >= minAnswersForCalibration
      ? calibrationRate(data.hits, data.answered)
      : null;
  if (rate != null) {
    final label = _paragraph(
      '${AppStrings.calibration} ${formatPercent(rate)}',
      38,
      _indigoText,
      FontWeight.w700,
      0,
      800,
      TextAlign.left,
    );
    c.drawParagraph(label, Offset(w - 120 - label.longestLine, top + 40));
  }

  _score(c, data.total, data.max, Offset(w / 2, top + 80));

  // The day's squares with their points.
  const square = 112.0, gap = 30.0;
  final n = data.results.length;
  final x0 = (w - n * square - (n - 1) * gap) / 2;
  final y = top + 300;
  for (final (i, r) in data.results.indexed) {
    final x = x0 + i * (square + gap);
    c.drawRRect(
      RRect.fromLTRBR(x, y, x + square, y + square, const Radius.circular(30)),
      Paint()..color = tiers.forTier(r.tier),
    );
    _text(
      c,
      '${r.points}',
      Offset(x + square / 2, y + square + 14),
      36,
      _grey,
      weight: FontWeight.w700,
      centred: true,
      width: square + gap,
    );
  }
}

/// Text whose top edge is at [at]; [centred] centres it on at.dx.
void _text(
  Canvas c,
  String text,
  Offset at,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  bool centred = false,
  double width = 1000,
}) {
  final p = _paragraph(
    text,
    size,
    color,
    weight,
    letterSpacing,
    width,
    centred ? TextAlign.center : TextAlign.left,
  );
  c.drawParagraph(p, Offset(centred ? at.dx - width / 2 : at.dx, at.dy));
}

ui.Paragraph _paragraph(
  String text,
  double size,
  Color color,
  FontWeight weight,
  double letterSpacing,
  double width,
  TextAlign align,
) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: align))
    ..pushStyle(
      ui.TextStyle(
        fontFamily: 'Roboto',
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      ),
    )
    ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

/// "380 / 500": the total large, the maximum small, on one baseline.
void _score(Canvas c, int total, int max, Offset topCentre) {
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(
          ui.TextStyle(
            fontFamily: 'Roboto',
            color: _indigoText,
            fontSize: 190,
            fontWeight: FontWeight.w800,
            letterSpacing: -6,
          ),
        )
        ..addText('$total')
        ..pop()
        ..pushStyle(
          ui.TextStyle(
            fontFamily: 'Roboto',
            color: _grey,
            fontSize: 64,
            fontWeight: FontWeight.w600,
          ),
        )
        ..addText(' / $max');
  const width = 1000.0;
  final p = builder.build()
    ..layout(const ui.ParagraphConstraints(width: width));
  c.drawParagraph(p, Offset(topCentre.dx - width / 2, topCentre.dy));
}

/// [label] in a rounded pill centred on [centre].
void _pill(
  Canvas c,
  String label,
  Offset centre, {
  required Color fill,
  required Color text,
  double size = 42,
  double padX = 40,
  double padY = 14,
}) {
  final p = _paragraph(
    label,
    size,
    text,
    FontWeight.w800,
    0,
    900,
    TextAlign.left,
  );
  final textWidth = p.longestLine;
  final rect = Rect.fromCenter(
    center: centre,
    width: textWidth + padX * 2,
    height: p.height + padY * 2,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    Paint()..color = fill,
  );
  c.drawParagraph(
    p,
    Offset(centre.dx - textWidth / 2, centre.dy - p.height / 2),
  );
}
