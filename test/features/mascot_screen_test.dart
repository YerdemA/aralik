import 'package:aralik/core/mascot_look.dart';
import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/features/settings/mascot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsStore> _settings([Map<String, Object> prefs = const {}]) {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsStore.open();
}

final _now = DateTime(2026, 11, 10, 12);

Widget _app(SettingsStore settings) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MascotScreen(settings: settings, now: () => _now),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, SettingsStore settings) async {
  // Tall enough for every row of options (the list builds lazily).
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(settings));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String label) async {
  final option = find.bySemanticsLabel(label);
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first mascot is saved at once, without a wait', (
    tester,
  ) async {
    final settings = await _settings();
    await _open(tester, settings);
    await _pick(tester, '${AppStrings.mascotHat}: Fes');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(settings.mascot.hat, MascotHat.fez);
    expect(settings.nextMascotChange(_now), isNull);
    expect(find.text(AppStrings.mascotSaved), findsOneWidget);
  });

  testWidgets('a woman hides the beard and moustache rows', (tester) async {
    final settings = await _settings();
    await _open(tester, settings);
    expect(find.text(AppStrings.mascotBeard), findsOneWidget);
    await _pick(tester, '${AppStrings.mascotGender}: Kadın');
    expect(find.text(AppStrings.mascotBeard), findsNothing);
    expect(find.text(AppStrings.mascotMoustache), findsNothing);
  });

  testWidgets('a change asks, then waits three days', (tester) async {
    final settings = await _settings({'mascot_look': '011100000'});
    await _open(tester, settings);
    await _pick(tester, '${AppStrings.mascotGlasses}: Kalın');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.mascotConfirmTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.save).last);
    await tester.pumpAndSettle();
    expect(settings.mascot.glasses, MascotGlasses.square);
    expect(settings.nextMascotChange(_now), DateTime(2026, 11, 13, 12));

    // Back in: locked till then.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.mascotLocked(DateTime(2026, 11, 13, 12))),
      findsOneWidget,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.save),
    );
    expect(save.onPressed, isNull);
  });
}
