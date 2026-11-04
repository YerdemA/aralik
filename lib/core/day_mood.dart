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
}
