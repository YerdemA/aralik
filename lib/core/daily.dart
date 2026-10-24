/// Daily set selection. Everyone sees the same questions on the same local
/// date, so no backend is needed.
library;

const int questionsPerDay = 5;

/// Day 0 of the game (local calendar date).
final DateTime epoch = DateTime(2026, 11, 1);

/// Days between [epoch] and the local calendar date of [now].
///
/// Computed on calendar dates in UTC, so DST shifts and the time of day do
/// not matter. Negative before the epoch.
int dayIndexFor(DateTime now) {
  final local = now.toLocal();
  final today = DateTime.utc(local.year, local.month, local.day);
  final start = DateTime.utc(epoch.year, epoch.month, epoch.day);
  return today.difference(start).inDays;
}

/// Public puzzle number shown in the share text ("Aralık #1" on day 0).
int puzzleNumber(int dayIndex) => dayIndex + 1;

/// Bank indices of the questions for [dayIndex]:
/// `5·dayIndex .. 5·dayIndex+4`, wrapping around when the bank runs out.
List<int> dailyIndices(int dayIndex, int bankSize) {
  if (bankSize <= 0) return const [];
  final count = questionsPerDay < bankSize ? questionsPerDay : bankSize;
  return List.unmodifiable([
    for (var k = 0; k < count; k++) (questionsPerDay * dayIndex + k) % bankSize,
  ]);
}

/// Bank indices available for practice on [todayIndex]: only questions of
/// past days, never today's set, so nothing upcoming is spoiled.
///
/// Sorted and unique. Empty on or before day 0.
List<int> practiceIndices(int todayIndex, int bankSize) {
  if (todayIndex <= 0 || bankSize <= 0) return const [];
  final pastCount = questionsPerDay * todayIndex;
  final today = dailyIndices(todayIndex, bankSize).toSet();
  return List.unmodifiable([
    for (var i = 0; i < bankSize && i < pastCount; i++)
      if (!today.contains(i)) i,
  ]);
}
