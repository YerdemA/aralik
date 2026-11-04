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
/// to mean something.
String dailyShareText({
  required int dayIndex,
  required List<QuestionResult> results,
  required int hits,
  required int answered,
}) {
  final title = '${AppStrings.appName} · ${dayLabel(dateOfDay(dayIndex))}';
  final total = totalPoints(results);
  final squares = results.map((r) => r.tier.emoji).join();
  final rate = answered >= minAnswersForCalibration
      ? calibrationRate(hits, answered)
      : null;
  return [
    '$title · $total/$maxDailyPoints',
    squares,
    if (rate != null) '${AppStrings.calibration} ${formatPercent(rate)}',
  ].join('\n');
}
