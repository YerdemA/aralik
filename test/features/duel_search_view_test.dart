import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/features/duel/duel_search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the search says which duel it is looking for', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Future<void> show({required bool math}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DuelSearchView(name: 'Ayşe', firstTip: 0, math: math),
          ),
        ),
      );
      await tester.pump();
    }

    await show(math: true);
    expect(find.text(AppStrings.mathDuelTitle), findsOneWidget);
    await show(math: false);
    expect(find.text(AppStrings.duelModeBank), findsOneWidget);
    expect(find.text(AppStrings.mathDuelTitle), findsNothing);
  });
}
