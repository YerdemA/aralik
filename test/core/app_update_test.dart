import 'dart:io';

import 'package:aralik/core/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appBuild matches the build number in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*[\d.]+\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(version, isNotNull);
    expect(appBuild, int.parse(version!.group(1)!));
  });

  test('an update is available only for a newer build', () {
    expect(updateAvailable(null, current: 4), isFalse);
    expect(updateAvailable(3, current: 4), isFalse);
    expect(updateAvailable(4, current: 4), isFalse);
    expect(updateAvailable(5, current: 4), isTrue);
  });
}
