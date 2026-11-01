import 'package:aralik/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app bars ask for status bar icons that contrast with the theme', () {
    // Transparent app bars cannot infer it; without this the icons turn
    // white on the light background.
    expect(
      AppTheme.light.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      AppTheme.dark.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
  });

  test('text on the home cards is readable (WCAG AA)', () {
    double contrast(Color a, Color b) {
      final (hi, lo) = a.computeLuminance() > b.computeLuminance()
          ? (a, b)
          : (b, a);
      return (hi.computeLuminance() + .05) / (lo.computeLuminance() + .05);
    }

    for (final background in [
      Palette.heroTop,
      Palette.heroBottom,
      Palette.roundStart,
      Palette.roundEnd,
    ]) {
      expect(contrast(Colors.white, background), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(Palette.onSun, Palette.sun), greaterThanOrEqualTo(4.5));
  });

  test('SystemUiOverlayStyle.dark means dark icons', () {
    expect(SystemUiOverlayStyle.dark.statusBarIconBrightness, Brightness.dark);
  });
}
