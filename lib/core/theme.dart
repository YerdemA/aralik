import 'package:flutter/material.dart';

/// App-wide light and dark themes (Material 3, system font).
abstract final class AppTheme {
  static const Color _seed = Color(0xFF2E6BD9);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    const largeTarget = Size(64, 56);
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        // Big numbers (guess, interval, score) use tabular figures so they
        // don't jitter while the slider moves.
        displayMedium: base.textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: largeTarget,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: largeTarget,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 8),
      extensions: [
        brightness == Brightness.light ? GameColors.light : GameColors.dark,
      ],
    );
  }
}

/// Result colors, matching the share card emojis (🟩 🟨 ⬛).
@immutable
class GameColors extends ThemeExtension<GameColors> {
  const GameColors({
    required this.good,
    required this.partial,
    required this.miss,
  });

  /// ≥70 points.
  final Color good;

  /// 1–69 points.
  final Color partial;

  /// Interval missed the answer.
  final Color miss;

  static const light = GameColors(
    good: Color(0xFF2E9E5B),
    partial: Color(0xFFD9A400),
    miss: Color(0xFF5F6368),
  );

  static const dark = GameColors(
    good: Color(0xFF5CCB8A),
    partial: Color(0xFFF2C94C),
    miss: Color(0xFF9AA0A6),
  );

  @override
  GameColors copyWith({Color? good, Color? partial, Color? miss}) => GameColors(
    good: good ?? this.good,
    partial: partial ?? this.partial,
    miss: miss ?? this.miss,
  );

  @override
  GameColors lerp(GameColors? other, double t) {
    if (other == null) return this;
    return GameColors(
      good: Color.lerp(good, other.good, t)!,
      partial: Color.lerp(partial, other.partial, t)!,
      miss: Color.lerp(miss, other.miss, t)!,
    );
  }
}
