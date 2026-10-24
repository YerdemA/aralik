import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/question.dart';
import 'package:aralik/features/game/game_controller.dart';
import 'package:aralik/features/game/game_screen.dart';
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

    await tester.tap(find.text(AppStrings.finish));
    await tester.pumpAndSettle();
    expect(popped, hasLength(1));
    expect(popped!.single.hit, isTrue);
  });
}
