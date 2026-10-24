import 'dart:math' as math;

/// Turns the player's guess and the width slider into an interval.
///
/// Pure functions. The returned bounds are exactly what the player sees and
/// what is scored.

/// At the slider's right end a magnitude interval is guess÷10 … guess×10.
const double maxMagnitudeFactor = 10;

/// At the slider's right end a year interval is guess ± 50.
const int maxYearHalfWidth = 50;

/// Initial slider position for a new question.
const double defaultWidth = 0.3;

typedef Bounds = ({int low, int high});

/// Log-scale interval around [guess]: `guess÷f … guess×f` with
/// `f = maxMagnitudeFactor^t`.
///
/// Bounds are rounded outwards to a "nice" step (1, 2 or 5 × 10ⁿ), so
/// `5.000` at ×1,1 reads `4.500 – 5.500`, not `4.545 – 5.500`. Each bound's
/// step is at most a tenth of the width and a tenth of the bound itself, so
/// at full width `500 – 50.000` keeps its low end. The low bound is ≥ 1.
Bounds magnitudeInterval(int guess, double t) {
  assert(guess > 0);
  final position = t.clamp(0.0, 1.0);
  if (position == 0) return (low: guess, high: guess);

  final factor = math.pow(maxMagnitudeFactor, position).toDouble();
  final rawLow = guess / factor;
  final rawHigh = guess * factor;
  final widthStep = _niceStep(rawHigh - rawLow);
  final lowStep = math.min(widthStep, _niceStep(rawLow));
  final highStep = math.min(widthStep, _niceStep(rawHigh));
  final low = math.max(1, (rawLow / lowStep).floor() * lowStep);
  final high = (rawHigh / highStep).ceil() * highStep;
  return (low: math.min(low, guess), high: math.max(high, guess));
}

/// Linear ±years interval with a quadratic slider, so small widths get
/// fine control: half width `round(50·t²)`.
Bounds yearInterval(int guess, double t) {
  final position = t.clamp(0.0, 1.0);
  final half = (maxYearHalfWidth * position * position).round();
  return (low: guess - half, high: guess + half);
}

/// Largest 1/2/5 × 10ⁿ step not above a tenth of [size], at least 1.
int _niceStep(double size) {
  final target = size / 10;
  if (target < 2) return 1;
  final power = math.pow(10, (math.log(target) / math.ln10).floor()).toInt();
  for (final multiple in const [5, 2, 1]) {
    if (multiple * power <= target) return multiple * power;
  }
  return power;
}
