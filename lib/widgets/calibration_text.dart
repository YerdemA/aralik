import '../core/number_format.dart';
import '../core/scoring.dart';
import '../core/strings.dart';

/// "%62 · Aralıkların fazla dar." or a hint while there is too little data.
String calibrationSummary(int hits, int answered) {
  final feedback = calibrationFeedback(hits, answered);
  final text = switch (feedback) {
    CalibrationFeedback.notEnoughData => AppStrings.calibrationNoData,
    CalibrationFeedback.tooNarrow => AppStrings.calibrationTooNarrow,
    CalibrationFeedback.good => AppStrings.calibrationGood,
    CalibrationFeedback.tooWide => AppStrings.calibrationTooWide,
  };
  if (feedback == CalibrationFeedback.notEnoughData) return text;
  return '${formatPercent(hits / answered)} · $text';
}
