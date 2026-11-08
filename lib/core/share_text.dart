import 'daily.dart';
import 'number_format.dart';
import 'scoring.dart';
import 'strings.dart';

/// Wordle-style share card:
///
/// ```
/// Kabaca · 4 Kasım · 380/500
/// 🟩🟩🟨⬛🟩
/// Kalibrasyon %80
/// ```
///
/// The calibration line appears only once there are enough answers for it
/// to mean something. Without [dayIndex] it is a free-play round:
/// "Kabaca · Serbest tur · 320/500" (out of its own questions' maximum).
String shareText({
  int? dayIndex,
  required List<QuestionResult> results,
  required int hits,
  required int answered,
}) {
  final title = '${AppStrings.appName} · ${shareLabel(dayIndex)}';
  final total = totalPoints(results);
  final max = dayIndex == null
      ? results.length * maxPointsPerQuestion
      : maxDailyPoints;
  final squares = results.map((r) => r.tier.emoji).join();
  final rate = answered >= minAnswersForCalibration
      ? calibrationRate(hits, answered)
      : null;
  return [
    '$title · $total/$max',
    squares,
    if (rate != null) '${AppStrings.calibration} ${formatPercent(rate)}',
  ].join('\n');
}

/// What the share text and card call the set: "4 Kasım", or "Serbest tur".
String shareLabel(int? dayIndex) => dayIndex == null
    ? AppStrings.freeRoundLabel
    : dayLabel(dateOfDay(dayIndex));
