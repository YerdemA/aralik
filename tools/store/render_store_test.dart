// Renders the Play Store images into play-store/ (not in git): the feature
// graphic and the framed screenshots, from the raw shots in
// play-store/screenshots/ (capture_screens_test.dart draws them).
//
//   flutter test tools/store/render_store_test.dart
//
// With --dart-define=phone=iphone it frames the iPhone shots in
// app-store/screenshots/ for the App Store instead (1320 × 2868, the 6.9"
// size, into app-store/screenshots/app-store/); no feature graphic there.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/widgets/philosopher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Raw shot and headline of each store screenshot, in store order.
const _shots = [
  ('01-ana-ekran', 'Her gün 5 yeni soru,\ndüello, matematik, turnuva'),
  ('02-aralik', '%90 emin olduğun\naralığı seç'),
  ('03-sonuc', 'Aralık ne kadar darsa\no kadar çok puan'),
  ('04-duello', 'Canlı düello:\naynı soru, iki aralık'),
  ('05-rovans', 'Kazan, rövanş iste,\nsıralamada yüksel'),
  ('09-siralama', 'Aylık düello sıralaması:\nher ay sıfırdan'),
  ('10-maskot', 'Maskotunu tasarla:\nfes mi, kep mi, bere mi?'),
  ('07-matematik-soru', 'Matematik modu:\nkafadan kabaca tahmin'),
];

const _sun = Palette.sun;

const _iphone = String.fromEnvironment('phone') == 'iphone';

Directory _materialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fonts = Directory('${dir.path}/bin/cache/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    if (dir.parent.path == dir.path) {
      throw StateError('Flutter fonts not found');
    }
    dir = dir.parent;
  }
}

Future<void> _loadRoboto() async {
  final fonts = _materialFonts().path;
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black']) {
    final bytes = File('$fonts/roboto-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Lays out [text]; [letterSpacing] tightens big headlines.
TextPainter _text(
  String text,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  TextAlign align = TextAlign.left,
  double width = 2000,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      fontFamily: 'Roboto',
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: 1.12,
    ),
  ),
  textAlign: align,
  textDirection: TextDirection.ltr,
)..layout(minWidth: align == TextAlign.center ? width : 0, maxWidth: width);

/// The indigo background with faint "?" and "≈" doodles.
void _background(
  Canvas c,
  Size size,
  List<(String, double, double, double)> doodles,
) {
  c.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [Palette.heroTop, Palette.heroBottom],
      ),
  );
  for (final (glyph, x, y, s) in doodles) {
    _text(
      glyph,
      s,
      Colors.white.withValues(alpha: .08),
      weight: FontWeight.w900,
    ).paint(c, Offset(x, y));
  }
}

Future<void> _save(ui.Picture picture, Size size, String path) async {
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

void _paintFeature(Canvas c, Size size) {
  _background(c, size, const [
    ('?', 560, 30, 90),
    ('≈', 925, 50, 70),
    ('≈', 450, 400, 60),
    ('?', 950, 385, 80),
  ]);
  c.save();
  c.translate(-5, -20);
  c.scale(570);
  const Philosopher().paintScene(c);
  c.restore();

  const left = 505.0;
  _text(
    AppStrings.appName,
    132,
    Colors.white,
    weight: FontWeight.w900,
    letterSpacing: -4,
  ).paint(c, const Offset(left, 118));
  _text(
    AppStrings.tagline,
    33,
    Colors.white,
    weight: FontWeight.w500,
  ).paint(c, const Offset(left, 282));
  _text(
    'Her gün 5 soru · günlük tahmin oyunu',
    23,
    _sun,
    weight: FontWeight.w700,
  ).paint(c, const Offset(left, 335));
}

void _paintScreenshot(Canvas c, Size size, ui.Image shot, String headline) {
  // Laid out for 1080 wide; [u] scales it to the iPhone's 1320.
  final u = size.width / 1080;
  _background(c, size, [
    ('?', 40 * u, 300 * u, 120 * u),
    ('≈', 960 * u, 420 * u, 100 * u),
    ('?', 970 * u, size.height * .65, 110 * u),
    ('≈', 10 * u, size.height * .57, 90 * u),
  ]);
  final title = _text(
    headline,
    70 * u,
    Colors.white,
    weight: FontWeight.w800,
    letterSpacing: -1.5 * u,
    align: TextAlign.center,
    width: size.width - 60 * u,
  )..paint(c, Offset(30 * u, 64 * u));

  // The phone runs off the bottom, just past the shot's main buttons.
  final top = (64 + 56) * u + title.height;
  // The iPhone shot has the frame's own shape, so it needs a bigger phone to
  // run off the bottom.
  final scale = math.min(
    _iphone ? 0.9 : 0.76,
    (size.height - top + 6 * u) / (shot.height - 100 * u),
  );
  final w = shot.width * scale;
  final phone = Rect.fromLTWH(
    (size.width - w) / 2,
    top,
    w,
    shot.height * scale,
  );
  final corner = RRect.fromRectAndCorners(
    phone,
    topLeft: Radius.circular(56 * u),
    topRight: Radius.circular(56 * u),
  );
  c.drawShadow(Path()..addRRect(corner), Colors.black, 24 * u, false);
  c.save();
  c.clipRRect(corner);
  c.drawImageRect(
    shot,
    Offset.zero & Size(shot.width.toDouble(), shot.height.toDouble()),
    phone,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
  c.drawRRect(
    corner,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * u
      ..color = Colors.white.withValues(alpha: .35),
  );
}

void main() {
  testWidgets('renders the store images', (tester) async {
    await tester.runAsync(() async {
      await _loadRoboto();

      ui.PictureRecorder recorder;
      if (!_iphone) {
        const feature = Size(1024, 500);
        recorder = ui.PictureRecorder();
        _paintFeature(Canvas(recorder), feature);
        await _save(
          recorder.endRecording(),
          feature,
          'play-store/graphics/feature-graphic-1024x500.png',
        );
      }

      const screen = _iphone ? Size(1320, 2868) : Size(1080, 1920);
      const raw = _iphone ? 'app-store/screenshots' : 'play-store/screenshots';
      const framed = _iphone ? '$raw/app-store' : '$raw/play';
      Directory(framed).createSync(recursive: true);
      for (final (i, (name, headline)) in _shots.indexed) {
        final bytes = File('$raw/$name.png').readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final shot = (await codec.getNextFrame()).image;
        recorder = ui.PictureRecorder();
        _paintScreenshot(Canvas(recorder), screen, shot, headline);
        await _save(
          recorder.endRecording(),
          screen,
          '$framed/${i + 1}-$name.png',
        );
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
