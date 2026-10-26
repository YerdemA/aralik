import 'dart:io';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/attributions.dart';
import 'package:aralik/data/settings_store.dart';
import 'package:aralik/features/settings/attributions_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sources = [
  Attribution(
    name: 'Wikidata',
    attribution: 'Wikidata, Wikimedia Vakfı.',
    license: 'CC0 1.0',
    licenseUrl: 'https://www.wikidata.org/wiki/Wikidata:Licensing',
    url: 'https://www.wikidata.org/',
  ),
];

Widget app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Future<SettingsStore> settingsStore([Map<String, Object> prefs = const {}]) {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsStore.open();
}

void main() {
  testWidgets('settings lists data sources, licenses and privacy', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(SettingsScreen(settings: await settingsStore())),
    );
    expect(find.text(AppStrings.dataSources), findsOneWidget);
    expect(find.text(AppStrings.openSourceLicenses), findsOneWidget);
    expect(find.text(AppStrings.privacyPolicyUrl), findsOneWidget);
  });

  testWidgets('choosing a theme updates and keeps it', (tester) async {
    final settings = await settingsStore();
    expect(settings.themeMode, ThemeMode.system);
    await tester.pumpWidget(app(SettingsScreen(settings: settings)));

    await tester.tap(find.text(AppStrings.themeDark));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect((await SettingsStore.open()).themeMode, ThemeMode.dark);

    await tester.tap(find.text(AppStrings.themeLight));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.light);
  });

  test('an unknown stored theme falls back to the system', () async {
    final settings = await settingsStore({'theme_mode': 'sepia'});
    expect(settings.themeMode, ThemeMode.system);
  });

  testWidgets('the app follows the chosen theme', (tester) async {
    final settings = await settingsStore({'theme_mode': 'dark'});
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: const Scaffold(),
        ),
      ),
    );
    BuildContext ctx() => tester.element(find.byType(Scaffold));
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    await settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);
  });

  testWidgets('the sources screen shows each credit and license', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(AttributionsScreen(load: () async => _sources)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wikidata'), findsOneWidget);
    expect(find.text('Wikidata, Wikimedia Vakfı.'), findsOneWidget);
    expect(find.text('${AppStrings.license}: CC0 1.0'), findsOneWidget);
    expect(find.text('https://www.wikidata.org/'), findsOneWidget);
  });

  test('the bundled attributions parse and name Wikidata', () {
    final sources = parseAttributions(
      File(attributionsAssetPath).readAsStringSync(),
    );
    expect(sources.map((s) => s.name), contains('Wikidata'));
    for (final s in sources) {
      expect(s.url, startsWith('https://'));
      expect(s.licenseUrl, startsWith('https://'));
    }
  });

  test('parseAttributions rejects incomplete entries', () {
    expect(() => parseAttributions('{}'), throwsFormatException);
    expect(
      () => parseAttributions('[{"name": "X", "attribution": "Y"}]'),
      throwsFormatException,
    );
  });
}
