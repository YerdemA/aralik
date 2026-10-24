import 'strings.dart';

/// Turkish number formatting: `1.234.567`, `3,5`, `12,5 milyon`.
///
/// Pure functions, no `intl` dependency.

const String _thousandsSeparator = '.';
const String _decimalSeparator = ',';

/// Formats [value] with Turkish separators, rounding to at most
/// [maxDecimals] decimals and trimming trailing zeros.
///
/// `formatNumber(1234567) == '1.234.567'`,
/// `formatNumber(3.5, maxDecimals: 1) == '3,5'`.
String formatNumber(num value, {int maxDecimals = 0}) {
  assert(value.isFinite, 'Cannot format $value');
  assert(maxDecimals >= 0);

  final fixed = value.abs().toStringAsFixed(maxDecimals);
  final dot = fixed.indexOf('.');
  final intPart = dot < 0 ? fixed : fixed.substring(0, dot);
  final fracPart = dot < 0
      ? ''
      : fixed.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '');

  final grouped = _groupThousands(intPart);
  final body = fracPart.isEmpty
      ? grouped
      : '$grouped$_decimalSeparator$fracPart';
  final isZero = intPart == '0' && fracPart.isEmpty;
  return value < 0 && !isZero ? '-$body' : body;
}

/// Formats large magnitudes with a Turkish scale word:
/// `12500000 → '12,5 milyon'`, `2300000000 → '2,3 milyar'`.
/// Values below one million fall back to [formatNumber].
String formatCompact(num value) {
  final abs = value.abs();
  for (final (scale, word) in _scales) {
    // The small tolerance makes 999.960.000 read "1 milyar", not
    // "1.000 milyon", after rounding to one decimal.
    if (abs >= scale * 0.99995) {
      final sign = value < 0 ? '-' : '';
      return '$sign${formatNumber(abs / scale, maxDecimals: 1)} $word';
    }
  }
  return formatNumber(value);
}

const List<(num, String)> _scales = [
  (1e9, AppStrings.billion),
  (1e6, AppStrings.million),
];

/// Formats a calendar year without thousands separators.
/// Negative years are BCE: `-330 → 'MÖ 330'`.
String formatYear(int year) =>
    year < 0 ? '${AppStrings.beforeCommonEra} ${-year}' : '$year';

/// Formats an interval for display, e.g. `4.500 – 5.500 m`.
///
/// For magnitudes a shared scale word is written once:
/// `80 – 90 milyon kişi`. Years are formatted with [formatYear].
String formatRange(num low, num high, {String unit = '', bool isYear = false}) {
  final String text;
  if (isYear) {
    text = '${formatYear(low.round())} – ${formatYear(high.round())}';
  } else {
    final lowText = formatCompact(low);
    final highText = formatCompact(high);
    final lowWord = _scaleWord(lowText);
    text = lowWord != null && lowWord == _scaleWord(highText)
        ? '${lowText.substring(0, lowText.length - lowWord.length - 1)}'
              ' – $highText'
        : '$lowText – $highText';
  }
  return unit.isEmpty ? text : '$text $unit';
}

String? _scaleWord(String formatted) {
  for (final (_, word) in _scales) {
    if (formatted.endsWith(' $word')) return word;
  }
  return null;
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  final firstGroup = digits.length % 3;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (i - firstGroup) % 3 == 0) buffer.write(_thousandsSeparator);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
