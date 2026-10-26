import 'package:aralik/core/theme.dart';
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

  test('SystemUiOverlayStyle.dark means dark icons', () {
    expect(SystemUiOverlayStyle.dark.statusBarIconBrightness, Brightness.dark);
  });
}
