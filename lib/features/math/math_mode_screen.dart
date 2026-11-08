import 'package:flutter/material.dart';

import '../../core/math/math_problem.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// Math mode's start: the rules in one line, then basic or further on.
/// Pops with the chosen [MathTier].
class MathModeScreen extends StatelessWidget {
  const MathModeScreen({super.key, this.onDuel});

  /// Opens the math duel's lobby; null hides it (no server).
  final VoidCallback? onDuel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.modeMath)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              AppStrings.mathChoose,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(AppStrings.mathRules, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            const _TierCard(
              tier: MathTier.basic,
              icon: Icons.calculate_rounded,
              title: AppStrings.mathBasic,
              hint: AppStrings.mathBasicHint,
              colors: [Palette.mathStart, Palette.mathEnd],
            ),
            const SizedBox(height: 14),
            const _TierCard(
              tier: MathTier.advanced,
              icon: Icons.functions_rounded,
              title: AppStrings.mathAdvanced,
              hint: AppStrings.mathAdvancedHint,
              colors: [Palette.heroTop, Palette.heroBottom],
            ),
            if (onDuel != null) ...[
              const SizedBox(height: 14),
              _TierCard(
                onTap: onDuel,
                icon: Icons.bolt_rounded,
                title: AppStrings.mathDuel,
                hint: AppStrings.mathDuelHint,
                colors: const [Palette.duelMe, Palette.duelOpponent],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    this.tier,
    this.onTap,
    required this.icon,
    required this.title,
    required this.hint,
    required this.colors,
  });

  /// Picks this tier (pops with it); or [onTap] does something else.
  final MathTier? tier;
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String hint;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(24);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap ?? () => Navigator.of(context).pop(tier),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: .2),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
