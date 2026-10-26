import 'package:flutter/material.dart';

/// A big value over a small label, sharing a [Row] equally.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
