import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/strings.dart';

/// A URL as selectable text with a copy button. Links are not opened in a
/// browser, which would need an extra package.
class LinkText extends StatelessWidget {
  const LinkText({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            url,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        IconButton(
          tooltip: AppStrings.copyLink,
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.linkCopied)),
            );
          },
        ),
      ],
    );
  }
}
