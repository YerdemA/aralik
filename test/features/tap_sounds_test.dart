import 'package:aralik/data/sound.dart';
import 'package:aralik/widgets/tap_sounds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Sfx> played;

  setUp(() => played = Sounds.played = []);
  tearDown(() => Sounds.played = null);

  Future<void> pump(WidgetTester tester, Widget home) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(splashFactory: TapSoundSplash.splashFactory),
      navigatorObservers: [PageSounds()],
      home: home,
    ),
  );

  testWidgets('an enabled button clicks, a disabled one does not', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            FilledButton(onPressed: () {}, child: const Text('on')),
            const FilledButton(onPressed: null, child: Text('off')),
            const Text('plain'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('on'));
    await tester.pump(Sounds.tapDelay * 2);
    expect(played, [Sfx.tap]);

    await tester.tap(find.text('off'), warnIfMissed: false);
    await tester.tap(find.text('plain'));
    await tester.pump(Sounds.tapDelay * 2);
    expect(played, [Sfx.tap]);
  });

  testWidgets('a tap that plays its own sound does not click too', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: FilledButton(
          onPressed: () => Sounds.play(Sfx.lock),
          child: const Text('lock'),
        ),
      ),
    );
    await tester.tap(find.text('lock'));
    await tester.pump(Sounds.tapDelay * 2);
    expect(played, [Sfx.lock]);
  });

  testWidgets('a scroll over a card stays quiet', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: ListView(
          children: [
            for (var i = 0; i < 30; i++)
              ListTile(title: Text('row $i'), onTap: () {}),
          ],
        ),
      ),
    );
    await tester.drag(find.text('row 2'), const Offset(0, -200));
    await tester.pump(Sounds.tapDelay * 2);
    expect(played, isEmpty);
  });

  testWidgets('pages whoosh in and out instead of clicking', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: BackButton()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(played, [Sfx.page]);

    // "Recently played" is wall-clock time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(played, [Sfx.page, Sfx.back]);
  });
}
