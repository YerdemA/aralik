import 'daily.dart';
import 'number_format.dart';
import 'scoring.dart';
import 'strings.dart';

/// Wordle-style share card:
///
/// ```
/// Aralık #42 · 380/500
/// 🟩🟩🟨⬛🟩
/// Kalibrasyon %80
/// ```
///
/// The calibration line appears only once there are enough answers for it
/// to mean something. Before the epoch the title says "deneme" instead of a
/// number.
String dailyShareText({
  required int dayIndex,
  required List<QuestionResult> results,
  required int hits,
  required int answered,
}) {
  final number = puzzleNumber(dayIndex);
  final title = number > 0
      ? '${AppStrings.appName} #$number'
      : '${AppStrings.appName} ${AppStrings.previewEdition}';
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
