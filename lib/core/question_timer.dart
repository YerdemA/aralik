// Time limit of daily-set questions (pure functions).

/// Time allowed per daily question, from the moment it is first shown.
/// Math mode: long enough to estimate, too short to work it out exactly.
const Duration mathTimeLimit = Duration(seconds: 30);

const Duration dailyTimeLimit = Duration(seconds: 15);

/// Below this the countdown turns to the warning colour.
const Duration timeWarning = Duration(seconds: 5);

/// Time left of [limit] for a question first shown at [startedAt].
///
/// Clamped to 0…[limit], so a clock set back never gives more than [limit].
Duration timeLeft({
  required DateTime startedAt,
  required DateTime now,
  Duration limit = dailyTimeLimit,
}) {
  final elapsed = now.difference(startedAt);
  if (elapsed.isNegative) return limit;
  final left = limit - elapsed;
  return left.isNegative ? Duration.zero : left;
}

/// Whole seconds shown on the countdown: 14,2 s → 15, 0 → 0.
int secondsShown(Duration left) => (left.inMilliseconds / 1000).ceil();
