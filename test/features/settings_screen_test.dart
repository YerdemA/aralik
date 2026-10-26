import 'dart:io';

import 'package:aralik/core/strings.dart';
import 'package:aralik/core/theme.dart';
import 'package:aralik/data/attributions.dart';
import 'package:aralik/features/settings/attributions_screen.dart';
import 'package:aralik/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('settings lists data sources, licenses and privacy', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SettingsScreen()));
    expect(find.text(AppStrings.dataSources), findsOneWidget);
    expect(find.text(AppStrings.openSourceLicenses), findsOneWidget);
    expect(find.text(AppStrings.privacyPolicyUrl), findsOneWidget);
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
