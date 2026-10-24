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
  });

  final ValueChanged<String> onDigits;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool showTripleZero;

  static const double keyHeight = 60;

  @override
  Widget build(BuildContext context) {
    Widget digit(String label) =>
        _PadKey(onTap: () => onDigits(label), child: Text(label));

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
                  : const SizedBox(height: keyHeight),
            ),
            Expanded(child: digit('0')),
            Expanded(
              child: _PadKey(
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
    this.onLongPress,
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final Widget child;

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
              height: NumberPad.keyHeight,
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
