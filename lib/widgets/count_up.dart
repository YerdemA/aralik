import 'package:flutter/material.dart';

/// An integer that counts up from 0 to [value] once, then stays.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.textAlign = TextAlign.center,
    this.format,
    this.duration = const Duration(milliseconds: 700),
  });

  final int value;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Builds the text for an intermediate value; defaults to the number.
  final String Function(int value)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final text = format ?? (int v) => '$v';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        text(v.round()),
        style: style,
        textAlign: textAlign,
        // Read the final value, not the moving one.
        semanticsLabel: text(value),
      ),
    );
  }
}
