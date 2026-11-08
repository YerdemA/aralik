/// Math mode: estimation questions made by algorithms (pure Dart).
///
/// The answer is computed, never looked up, so the pool never runs out and
/// nothing can be made up: the text states every assumption it needs (a
/// 0,1 mm sheet of paper, a 365-day year) and the answer follows from it.
/// The same id always makes the same question ([mathProblemFromId]): a
/// seed and [SeededRandom], which also runs in JavaScript, so the duel
/// server can make them too.
///
/// Answers are positive and below a trillion (the slider's log scale and
/// the number format); percentages stay within 1–99 (the ± interval).
/// Difficulty 1 (easy) … 3 (hard) as for bank questions.
library;

import 'dart:math' as math;

import '../number_format.dart';
import '../strings.dart';
import 'advanced.dart';
import 'seeded_random.dart';

/// The kinds of math questions. [key] goes into the id; never rename one.
enum MathTopic {
  multiply('carpma'),
  power('us'),
  root('kok'),
  factorial('faktoriyel'),
  combination('kombinasyon'),
  series('toplam'),
  compound('faiz'),
  percent('yuzde'),
  units('birim'),
  geometry('geometri'),
  probability('olasilik'),
  primes('asal'),
  digits('basamak'),
  fibonacci('fibonacci'),
  folding('katlama'),

  // Further on: high school and first-year university (lib/core/math/
  // advanced.dart).
  trigonometry('trigonometri', MathTier.advanced),
  limit('limit', MathTier.advanced),
  derivative('turev', MathTier.advanced),
  integral('integral', MathTier.advanced),
  logarithm('logaritma', MathTier.advanced),
  exponential('ustel', MathTier.advanced),
  sequence('dizi', MathTier.advanced),
  statistics('istatistik', MathTier.advanced),
  matrix('matris', MathTier.advanced),
  complex('karmasik', MathTier.advanced),
  vector('vektor', MathTier.advanced),
  numberTheory('sayilar', MathTier.advanced);

  const MathTopic(this.key, [this.tier = MathTier.basic]);
  final String key;
  final MathTier tier;

  static MathTopic? byKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// Basic arithmetic and counting, or further on (trigonometry, calculus,
/// linear algebra, …).
enum MathTier { basic, advanced }

/// One generated question.
class MathProblem {
  const MathProblem({
    required this.topic,
    required this.difficulty,
    required this.seed,
    required this.text,
    required this.answer,
    required this.unit,
    required this.working,
  });

  final MathTopic topic;
  final int difficulty;
  final int seed;
  final String text;
  final num answer;

  /// `''` for a plain number, `%` for a percentage, `cm²`, `TL`, …
  final String unit;

  /// How the answer comes out, shown after locking ("47 × 86 = 4.042").
  final String working;

  /// `math:carpma:2:123456`: enough to make it again.
  String get id => mathId(topic, difficulty, seed);

  bool get isPercent => unit == '%';
}

String mathId(MathTopic topic, int difficulty, int seed) =>
    'math:${topic.key}:$difficulty:$seed';

/// The question an id names, or null for anything that is not one.
MathProblem? mathProblemFromId(String id) {
  final parts = id.split(':');
  if (parts.length != 4 || parts[0] != 'math') return null;
  final topic = MathTopic.byKey(parts[1]);
  final difficulty = int.tryParse(parts[2]);
  final seed = int.tryParse(parts[3]);
  if (topic == null || difficulty == null || seed == null) return null;
  if (difficulty < 1 || difficulty > 3 || seed < 0) return null;
  return generateMath(topic, difficulty, seed);
}

/// The question of [topic] at [difficulty] (1–3) for [seed].
MathProblem generateMath(MathTopic topic, int difficulty, int seed) {
  final r = SeededRandom(seed);
  final level = difficulty.clamp(1, 3);
  final (text, answer, unit, working) = switch (topic) {
    MathTopic.multiply => _multiply(r, level),
    MathTopic.power => _power(r, level),
    MathTopic.root => _root(r, level),
    MathTopic.factorial => _factorial(r, level),
    MathTopic.combination => _combination(r, level),
    MathTopic.series => _series(r, level),
    MathTopic.compound => _compound(r, level),
    MathTopic.percent => _percent(r, level),
    MathTopic.units => _units(r, level),
    MathTopic.geometry => _geometry(r, level),
    MathTopic.probability => _probability(r, level),
    MathTopic.primes => _primes(r, level),
    MathTopic.digits => _digits(r, level),
    MathTopic.fibonacci => _fibonacci(r, level),
    MathTopic.folding => _folding(r, level),
    MathTopic.trigonometry => mathTrigonometry(r, level),
    MathTopic.limit => mathLimit(r, level),
    MathTopic.derivative => mathDerivative(r, level),
    MathTopic.integral => mathIntegral(r, level),
    MathTopic.logarithm => mathLogarithm(r, level),
    MathTopic.exponential => mathExponential(r, level),
    MathTopic.sequence => mathSequence(r, level),
    MathTopic.statistics => mathStatistics(r, level),
    MathTopic.matrix => mathMatrix(r, level),
    MathTopic.complex => mathComplex(r, level),
    MathTopic.vector => mathVector(r, level),
    MathTopic.numberTheory => mathNumberTheory(r, level),
  };
  return MathProblem(
    topic: topic,
    difficulty: level,
    seed: seed,
    text: text,
    answer: answer,
    unit: unit,
    working: working,
  );
}

/// A round of math questions for [seed], one per entry of [levels] (easy
/// to hard by default), each from a different topic of [tiers].
List<MathProblem> mathRound(
  int seed, {
  List<int> levels = const [1, 1, 2, 2, 3],
  Set<MathTier> tiers = const {MathTier.basic, MathTier.advanced},
}) {
  final r = SeededRandom(seed);
  final topics = [
    for (final t in MathTopic.values)
      if (tiers.contains(t.tier)) t,
  ];
  // Fisher–Yates with the seeded generator: the same seed, the same round.
  for (var i = topics.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final swap = topics[i];
    topics[i] = topics[j];
    topics[j] = swap;
  }
  return [
    for (var i = 0; i < levels.length; i++)
      generateMath(topics[i % topics.length], levels[i], r.nextUint32()),
  ];
}

/// What a generator makes: the text, the answer, its unit, the working.
typedef MathMade = (String text, num answer, String unit, String working);

// ---------------------------------------------------------------------------
// Pure helpers (also tested on their own).

/// [x] rounded half up to [decimals] places.
double roundTo(double x, int decimals) {
  final f = math.pow(10, decimals);
  return (x * f).round() / f;
}

int factorial(int n) {
  var f = 1;
  for (var k = 2; k <= n; k++) {
    f *= k;
  }
  return f;
}

/// n choose k, exact for the sizes used here.
int choose(int n, int k) {
  if (k < 0 || k > n) return 0;
  final m = math.min(k, n - k);
  var c = 1;
  for (var i = 1; i <= m; i++) {
    c = c * (n - m + i) ~/ i;
  }
  return c;
}

/// The [n]th Fibonacci number, F(1) = F(2) = 1.
int fibonacci(int n) {
  var (a, b) = (0, 1);
  for (var i = 0; i < n; i++) {
    (a, b) = (b, a + b);
  }
  return a;
}

/// How many primes are ≤ [n] (sieve of Eratosthenes).
int primeCount(int n) {
  if (n < 2) return 0;
  final composite = List<bool>.filled(n + 1, false);
  var count = 0;
  for (var i = 2; i <= n; i++) {
    if (composite[i]) continue;
    count++;
    for (var j = i * i; j <= n; j += i) {
      composite[j] = true;
    }
  }
  return count;
}

/// Digits of [base]^[exponent], exactly (BigInt).
int powerDigits(int base, int exponent) =>
    BigInt.from(base).pow(exponent).toString().length;

/// Digits of [n]!, exactly.
int factorialDigits(int n) {
  var f = BigInt.one;
  for (var k = 2; k <= n; k++) {
    f *= BigInt.from(k);
  }
  return f.toString().length;
}

/// Chance (0…1) that among [people] at least two share a birthday
/// (365 equally likely days).
double sharedBirthday(int people) {
  var none = 1.0;
  for (var i = 0; i < people; i++) {
    none *= (365 - i) / 365;
  }
  return 1 - none;
}

/// "2¹⁶": [exponent] in superscript digits.
String superscript(int exponent) {
  const digits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
  return [for (final c in '$exponent'.split('')) digits[int.parse(c)]].join();
}

/// "∫₀⁵": [n] in subscript digits.
String subscript(int n) {
  const digits = '₀₁₂₃₄₅₆₇₈₉';
  return [for (final c in '$n'.split('')) digits[int.parse(c)]].join();
}

bool _isSquare(int n) {
  final s = math.sqrt(n).round();
  return s * s == n;
}

bool _isCube(int n) {
  final c = math.pow(n, 1 / 3).round();
  return c * c * c == n;
}

String _n(num v, [int decimals = 0]) => formatNumber(v, maxDecimals: decimals);

// ---------------------------------------------------------------------------
// Generators. Each returns the text, the answer, its unit and the working.

MathMade _multiply(SeededRandom r, int level) {
  final List<int> factors = switch (level) {
    1 => [r.between(12, 99), r.between(12, 99)],
    2 => [r.between(100, 999), r.between(12, 99)],
    _ =>
      r.nextBool()
          ? [r.between(100, 999), r.between(100, 999)]
          : [r.between(12, 99), r.between(12, 99), r.between(12, 99)],
  };
  final answer = factors.reduce((a, b) => a * b);
  final expr = factors.map(_n).join(' × ');
  return (AppStrings.mathMultiply(expr), answer, '', '$expr = ${_n(answer)}');
}

MathMade _power(SeededRandom r, int level) {
  final (base, exponent) = switch (level) {
    1 => (2, r.between(8, 16)),
    2 => switch (r.pick(const [3, 5, 6, 7])) {
      3 => (3, r.between(9, 14)),
      5 => (5, r.between(6, 10)),
      6 => (6, r.between(6, 9)),
      _ => (7, r.between(5, 8)),
    },
    _ =>
      r.nextBool()
          ? (r.between(11, 19), r.between(5, 8))
          : (2, r.between(25, 39)),
  };
  final answer = math.pow(base, exponent).toInt();
  final expr = '$base${superscript(exponent)}';
  return (AppStrings.mathPower(expr), answer, '', '$expr = ${_n(answer)}');
}

MathMade _root(SeededRandom r, int level) {
  if (level == 3) {
    int n;
    do {
      n = r.between(1000, 999999);
    } while (_isCube(n));
    final answer = roundTo(math.pow(n, 1 / 3).toDouble(), 1);
    final c = answer.floor();
    return (
      AppStrings.mathCubeRoot(_n(n)),
      answer,
      '',
      '∛${_n(n)} ≈ ${_n(answer, 1)} '
          '(${_n(c)}³ = ${_n(c * c * c)}, ${_n(c + 1)}³ = '
          '${_n((c + 1) * (c + 1) * (c + 1))})',
    );
  }
  int n;
  do {
    n = level == 1 ? r.between(50, 999) : r.between(1000, 99999);
  } while (_isSquare(n));
  final answer = roundTo(math.sqrt(n), 1);
  final s = answer.floor();
  return (
    AppStrings.mathSquareRoot(_n(n)),
    answer,
    '',
    '√${_n(n)} ≈ ${_n(answer, 1)} '
        '(${_n(s)}² = ${_n(s * s)}, ${_n(s + 1)}² = ${_n((s + 1) * (s + 1))})',
  );
}

MathMade _factorial(SeededRandom r, int level) {
  final n = switch (level) {
    1 => r.between(5, 7),
    2 => r.between(8, 10),
    _ => r.between(11, 14),
  };
  final answer = factorial(n);
  return (
    AppStrings.mathFactorial(n),
    answer,
    '',
    '$n! = 1 × 2 × … × $n = ${_n(answer)}',
  );
}

MathMade _combination(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final n = r.between(8, 30);
      final answer = choose(n, 2);
      return (
        AppStrings.mathHandshakes(n),
        answer,
        '',
        '$n × ${n - 1} ÷ 2 = ${_n(answer)}',
      );
    case 2:
      final n = r.between(10, 30);
      final k = r.between(3, 4);
      final answer = choose(n, k);
      return (
        AppStrings.mathTeams(n, k),
        answer,
        '',
        'C($n, $k) = ${_n(answer)}',
      );
    default:
      final n = r.between(40, 60);
      final k = r.between(5, 6);
      final answer = choose(n, k);
      return (
        AppStrings.mathLottery(n, k),
        answer,
        '',
        'C($n, $k) = ${_n(answer)}',
      );
  }
}

MathMade _series(SeededRandom r, int level) {
  if (level == 3) {
    final n = r.between(20, 100);
    final answer = n * (n + 1) * (2 * n + 1) ~/ 6;
    return (
      AppStrings.mathSumSquares(n),
      answer,
      '',
      '$n × ${n + 1} × ${2 * n + 1} ÷ 6 = ${_n(answer)}',
    );
  }
  final n = level == 1 ? r.between(20, 100) : r.between(101, 2000);
  final answer = n * (n + 1) ~/ 2;
  return (
    AppStrings.mathSumTo(_n(n)),
    answer,
    '',
    '${_n(n)} × ${_n(n + 1)} ÷ 2 = ${_n(answer)}',
  );
}

MathMade _compound(SeededRandom r, int level) {
  if (level == 3) {
    final rate = r.between(3, 15);
    final years = roundTo(math.log(2) / math.log(1 + rate / 100), 1);
    return (
      AppStrings.mathDoubling(rate),
      years,
      AppStrings.mathYears,
      'log 2 ÷ log ${_n(1 + rate / 100, 2)} ≈ ${_n(years, 1)}',
    );
  }
  final principal = r.pick(const [1000, 2000, 5000, 10000]);
  final (rate, years) = level == 1
      ? (r.pick(const [10, 20, 25, 50]), r.between(2, 3))
      : (r.between(5, 30), r.between(5, 10));
  final answer = (principal * math.pow(1 + rate / 100, years)).round();
  return (
    AppStrings.mathCompound(_n(principal), rate, years),
    answer,
    'TL',
    '${_n(principal)} × ${_n(1 + rate / 100, 2)}${superscript(years)} '
        '≈ ${_n(answer)}',
  );
}

MathMade _percent(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final x = r.between(2, 90) * 100;
      final p = r.stepped(5, 95, 5);
      final answer = x * p ~/ 100;
      return (
        AppStrings.mathPercentOf(_n(x), p),
        answer,
        '',
        '${_n(x)} × $p ÷ 100 = ${_n(answer)}',
      );
    case 2:
      final x = r.between(5, 50) * 100;
      final up = r.stepped(10, 50, 5);
      final down = r.stepped(10, 50, 5);
      final answer = roundTo(x * (1 + up / 100) * (1 - down / 100), 2);
      return (
        AppStrings.mathRaiseThenCut(_n(x), up, down),
        answer,
        'TL',
        '${_n(x)} × ${_n(1 + up / 100, 2)} × ${_n(1 - down / 100, 2)} '
            '= ${_n(answer, 2)}',
      );
    default:
      final p = r.between(2, 5);
      final answer = roundTo((math.pow(1 + p / 100, 12) - 1) * 100, 1);
      return (
        AppStrings.mathMonthlyRise(p),
        answer,
        '%',
        '${_n(1 + p / 100, 2)}¹² − 1 ≈ %${_n(answer, 1)}',
      );
  }
}

MathMade _units(SeededRandom r, int level) {
  switch (level) {
    case 1:
      if (r.nextBool()) {
        final v = r.between(20, 200);
        final answer = roundTo(v / 3.6, 1);
        return (
          AppStrings.mathKmhToMs(v),
          answer,
          'm/sn',
          '$v × 1.000 ÷ 3.600 ≈ ${_n(answer, 1)}',
        );
      }
      final days = r.between(2, 30);
      final answer = days * 24 * 60;
      return (
        AppStrings.mathDaysToMinutes(days),
        answer,
        AppStrings.mathMinutes,
        '$days × 24 × 60 = ${_n(answer)}',
      );
    case 2:
      if (r.nextBool()) {
        final miles = r.between(10, 500);
        final answer = roundTo(miles * 1.609344, 1);
        return (
          AppStrings.mathMilesToKm(miles),
          answer,
          'km',
          '$miles × 1,609344 ≈ ${_n(answer, 1)}',
        );
      }
      final years = r.between(1, 20);
      final answer = years * 365 * 24 * 3600;
      return (
        AppStrings.mathYearsToSeconds(years),
        answer,
        AppStrings.mathSeconds,
        '$years × 365 × 86.400 = ${_n(answer)}',
      );
    default:
      final days = r.between(1, 60);
      final answer = roundTo(299792.458 * 86400 * days / 1e9, 1);
      return (
        AppStrings.mathLightDays(days),
        answer,
        AppStrings.mathBillionKm,
        '299.792,458 × 86.400 × $days ≈ ${_n(answer, 1)} milyar',
      );
  }
}

MathMade _geometry(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final radius = r.between(3, 30);
      final answer = roundTo(math.pi * radius * radius, 1);
      return (
        AppStrings.mathCircleArea(radius),
        answer,
        'cm²',
        'π × $radius² ≈ ${_n(answer, 1)}',
      );
    case 2:
      final d = r.between(4, 40);
      final answer = roundTo(4 / 3 * math.pi * math.pow(d / 2, 3), 1);
      return (
        AppStrings.mathSphereVolume(d),
        answer,
        'cm³',
        '4 ÷ 3 × π × ${_n(d / 2, 1)}³ ≈ ${_n(answer, 1)}',
      );
    default:
      final a = r.between(5, 40);
      final b = r.between(5, 40);
      final c = r.between((a - b).abs() + 1, a + b - 1);
      final s = (a + b + c) / 2;
      final answer = roundTo(math.sqrt(s * (s - a) * (s - b) * (s - c)), 1);
      return (
        AppStrings.mathTriangleArea(a, b, c),
        answer,
        'cm²',
        'Heron: √(s(s − a)(s − b)(s − c)), s = ${_n(s, 1)} → '
            '${_n(answer, 1)}',
      );
  }
}

MathMade _probability(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final throws = r.between(2, 12);
      final answer = roundTo((1 - math.pow(5 / 6, throws)) * 100, 1);
      return (
        AppStrings.mathAtLeastOneSix(throws),
        answer,
        '%',
        '1 − (5/6)${superscript(throws)} ≈ %${_n(answer, 1)}',
      );
    case 2:
      final people = r.between(10, 50);
      final answer = roundTo(sharedBirthday(people) * 100, 1);
      return (
        AppStrings.mathSharedBirthday(people),
        answer,
        '%',
        '1 − (365 × 364 × … × ${366 - people}) ÷ 365${superscript(people)} '
            '≈ %${_n(answer, 1)}',
      );
    default:
      final people = r.between(50, 500);
      final answer = roundTo((1 - math.pow(364 / 365, people)) * 100, 1);
      return (
        AppStrings.mathMyBirthday(people),
        answer,
        '%',
        '1 − (364/365)${superscript(people)} ≈ %${_n(answer, 1)}',
      );
  }
}

MathMade _primes(SeededRandom r, int level) {
  final n = switch (level) {
    1 => r.stepped(50, 300, 10),
    2 => r.stepped(1000, 20000, 500),
    _ => r.stepped(100000, 2000000, 50000),
  };
  final answer = primeCount(n);
  return (
    AppStrings.mathPrimes(_n(n)),
    answer,
    '',
    AppStrings.mathPrimesWorking(_n(n), _n(answer)),
  );
}

MathMade _digits(SeededRandom r, int level) {
  switch (level) {
    case 1:
      final e = r.between(20, 60);
      final answer = powerDigits(2, e);
      return (
        AppStrings.mathDigits('2${superscript(e)}'),
        answer,
        '',
        '$e × log 2 ≈ ${_n(e * math.log(2) / math.ln10, 2)} → $answer',
      );
    case 2:
      final base = r.between(3, 9);
      final e = r.between(20, 80);
      final answer = powerDigits(base, e);
      return (
        AppStrings.mathDigits('$base${superscript(e)}'),
        answer,
        '',
        '$e × log $base ≈ '
            '${_n(e * math.log(base) / math.ln10, 2)} → $answer',
      );
    default:
      final n = r.between(20, 80);
      final answer = factorialDigits(n);
      return (
        AppStrings.mathDigits('$n!'),
        answer,
        '',
        'log 1 + log 2 + … + log $n → $answer',
      );
  }
}

MathMade _fibonacci(SeededRandom r, int level) {
  final n = switch (level) {
    1 => r.between(12, 20),
    2 => r.between(21, 35),
    _ => r.between(36, 55),
  };
  final answer = fibonacci(n);
  return (
    AppStrings.mathFibonacci(n),
    answer,
    '',
    'F($n) = F(${n - 1}) + F(${n - 2}) = ${_n(answer)}',
  );
}

MathMade _folding(SeededRandom r, int level) {
  // A 0,1 mm sheet doubles with every fold.
  final (folds, unit, perUnit) = switch (level) {
    1 => (r.between(8, 12), 'cm', 0.01),
    2 => (r.between(15, 25), 'm', 0.0001),
    _ => (r.between(30, 42), 'km', 0.0000001),
  };
  final answer = roundTo(perUnit * math.pow(2, folds), 1);
  return (
    AppStrings.mathFolding(folds, unit),
    answer,
    unit,
    '0,1 mm × 2${superscript(folds)} ≈ ${_n(answer, 1)} $unit',
  );
}
