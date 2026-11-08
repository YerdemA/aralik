// The philosopher's mood on the daily share card, from the day's total
// (pure). Five bands over the possible −250…500.

/// Best first. [minTotal] is the lowest daily total of the band.
enum DayMood {
  /// Laughing and flexing.
  legend(450),

  /// Beaming, thumbs up.
  great(350),

  /// Chest out, a smile under the moustache.
  proud(200),

  /// Unsure, scratching his head.
  unsure(0),

  /// Deflated, under a little rain cloud.
  down(null);

  const DayMood(this.minTotal);

  final int? minTotal;

  static DayMood of(int total) =>
      values.firstWhere((m) => m.minTotal == null || total >= m.minTotal!);

  /// Math mode (2026-11-08): no minus points and a strict slider, so the
  /// bands sit over 0…500 instead: 0 there is a bad round, not "idare
  /// eder".
  static const Map<DayMood, int> mathMinTotals = {
    legend: 400,
    great: 275,
    proud: 150,
    unsure: 50,
  };

  static DayMood ofMath(int total) => values.firstWhere(
    (m) => !mathMinTotals.containsKey(m) || total >= mathMinTotals[m]!,
  );
}
