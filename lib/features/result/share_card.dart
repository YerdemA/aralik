import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/daily.dart';
import '../../core/number_format.dart';
import '../../core/scoring.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/philosopher.dart';

/// What the daily share card shows.
@immutable
class ShareCardData {
  const ShareCardData({
    required this.dayIndex,
    required this.results,
    required this.hits,
    required this.answered,
  });

  final int dayIndex;
  final List<QuestionResult> results;

  /// All-time calibration counts.
  final int hits;
  final int answered;
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

const _navyTop = Color(0xFF34477D);
const _navyBottom = Color(0xFF1C2742);
const _navyText = Color(0xFF22305A);
const _grey = Color(0xFF5F6368);
const _peach = Color(0xFFFFB590);

/// Paints the card on a [shareCardSize] canvas: title, the philosopher
/// peeking over a white score card with the day's squares, and a tagline.
void paintShareCard(Canvas c, ShareCardData data) {
  const w = 1080.0, h = 1920.0;
  const tiers = GameColors.light;

  // Background with faint "?" and "≈" doodles.
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [
        _navyTop,
        _navyBottom,
      ]),
  );
  for (final (glyph, x, y, size) in const [
    ('?', 90.0, 180.0, 130.0),
    ('≈', 880.0, 120.0, 120.0),
    ('?', 940.0, 520.0, 100.0),
    ('≈', 60.0, 760.0, 110.0),
    ('?', 900.0, 1010.0, 120.0),
    ('≈', 120.0, 1840.0, 90.0),
    ('?', 960.0, 1800.0, 90.0),
  ]) {
    _text(
      c,
      glyph,
      Offset(x, y),
      size,
      Colors.white.withValues(alpha: 0.07),
      weight: FontWeight.w800,
      centred: true,
      width: 200,
    );
  }

  // Title, the range mark and the day.
  _text(
    c,
    AppStrings.appName,
    const Offset(w / 2, 130),
    160,
    Colors.white,
    weight: FontWeight.w800,
    letterSpacing: -4,
    centred: true,
  );
  _rangeMark(c, const Offset(w / 2, 345));
  final number = puzzleNumber(data.dayIndex);
  _pill(
    c,
    number > 0 ? '#$number' : AppStrings.shareCardPreview,
    const Offset(w / 2, 430),
  );

  // The mascot, its toga running behind the score card.
  c.save();
  c.translate(170, 470);
  c.scale(720);
  const Philosopher().paintScene(c, bottom: 1.3); // ends behind the card
  c.restore();

  // Score card.
  final card = RRect.fromLTRBR(
    80,
    1090,
    w - 80,
    1745,
    const Radius.circular(56),
  );
  c.drawRRect(
    card.shift(const Offset(0, 18)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
  );
  c.drawRRect(card, Paint()..color = Colors.white);

  _text(
    c,
    AppStrings.shareCardScoreLabel,
    const Offset(w / 2, 1135),
    42,
    _grey,
    weight: FontWeight.w600,
    centred: true,
  );
  final total = totalPoints(data.results);
  _score(c, total, const Offset(w / 2, 1185));

  // The day's squares with their points.
  const square = 128.0, gap = 28.0;
  final n = data.results.length;
  final x0 = (w - n * square - (n - 1) * gap) / 2;
  for (final (i, r) in data.results.indexed) {
    final x = x0 + i * (square + gap);
    c.drawRRect(
      RRect.fromLTRBR(
        x,
        1440,
        x + square,
        1440 + square,
        const Radius.circular(30),
      ),
      Paint()..color = tiers.forTier(r.tier),
    );
    _text(
      c,
      '${r.points}',
      Offset(x + square / 2, 1588),
      40,
      _grey,
      weight: FontWeight.w600,
      centred: true,
      width: square + gap,
    );
  }

  final rate = data.answered >= minAnswersForCalibration
      ? calibrationRate(data.hits, data.answered)
      : null;
  if (rate != null) {
    _text(
      c,
      '${AppStrings.calibration} ${formatPercent(rate)}',
      const Offset(w / 2, 1660),
      44,
      _navyText,
      weight: FontWeight.w700,
      centred: true,
    );
  }

  // Tagline and invitation.
  _text(
    c,
    AppStrings.tagline,
    const Offset(w / 2, 1785),
    46,
    Colors.white.withValues(alpha: 0.88),
    centred: true,
  );
  _text(
    c,
    AppStrings.shareCardInvite,
    const Offset(w / 2, 1850),
    42,
    _peach,
    weight: FontWeight.w700,
    centred: true,
  );
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
void _score(Canvas c, int total, Offset topCentre) {
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(
          ui.TextStyle(
            color: _navyText,
            fontSize: 220,
            fontWeight: FontWeight.w800,
            letterSpacing: -6,
          ),
        )
        ..addText('$total')
        ..pop()
        ..pushStyle(
          ui.TextStyle(color: _grey, fontSize: 72, fontWeight: FontWeight.w600),
        )
        ..addText(' / $maxDailyPoints');
  const width = 1000.0;
  final p = builder.build()
    ..layout(const ui.ParagraphConstraints(width: width));
  c.drawParagraph(p, Offset(topCentre.dx - width / 2, topCentre.dy));
}

/// The home screen's range mark: a track, a band, two handles.
void _rangeMark(Canvas c, Offset centre) {
  const half = 170.0, t = 16.0;
  final track = RRect.fromLTRBR(
    centre.dx - half,
    centre.dy - t / 2,
    centre.dx + half,
    centre.dy + t / 2,
    const Radius.circular(t / 2),
  );
  c.drawRRect(track, Paint()..color = Colors.white.withValues(alpha: 0.22));
  c.drawRRect(
    RRect.fromLTRBR(
      centre.dx - 95,
      centre.dy - t / 2,
      centre.dx + 95,
      centre.dy + t / 2,
      const Radius.circular(t / 2),
    ),
    Paint()..color = Palette.terracotta,
  );
  for (final x in [centre.dx - 95, centre.dx + 95]) {
    c.drawCircle(Offset(x, centre.dy), 24, Paint()..color = Colors.white);
    c.drawCircle(Offset(x, centre.dy), 10, Paint()..color = _navyText);
  }
}

/// "#42" in a terracotta pill centred on [centre].
void _pill(Canvas c, String text, Offset centre) {
  final p = _paragraph(
    text,
    46,
    Colors.white,
    FontWeight.w800,
    0,
    600,
    TextAlign.left,
  );
  final textWidth = p.longestLine;
  final rect = Rect.fromCenter(
    center: centre,
    width: textWidth + 72,
    height: p.height + 20,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    Paint()..color = Palette.terracotta,
  );
  c.drawParagraph(
    p,
    Offset(centre.dx - textWidth / 2, centre.dy - p.height / 2),
  );
}
