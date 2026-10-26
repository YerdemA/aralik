import 'package:aralik/core/strings.dart';
import 'package:aralik/features/intro/intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _next = Scaffold(body: Text('ana ekran'));

void main() {
  testWidgets('plays once, then fades to the next screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IntroScreen(next: _next)));
    expect(find.text('ana ekran'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(AppStrings.appName), findsOneWidget);
    await tester.pump(IntroScreen.duration);
    await tester.pumpAndSettle();
    expect(find.text('ana ekran'), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
  });

  testWidgets('a tap skips it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IntroScreen(next: _next)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(IntroScreen));
    await tester.pumpAndSettle();
    expect(find.text('ana ekran'), findsOneWidget);
  });
}
