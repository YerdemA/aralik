/// Math mode, further on: trigonometry, limits, derivatives, integrals,
/// logarithms, growth and decay, sequences, statistics, matrices, complex
/// numbers, vectors and number theory. Same rules as the basic topics
/// (math_problem.dart): the answer is computed from what the text says,
/// it is positive (at least 1, since the number pad has no decimal point
/// and the slider is logarithmic) and below a trillion; percentages stay
/// within 1–99. Angles are in degrees.
///
/// For the duel server later: these use sin, cos, exp and log, whose last
/// bit may differ between Dart and JavaScript; answers are rounded to one
/// decimal, which hides that in practice.
library;

import 'dart:math' as math;

import '../number_format.dart';
import '../strings.dart';
import 'math_problem.dart';
import 'seeded_random.dart';

String _n(num v, [int decimals = 0]) => formatNumber(v, maxDecimals: decimals);

double _rad(num degrees) => degrees * math.pi / 180;
double _deg(num radians) => radians * 180 / math.pi;

/// "−3" with a real minus sign.
String _signed(int v) => v < 0 ? '−${-v}' : '$v';

// ---------------------------------------------------------------------------
// Pure helpers (tested on their own).

int gcd(int a, int b) {
  var (x, y) = (a.abs(), b.abs());
  while (y != 0) {
    (x, y) = (y, x % y);
  }
  return x;
}

int lcm(int a, int b) => a ~/ gcd(a, b) * b;

/// How many positive divisors [n] has.
int divisorCount(int n) {
  var count = 1;
  var m = n;
  for (var p = 2; p * p <= m; p++) {
    var e = 0;
    while (m % p == 0) {
      m ~/= p;
      e++;
    }
    count *= e + 1;
  }
  return m > 1 ? count * 2 : count;
}

/// Euler's φ: how many of 1…[n] share no factor with [n].
int totient(int n) {
  var result = n;
  var m = n;
  for (var p = 2; p * p <= m; p++) {
    if (m % p != 0) continue;
    while (m % p == 0) {
      m ~/= p;
    }
    result -= result ~/ p;
  }
  if (m > 1) result -= result ~/ m;
  return result;
}

/// Determinant of a square matrix of ints (2×2 or 3×3).
int determinant(List<List<int>> a) {
  if (a.length == 2) return a[0][0] * a[1][1] - a[0][1] * a[1][0];
  return a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
      a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
      a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]);
}

/// The standard normal distribution: P(Z ≤ [z]). Abramowitz & Stegun
/// 7.1.26 for erf (error below 1,5·10⁻⁷).
double normalCdf(double z) {
  final x = z.abs() / math.sqrt2;
  final t = 1 / (1 + 0.3275911 * x);
  final poly =
      t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  final erf = 1 - poly * math.exp(-x * x);
  return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

String _matrix(List<List<int>> a) =>
    '[${a.map((row) => row.map(_signed).join('  ')).join(' ; ')}]';

String _vector(List<int> v) => '(${v.map(_signed).join(', ')})';

// ---------------------------------------------------------------------------
// Generators.

MathMade mathTrigonometry(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final length = r.between(3, 12);
      final angle = r.stepped(15, 75, 5);
      final answer = (length * math.sin(_rad(angle)) * 100).round();
      return (
        AppStrings.mathLadder(length, angle),
        answer,
        'cm',
        '$length m × sin $angle° ≈ ${_n(answer)} cm',
      );
    case 2:
      final shadow = r.between(5, 40);
      final angle = r.stepped(20, 70, 5);
      final answer = roundTo(shadow * math.tan(_rad(angle)), 1);
      return (
        AppStrings.mathShadow(shadow, angle),
        answer,
        'm',
        '$shadow m × tan $angle° ≈ ${_n(answer, 1)} m',
      );
    default:
      if (r.nextBool()) {
        final a = r.between(5, 40);
        final b = r.between(5, 40);
        final angle = r.stepped(20, 160, 5);
        final answer = roundTo(
          math.sqrt(a * a + b * b - 2 * a * b * math.cos(_rad(angle))),
          1,
        );
        return (
          AppStrings.mathLawOfCosines(a, b, angle),
          answer,
          'cm',
          '√($a² + $b² − 2 × $a × $b × cos $angle°) ≈ ${_n(answer, 1)}',
        );
      }
      final speed = r.between(10, 40);
      final angle = r.stepped(15, 75, 5);
      final answer = roundTo(
        speed * speed * math.sin(_rad(2 * angle)) / 9.81,
        1,
      );
      return (
        AppStrings.mathProjectile(speed, angle),
        answer,
        'm',
        '$speed² × sin ${2 * angle}° ÷ 9,81 ≈ ${_n(answer, 1)} m',
      );
  }
}

MathMade mathLimit(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final a = r.between(6, 50);
      return (
        AppStrings.mathLimitAt(a, 'x² − ${_n(a * a)}', 'x − $a'),
        2 * a,
        '',
        '(x − $a)(x + $a) ÷ (x − $a) = x + $a → ${2 * a}',
      );
    case 2:
      final n = r.between(3, 5);
      final a = r.between(2, switch (n) {
        3 => 9,
        4 => 6,
        _ => 4,
      });
      final an = math.pow(a, n).toInt();
      final answer = n * math.pow(a, n - 1).toInt();
      return (
        AppStrings.mathLimitAt(a, 'x${superscript(n)} − ${_n(an)}', 'x − $a'),
        answer,
        '',
        '$n × $a${superscript(n - 1)} = ${_n(answer)} '
            '(${AppStrings.mathByDefinition})',
      );
    default:
      if (r.nextBool()) {
        final k = r.between(3, 9);
        final answer = roundTo(math.exp(k), 1);
        return (
          AppStrings.mathLimitE(k),
          answer,
          '',
          'e${superscript(k)} ≈ ${_n(answer, 1)}',
        );
      }
      final k = r.between(4, 20);
      final answer = roundTo(k * k / 2, 1);
      return (
        AppStrings.mathLimitCos(k),
        answer,
        '',
        '1 − cos ${k}x ≈ (${k}x)² ÷ 2 → $k² ÷ 2 = ${_n(answer, 1)}',
      );
  }
}

MathMade mathDerivative(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final a = r.between(2, 9);
      final n = r.between(2, 4);
      final c = r.between(2, 6);
      final answer = a * n * math.pow(c, n - 1).toInt();
      return (
        AppStrings.mathDerivativeAt('${a}x${superscript(n)}', c),
        answer,
        '',
        "f′(x) = ${a * n}x${n - 1 == 1 ? '' : superscript(n - 1)} → "
            '${_n(answer)}',
      );
    case 2:
      final a = r.between(1, 5);
      final b = r.between(1, 9);
      final c = r.between(1, 20);
      final x = r.between(2, 6);
      final answer = 3 * a * x * x + 2 * b * x + c;
      final f = "${a == 1 ? '' : a}x³ + ${b == 1 ? '' : b}x² + ${c}x";
      return (
        AppStrings.mathDerivativeAt(f, x),
        answer,
        '',
        "f′(x) = ${3 * a}x² + ${2 * b}x + $c → ${_n(answer)}",
      );
    default:
      if (r.nextBool()) {
        final c = r.between(2, 6);
        final answer = roundTo(math.exp(c) * (c * c + 2 * c), 1);
        return (
          AppStrings.mathDerivativeAt('x²·eˣ', c),
          answer,
          '',
          "f′(x) = eˣ(x² + 2x) → ${_n(answer, 1)}",
        );
      }
      final c = r.between(3, 6);
      final answer = roundTo(math.pow(c, c) * (math.log(c) + 1), 1);
      return (
        AppStrings.mathDerivativeAt('xˣ', c),
        answer,
        '',
        "f′(x) = xˣ(ln x + 1) → ${_n(answer, 1)}",
      );
  }
}

MathMade mathIntegral(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final b = r.between(3, 20);
      final answer = roundTo(b * b * b / 3, 1);
      return (
        AppStrings.mathIntegral('∫${subscript(0)}${superscript(b)} (x²) dx'),
        answer,
        '',
        '[x³ ÷ 3]₀^$b = ${_n(answer, 1)}',
      );
    case 2:
      final p = r.pick(const [3, 6, 9]);
      final q = r.pick(const [2, 4, 6]);
      final b = r.between(3, 15);
      final answer = p ~/ 3 * (b * b * b - 1) + q ~/ 2 * (b * b - 1);
      return (
        AppStrings.mathIntegral(
          '∫${subscript(1)}${superscript(b)} (${p}x² + ${q}x) dx',
        ),
        answer,
        '',
        '[${p ~/ 3 == 1 ? '' : p ~/ 3}x³ + ${q ~/ 2 == 1 ? '' : q ~/ 2}x²]₁^$b '
            '= ${_n(answer)}',
      );
    default:
      if (r.nextBool()) {
        final b = r.between(3, 12);
        final answer = roundTo(math.exp(b) - 1, 1);
        return (
          AppStrings.mathIntegral('∫${subscript(0)}${superscript(b)} (eˣ) dx'),
          answer,
          '',
          'e${superscript(b)} − 1 ≈ ${_n(answer, 1)}',
        );
      }
      final b = r.between(2, 9);
      final answer = roundTo((b - 1) * math.exp(b) + 1, 1);
      return (
        AppStrings.mathIntegral('∫${subscript(0)}${superscript(b)} (x·eˣ) dx'),
        answer,
        '',
        '[(x − 1)eˣ]₀^$b = ${b - 1}e${superscript(b)} + 1 ≈ '
            '${_n(answer, 1)}',
      );
  }
}

MathMade mathLogarithm(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final n = r.between(1000, 1000000);
      final answer = roundTo(math.log(n) / math.ln2, 1);
      return (
        AppStrings.mathLog('log₂', _n(n)),
        answer,
        '',
        '2^${_n(answer, 1)} ≈ ${_n(n)}',
      );
    case 2:
      final base = r.pick(const [3, 5, 7]);
      final n = r.between(10000, 100000000);
      final answer = roundTo(math.log(n) / math.log(base), 1);
      return (
        AppStrings.mathSolvePower(base, _n(n)),
        answer,
        '',
        'x = ln ${_n(n)} ÷ ln $base ≈ ${_n(answer, 1)}',
      );
    default:
      if (r.nextBool()) {
        final e = r.between(5, 15);
        final answer = roundTo(e * math.log(10) / math.ln2, 1);
        return (
          AppStrings.mathSolveTwoToTen(e),
          answer,
          '',
          'x = $e × log₂ 10 ≈ ${_n(answer, 1)}',
        );
      }
      final small = r.stepped(40, 60, 5) / 10;
      final step = r.stepped(10, 30, 5) / 10;
      final answer = roundTo(math.pow(10, 1.5 * step).toDouble(), 1);
      return (
        AppStrings.mathQuakeEnergy(_n(small, 1), _n(small + step, 1)),
        answer,
        AppStrings.mathTimes,
        '10^(1,5 × ${_n(step, 1)}) ≈ ${_n(answer, 1)}',
      );
  }
}

MathMade mathExponential(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final every = r.pick(const [15, 20, 30]);
      final hours = r.between(2, 6);
      final doublings = hours * 60 ~/ every;
      final answer = math.pow(2, doublings).toInt();
      return (
        AppStrings.mathBacteria(every, hours),
        answer,
        '',
        '2${superscript(doublings)} = ${_n(answer)}',
      );
    case 2:
      final grams = r.stepped(100, 1000, 100);
      final half = r.pick(const [5, 10, 20, 30]);
      final years = r.stepped(half, half * 6, 5);
      final answer = roundTo(
        grams * 1000 * math.pow(0.5, years / half).toDouble(),
        1,
      );
      return (
        AppStrings.mathHalfLife(grams, half, years),
        answer,
        'mg',
        '${_n(grams * 1000)} mg × (1/2)^(${_n(years)} ÷ $half) ≈ '
            '${_n(answer, 1)}',
      );
    default:
      final times = r.pick(const [3, 5, 10]);
      final rate = r.between(2, 9);
      final answer = roundTo(math.log(times) / math.log(1 + rate / 100), 1);
      return (
        AppStrings.mathGrowthTimes(rate, times),
        answer,
        AppStrings.mathYears,
        'ln $times ÷ ln ${_n(1 + rate / 100, 2)} ≈ ${_n(answer, 1)}',
      );
  }
}

MathMade mathSequence(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final first = r.between(3, 50);
      final d = r.between(2, 15);
      final n = r.between(20, 100);
      final answer = n * (2 * first + (n - 1) * d) ~/ 2;
      final terms = [first, first + d, first + 2 * d].join(' + ');
      return (
        AppStrings.mathArithmeticSum(terms, n),
        answer,
        '',
        '$n × (2 × $first + ${n - 1} × $d) ÷ 2 = ${_n(answer)}',
      );
    case 2:
      if (r.nextBool()) {
        final n = r.between(10, 50);
        final answer = math.pow(n * (n + 1) ~/ 2, 2).toInt();
        return (
          AppStrings.mathSumCubes(n),
          answer,
          '',
          '($n × ${n + 1} ÷ 2)² = ${_n(answer)}',
        );
      }
      final a = r.between(1, 9);
      final ratio = r.between(2, 3);
      final n = r.between(8, ratio == 2 ? 30 : 18);
      final answer = a * (math.pow(ratio, n).toInt() - 1) ~/ (ratio - 1);
      final terms = [a, a * ratio, a * ratio * ratio].map(_n).join(' + ');
      return (
        AppStrings.mathGeometricSum(terms, n),
        answer,
        '',
        '$a × ($ratio${superscript(n)} − 1) ÷ ${ratio - 1} = ${_n(answer)}',
      );
    default:
      final (p, q) = r.pick(const [(1, 2), (2, 3), (3, 4), (4, 5), (9, 10)]);
      final a = q * q * r.between(1, 9) * (q <= 3 ? 10 : 1);
      final answer = a * q / (q - p);
      final terms = [a, a * p ~/ q, a * p * p ~/ (q * q)].map(_n).join(' + ');
      return (
        AppStrings.mathInfiniteSum(terms),
        roundTo(answer, 1),
        '',
        '${_n(a)} ÷ (1 − $p/$q) = ${_n(answer, 1)}',
      );
  }
}

MathMade mathStatistics(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final xs = [for (var i = 0; i < 6; i++) r.between(10, 99)];
      final mean = roundTo(xs.reduce((a, b) => a + b) / xs.length, 1);
      return (
        AppStrings.mathMean(xs.join(', ')),
        mean,
        '',
        '${xs.join(' + ')} = ${xs.reduce((a, b) => a + b)} → ÷ 6 = '
            '${_n(mean, 1)}',
      );
    case 2:
      List<int> xs;
      double sd;
      do {
        xs = [for (var i = 0; i < 5; i++) r.between(10, 99)];
        final mean = xs.reduce((a, b) => a + b) / xs.length;
        final variance =
            xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            xs.length;
        sd = math.sqrt(variance);
      } while (sd < 1);
      final answer = roundTo(sd, 1);
      return (
        AppStrings.mathStdDev(xs.join(', ')),
        answer,
        '',
        '√(Σ(x − ort)² ÷ 5) ≈ ${_n(answer, 1)}',
      );
    default:
      final mean = r.stepped(150, 190, 5);
      final sd = r.between(5, 12);
      // z between −2 and 2 in tenths, the cut-off a whole centimetre.
      int cut;
      double z;
      do {
        cut = mean + r.between(-2 * sd, 2 * sd);
        z = (cut - mean) / sd;
      } while (z.abs() < 0.1);
      final answer = roundTo(normalCdf(z) * 100, 1);
      return (
        AppStrings.mathNormalBelow(mean, sd, cut),
        answer,
        '%',
        'z = ($cut − $mean) ÷ $sd ≈ ${_n(z, 2)} → Φ(z) ≈ %${_n(answer, 1)}',
      );
  }
}

MathMade mathMatrix(SeededRandom r, int level) {
  final (size, low, high) = switch (level) {
    1 => (2, 1, 20),
    2 => (3, 0, 9),
    _ => (3, -9, 9),
  };
  List<List<int>> a;
  int det;
  do {
    a = [
      for (var i = 0; i < size; i++)
        [for (var j = 0; j < size; j++) r.between(low, high)],
    ];
    det = determinant(a);
  } while (det < 1);
  return (
    AppStrings.mathDeterminant(_matrix(a)),
    det,
    '',
    size == 2
        ? '${a[0][0]} × ${a[1][1]} − ${a[0][1]} × ${a[1][0]} = ${_n(det)}'
        : '${AppStrings.mathSarrus}: ${_n(det)}',
  );
}

MathMade mathComplex(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final a = r.between(1, 30);
      final b = r.between(1, 30);
      final answer = roundTo(math.sqrt(a * a + b * b), 1);
      return (
        AppStrings.mathModulus('$a + ${b}i'),
        answer,
        '',
        '√($a² + $b²) ≈ ${_n(answer, 1)}',
      );
    case 2:
      final a = r.between(1, 5);
      final b = r.between(1, 5);
      final n = r.between(3, 6);
      final answer = roundTo(math.pow(a * a + b * b, n / 2).toDouble(), 1);
      return (
        AppStrings.mathModulus('($a + ${b}i)${superscript(n)}'),
        answer,
        '',
        '|z|${superscript(n)} = (√${a * a + b * b})${superscript(n)} ≈ '
            '${_n(answer, 1)}',
      );
    default:
      int a, b, n;
      double angle;
      do {
        a = r.between(1, 9);
        b = r.between(1, 9);
        n = r.between(2, 6);
        angle = (_deg(math.atan2(b, a)) * n) % 360;
      } while (angle < 1);
      final answer = roundTo(angle, 1);
      return (
        AppStrings.mathArgument('($a + ${b}i)${superscript(n)}'),
        answer,
        '°',
        '$n × arctan($b/$a) ≈ ${_n(answer, 1)}° (De Moivre)',
      );
  }
}

MathMade mathVector(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final v = [for (var i = 0; i < 3; i++) r.between(1, 20)];
      final answer = roundTo(
        math.sqrt(v.map((x) => x * x).reduce((a, b) => a + b)),
        1,
      );
      return (
        AppStrings.mathVectorLength(_vector(v)),
        answer,
        '',
        '√(${v.map((x) => '$x²').join(' + ')}) ≈ ${_n(answer, 1)}',
      );
    case 2:
      List<int> u, v;
      double angle;
      do {
        u = [r.between(-9, 9), r.between(-9, 9)];
        v = [r.between(-9, 9), r.between(-9, 9)];
        angle = _angle(u, v);
      } while (angle.isNaN || angle < 5);
      final answer = roundTo(angle, 1);
      return (
        AppStrings.mathVectorAngle(_vector(u), _vector(v)),
        answer,
        '°',
        'cos θ = u·v ÷ (|u||v|) → θ ≈ ${_n(answer, 1)}°',
      );
    default:
      List<int> u, v;
      double area;
      do {
        u = [for (var i = 0; i < 3; i++) r.between(-9, 9)];
        v = [for (var i = 0; i < 3; i++) r.between(-9, 9)];
        final cross = [
          u[1] * v[2] - u[2] * v[1],
          u[2] * v[0] - u[0] * v[2],
          u[0] * v[1] - u[1] * v[0],
        ];
        area = math.sqrt(cross.map((x) => x * x).reduce((a, b) => a + b)) / 2;
      } while (area < 1);
      final answer = roundTo(area, 1);
      return (
        AppStrings.mathTriangleVectors(_vector(u), _vector(v)),
        answer,
        '',
        '|u × v| ÷ 2 ≈ ${_n(answer, 1)}',
      );
  }
}

/// The angle between two vectors, in degrees (NaN for a zero vector).
double _angle(List<int> u, List<int> v) {
  var dot = 0, uu = 0, vv = 0;
  for (var i = 0; i < u.length; i++) {
    dot += u[i] * v[i];
    uu += u[i] * u[i];
    vv += v[i] * v[i];
  }
  if (uu == 0 || vv == 0) return double.nan;
  return _deg(math.acos((dot / math.sqrt(uu * vv)).clamp(-1.0, 1.0)));
}

MathMade mathNumberTheory(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final a = r.between(6, 60);
      final b = r.between(6, 60);
      final answer = lcm(a, b);
      return (
        AppStrings.mathLcm('$a ve $b'),
        answer,
        '',
        'EBOB($a, $b) = ${gcd(a, b)} → $a × $b ÷ ${gcd(a, b)} = '
            '${_n(answer)}',
      );
    case 2:
      if (r.nextBool()) {
        final xs = [for (var i = 0; i < 3; i++) r.between(4, 30)];
        final answer = lcm(lcm(xs[0], xs[1]), xs[2]);
        return (
          AppStrings.mathLcm('${xs[0]}, ${xs[1]} ve ${xs[2]}'),
          answer,
          '',
          'EKOK = ${_n(answer)}',
        );
      }
      final n = r.between(100, 10000);
      final answer = divisorCount(n);
      return (
        AppStrings.mathDivisors(_n(n)),
        answer,
        '',
        AppStrings.mathDivisorsWorking(_n(n), answer),
      );
    default:
      final n = r.between(1000, 100000);
      final answer = totient(n);
      return (
        AppStrings.mathTotient(_n(n)),
        answer,
        '',
        'φ(${_n(n)}) = ${_n(answer)} (Euler)',
      );
  }
}
