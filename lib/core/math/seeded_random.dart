/// A small seeded random generator (mulberry32) that gives the same
/// numbers in Dart and in JavaScript: the same seed makes the same math
/// question on the phone and, later, on the duel server.
///
/// JavaScript reference (server side):
///
/// ```js
/// a = (a + 0x6D2B79F5) | 0;
/// let t = Math.imul(a ^ (a >>> 15), 1 | a);
/// t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
/// return (t ^ (t >>> 14)) >>> 0;
/// ```
///
/// Native Dart ints are 64-bit; everything is kept to 32 bits with [_m].
class SeededRandom {
  SeededRandom(int seed) : _a = seed & _m;

  static const int _m = 0xFFFFFFFF;
  int _a;

  static int _imul(int x, int y) => (x * y) & _m;

  /// The next number, 0 ≤ n < 2³².
  int nextUint32() {
    _a = (_a + 0x6D2B79F5) & _m;
    var t = _imul(_a ^ (_a >>> 15), _a | 1);
    t = ((t + _imul(t ^ (t >>> 7), t | 61)) & _m) ^ t;
    return (t ^ (t >>> 14)) & _m;
  }

  /// 0 ≤ n < [max]. (Plain modulo: the bias is negligible for the small
  /// ranges used here, and the server does the same.)
  int nextInt(int max) => nextUint32() % max;

  /// [min] ≤ n ≤ [max].
  int between(int min, int max) => min + nextInt(max - min + 1);

  /// [min], [min] + [step], … up to [max].
  int stepped(int min, int max, int step) =>
      min + step * nextInt((max - min) ~/ step + 1);

  bool nextBool() => nextInt(2) == 1;

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}
