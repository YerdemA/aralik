import 'dart:math' as math;

import 'package:aralik/core/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is zero for the same point', () {
    expect(greatCircleKm(39.9, 32.8, 39.9, 32.8), 0);
  });

  test('one degree of longitude on the equator', () {
    expect(
      greatCircleKm(0, 0, 0, 1),
      closeTo(earthRadiusKm * math.pi / 180, 1e-9),
    );
  });

  test('pole to pole is half a circumference', () {
    expect(
      greatCircleKm(90, 0, -90, 0),
      closeTo(earthRadiusKm * math.pi, 1e-6),
    );
  });

  test('is symmetric and wraps the antimeridian', () {
    expect(
      greatCircleKm(10, 20, -30, 40),
      closeTo(greatCircleKm(-30, 40, 10, 20), 1e-9),
    );
    expect(
      greatCircleKm(0, 179.5, 0, -179.5),
      closeTo(greatCircleKm(0, 0, 0, 1), 1e-9),
    );
  });
}
