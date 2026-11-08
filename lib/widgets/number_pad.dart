import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/strings.dart';

/// Large 3×4 digit pad. The bottom-left key is "000" (handy for big
/// magnitudes) or empty for years. Long-press ⌫ clears.
class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.onDigits,
    required this.onBackspace,
    required this.onClear,
    this.showTripleZero = true,
    this.keyHeight = NumberPad.fullKeyHeight,
  });

  final ValueChanged<String> onDigits;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool showTripleZero;

  /// Height of each key; smaller on short screens (see [keyHeightFor]).
  final double keyHeight;

  static const double fullKeyHeight = 60;

  /// Never smaller than this: with its padding a key stays a 52 dp target.
  static const double minKeyHeight = 44;

  /// The key height that fits the pad and [others] (the rest of the
  /// column, in dp) into [maxHeight]: the full height when there is room.
  static double keyHeightFor(double maxHeight, {required double others}) {
    if (!maxHeight.isFinite) return fullKeyHeight;
    return ((maxHeight - others) / 4 - 8).clamp(minKeyHeight, fullKeyHeight);
  }

  @override
  Widget build(BuildContext context) {
    Widget digit(String label) => _PadKey(
      onTap: () => onDigits(label),
      height: keyHeight,
      child: Text(label),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) Expanded(child: digit(d))]),
        Row(
          children: [
            Expanded(
              child: showTripleZero
                  ? digit('000')
                  : SizedBox(height: keyHeight),
            ),
            Expanded(child: digit('0')),
            Expanded(
              child: _PadKey(
                height: keyHeight,
                onTap: onBackspace,
                onLongPress: onClear,
                semanticLabel: AppStrings.delete,
                child: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.onTap,
    required this.child,
    required this.height,
    this.onLongPress,
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                },
          child: Semantics(
            label: semanticLabel,
            button: true,
            child: SizedBox(
              height: height,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.headlineSmall,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
