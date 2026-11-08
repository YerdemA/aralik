import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/widgets/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final a = GlobalKey();
  final b = GlobalKey();
  final gone = GlobalKey(); // never on screen

  Future<Future<CoachOutcome>> start(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            ctx = context;
            return Scaffold(
              body: Column(
                children: [
                  SizedBox(key: a, height: 80, child: const Text('A')),
                  const Spacer(),
                  SizedBox(key: b, height: 80, child: const Text('B')),
                ],
              ),
            );
          },
        ),
      ),
    );
    final done = showCoachTour(ctx, [
      const CoachStep(title: 'Merhaba', body: 'Hoş geldin'),
      CoachStep(target: a, title: 'Bir', body: 'A burada'),
      CoachStep(target: gone, title: 'Yok', body: 'Görünmez'),
      CoachStep(target: b, title: 'İki', body: 'B burada'),
    ]);
    await tester.pumpAndSettle();
    return done;
  }

  testWidgets('steps one by one; a widget not on screen is left out', (
    tester,
  ) async {
    final done = await start(tester);
    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text(AppStrings.tourCounter(1, 3)), findsOneWidget);
    await tester.tap(find.text(AppStrings.tourNext));
    await tester.pumpAndSettle();
    expect(find.text('Bir'), findsOneWidget);
    await tester.tap(find.text(AppStrings.tourNext));
    await tester.pumpAndSettle();
    expect(find.text('Yok'), findsNothing);
    expect(find.text('İki'), findsOneWidget);
    expect(find.text(AppStrings.tourCounter(3, 3)), findsOneWidget);
    await tester.tap(find.text(AppStrings.tourDone));
    await tester.pumpAndSettle();
    expect(await done, CoachOutcome.finished);
    expect(find.text('İki'), findsNothing);
  });

  testWidgets('"Tanıtımdan çık" ends it at once', (tester) async {
    final done = await start(tester);
    await tester.tap(find.text(AppStrings.tourSkip));
    await tester.pumpAndSettle();
    expect(await done, CoachOutcome.skipped);
    expect(find.text('Merhaba'), findsNothing);
  });
}
