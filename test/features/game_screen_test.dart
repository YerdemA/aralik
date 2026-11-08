import 'package:aralik/core/question_timer.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/data/sound.dart';
import 'package:aralik/features/game/game_controller.dart';
import 'package:aralik/features/game/game_screen.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _question = Question(
  id: 'q1',
  text: 'Ağrı Dağı kaç metre yüksekliktedir?',
  answer: 5137,
  unit: 'm',
  kind: QuestionKind.magnitude,
  category: QuestionCategory.geography,
  source: 'https://www.wikidata.org/wiki/Q72303',
  dataYear: 2026,
);

void main() {
  testWidgets('guess, lock, see the result, finish', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final locked = <RoundAnswer>[];
    final played = Sounds.played = [];
    addTearDown(() => Sounds.played = null);
    List<RoundAnswer>? popped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        questions: const [_question],
                        onLocked: locked.add,
                      ),
                    ),
                  );
                },
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.questionProgress(1, 1)), findsOneWidget);
    expect(find.text(AppStrings.typeYourGuess), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.tap(find.text('000'));
    await tester.pump();
    expect(find.text('5.000 m'), findsOneWidget);

    await tester.tap(find.text(AppStrings.next));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.intervalLabel), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text(AppStrings.lock));
    await tester.pumpAndSettle();
    expect(locked, hasLength(1));
    expect(find.text(AppStrings.hit), findsOneWidget);
    expect(find.text('5.137 m'), findsOneWidget);
    expect(played, [Sfx.lock, Sfx.of(locked.single.tier)]);

    await tester.tap(find.text(AppStrings.finish));
    await tester.pumpAndSettle();
    expect(popped, hasLength(1));
    expect(popped!.single.hit, isTrue);
  });

  group('daily countdown', () {
    late DateTime clock;
    late List<RoundAnswer> locked;
    final start = DateTime(2026, 11, 4, 9);

    Future<void> open(WidgetTester tester, {DateTime? startedAt}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      clock = start;
      locked = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GameScreen(
            questions: const [_question],
            onLocked: locked.add,
            startQuestion: (_) => startedAt ?? start,
            now: () => clock,
          ),
        ),
      );
      await tester.pump(); // post-frame start of the clock
    }

    testWidgets('shows the seconds left', (tester) async {
      await open(tester);
      expect(
        find.text(AppStrings.secondsLeft(dailyTimeLimit.inSeconds)),
        findsOneWidget,
      );
      clock = start.add(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.text(AppStrings.secondsLeft(dailyTimeLimit.inSeconds - 6)),
        findsOneWidget,
      );
    });

    testWidgets('ticks each of the last five seconds', (tester) async {
      final played = Sounds.played = [];
      addTearDown(() => Sounds.played = null);
      await open(tester);
      for (var s = 9; s <= 14; s++) {
        clock = start.add(Duration(seconds: s, milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(played, List.filled(5, Sfx.tick));
    });

    testWidgets('time up without a guess shows "Süre doldu"', (tester) async {
      await open(tester);
      clock = start.add(dailyTimeLimit);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(locked, hasLength(1));
      expect(locked.single.timedOut, isTrue);
      expect(locked.single.hasInterval, isFalse);
      expect(find.text(AppStrings.timeUp), findsOneWidget);
      expect(find.text(AppStrings.noGuess), findsOneWidget);
    });

    testWidgets('time up locks the interval being set', (tester) async {
      await open(tester);
      await tester.tap(find.text('5'));
      await tester.tap(find.text('000'));
      await tester.tap(find.text(AppStrings.next));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      clock = start.add(dailyTimeLimit);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(locked.single.hit, isTrue);
      expect(find.text(AppStrings.hit), findsOneWidget);
      expect(find.text(AppStrings.autoLocked), findsOneWidget);
    });

    testWidgets('a resumed question that ran out times out at once', (
      tester,
    ) async {
      await open(
        tester,
        startedAt: start.subtract(const Duration(minutes: 10)),
      );
      await tester.pumpAndSettle();
      expect(locked.single.timedOut, isTrue);
      expect(find.text(AppStrings.timeUp), findsOneWidget);
    });
  });

  testWidgets('free play has no countdown', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GameScreen(questions: [_question]),
      ),
    );
    await tester.pump();
    expect(
      find.text(AppStrings.secondsLeft(dailyTimeLimit.inSeconds)),
      findsNothing,
    );
  });

  testWidgets('the first question is shown around before its clock starts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.open();
    var clock = DateTime(2026, 11, 8, 12);
    var started = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GameScreen(
          questions: const [_question],
          settings: settings,
          startQuestion: (_) {
            started++;
            return clock;
          },
          now: () => clock,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(AppStrings.tourQuestion), findsOneWidget);
    // The clock waits, showing its full time.
    expect(started, 0);
    expect(
      find.text(AppStrings.secondsLeft(dailyTimeLimit.inSeconds)),
      findsOneWidget,
    );
    for (final _ in [1, 2]) {
      await tester.tap(find.text(AppStrings.tourNext));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text(AppStrings.tourPad), findsOneWidget);
    await tester.tap(find.text(AppStrings.tourDone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(started, 1);
    expect(settings.tourSeen(TourPart.guess), isTrue);

    // The first interval: the slider and the lock, the clock paused.
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text(AppStrings.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(AppStrings.tourRange), findsOneWidget);
    clock = clock.add(const Duration(seconds: 30)); // reading takes a while
    await tester.tap(find.text(AppStrings.tourNext));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(AppStrings.tourDone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Not timed out: the 30 s of reading were given back.
    expect(find.text(AppStrings.lock), findsOneWidget);
    expect(settings.tourSeen(TourPart.range), isTrue);
  });
}
