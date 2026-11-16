// Draws the four reaction faces' motion frame by frame to
// build/mascot/motion/ for a visual check; ffmpeg makes a GIF of them:
//   flutter test tools/mascot/render_reaction_motion_test.dart
//   ffmpeg -framerate 30 -i build/mascot/motion/%03d.png build/mascot/motion.gif
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/reaction.dart';
import 'package:aralik/widgets/reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render reaction motion', (tester) async {
    tester.view.physicalSize = const Size(780, 240);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final out = Directory('build/mascot/motion')..createSync(recursive: true);
    for (final f in out.listSync()) {
      f.deleteSync();
    }
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFFFFF9F1),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final r in Reaction.values.where((r) => r.isFace))
                    ReactionMotion(
                      reaction: r,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF2F6BFF),
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: ReactionFace(
                            look: MascotLook.philosopher,
                            reaction: r,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 66; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${i.toString().padLeft(3, '0')}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.pumpAndSettle();
  });
}
