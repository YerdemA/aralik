import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/question.dart';
import 'scoring.dart';

/// Brand colours. The navy seeds the theme and is the app icon's
/// background (tools/icon/render_icon_test.dart); the terracotta matches
/// the philosopher's toga. All of them colour the result burst.
abstract final class Palette {
  static const navy = Color(0xFF3E5683);
  static const sky = Color(0xFF8EC5FF);
  static const terracotta = Color(0xFFD9825B);
  static const green = Color(0xFF8BCB72);
  static const pink = Color(0xFFF6A5C6);
}

/// App-wide light and dark themes (Material 3, system font).
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: Palette.navy,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          // Warm accents, like the toga in the app icon.
          tertiary: isLight ? const Color(0xFFB4532A) : const Color(0xFFFFB590),
          tertiaryContainer: isLight
              ? const Color(0xFFFFDBCB)
              : const Color(0xFF6E3218),
          onTertiaryContainer: isLight
              ? const Color(0xFF3A1100)
              : const Color(0xFFFFDBCB),
          surface: isLight ? const Color(0xFFF6F9FF) : const Color(0xFF111827),
        );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    const largeTarget = Size(64, 58);
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    );
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    const tabular = [FontFeature.tabularFigures()];
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        // Big numbers (guess, interval, score) use tabular figures so they
        // don't jitter while the slider moves.
        displayLarge: text.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -2,
          fontFeatures: tabular,
        ),
        displayMedium: text.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          fontFeatures: tabular,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: tabular,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        // A transparent app bar cannot guess the icon colour from its
        // background, so set it from the theme: dark icons when light.
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
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
          backgroundColor: isLight ? Colors.white : scheme.surfaceContainer,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 10,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 14),
      ),
      extensions: [isLight ? GameColors.light : GameColors.dark],
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
    required this.streak,
  });

  /// ≥70 points.
  final Color good;

  /// 1–69 points.
  final Color partial;

  /// Interval missed the answer.
  final Color miss;

  /// The streak flame.
  final Color streak;

  Color forTier(ResultTier tier) => switch (tier) {
    ResultTier.good => good,
    ResultTier.partial => partial,
    ResultTier.miss => miss,
  };

  static const light = GameColors(
    good: Color(0xFF2E9E5B),
    partial: Color(0xFFD9A400),
    miss: Color(0xFF5F6368),
    streak: Color(0xFFE0662B),
  );

  static const dark = GameColors(
    good: Color(0xFF5CCB8A),
    partial: Color(0xFFF2C94C),
    miss: Color(0xFF9AA0A6),
    streak: Color(0xFFFF9A5C),
  );

  @override
  GameColors copyWith({
    Color? good,
    Color? partial,
    Color? miss,
    Color? streak,
  }) => GameColors(
    good: good ?? this.good,
    partial: partial ?? this.partial,
    miss: miss ?? this.miss,
    streak: streak ?? this.streak,
  );

  @override
  GameColors lerp(GameColors? other, double t) {
    if (other == null) return this;
    return GameColors(
      good: Color.lerp(good, other.good, t)!,
      partial: Color.lerp(partial, other.partial, t)!,
      miss: Color.lerp(miss, other.miss, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
    );
  }
}

/// Icon and colour of a question category.
extension CategoryStyle on QuestionCategory {
  IconData get icon => switch (this) {
    QuestionCategory.geography => Icons.terrain_rounded,
    QuestionCategory.history => Icons.account_balance_rounded,
    QuestionCategory.turkey => Icons.flag_rounded,
    QuestionCategory.science => Icons.science_rounded,
    QuestionCategory.sports => Icons.sports_soccer_rounded,
    QuestionCategory.everyday => Icons.local_cafe_rounded,
    QuestionCategory.animals => Icons.pets_rounded,
    QuestionCategory.companies => Icons.business_rounded,
    QuestionCategory.other => Icons.category_rounded,
  };

  Color color(Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (this) {
      QuestionCategory.geography =>
        light ? const Color(0xFF2F8A4E) : const Color(0xFF7FD69B),
      QuestionCategory.history =>
        light ? const Color(0xFFB4532A) : const Color(0xFFFFB590),
      QuestionCategory.turkey =>
        light ? const Color(0xFFC62E3A) : const Color(0xFFFF9A9F),
      QuestionCategory.science =>
        light ? const Color(0xFF6A4BC4) : const Color(0xFFC3B1FF),
      QuestionCategory.sports =>
        light ? const Color(0xFF2E6BD9) : const Color(0xFF9DC0FF),
      QuestionCategory.everyday =>
        light ? const Color(0xFFB03F70) : const Color(0xFFF6A5C6),
      QuestionCategory.animals =>
        light ? const Color(0xFF8A6A1F) : const Color(0xFFE6C77A),
      QuestionCategory.companies =>
        light ? const Color(0xFF00796B) : const Color(0xFF7FD8CB),
      QuestionCategory.other =>
        light ? const Color(0xFF5F6368) : const Color(0xFFB0B6BE),
    };
  }
}
