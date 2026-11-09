import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/moderation.dart';

/// Report or block another player's [name] seen at [place]: a bottom sheet
/// with the two actions, then a short note. Nothing happens for an empty
/// name.
Future<void> showPlayerActions(
  BuildContext context, {
  required String name,
  required ReportPlace place,
  Moderation? moderation,
}) async {
  if (name.isEmpty) return;
  final m = moderation ?? Moderation.instance;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final blocked = m.isBlocked(name);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                m.shown(name),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            if (m.report != null)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text(AppStrings.reportName),
                subtitle: const Text(AppStrings.reportNameHint),
                onTap: () => Navigator.of(context).pop(_Action.report),
              ),
            ListTile(
              leading: Icon(blocked ? Icons.undo_rounded : Icons.block_rounded),
              title: Text(
                blocked ? AppStrings.unblockPlayer : AppStrings.blockPlayer,
              ),
              subtitle: blocked ? null : const Text(AppStrings.blockPlayerHint),
              onTap: () =>
                  Navigator.of(context)
                      .pop(blocked ? _Action.unblock : _Action.block),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  void note(String text) =>
      messenger?.showSnackBar(SnackBar(content: Text(text)));
  switch (action) {
    case _Action.report:
      final sent = await m.report?.call(name, place) ?? false;
      note(sent ? AppStrings.reportSent : AppStrings.reportFailed);
    case _Action.block:
      await m.block(name);
      note(AppStrings.playerBlocked);
    case _Action.unblock:
      await m.unblock(name);
      note(AppStrings.playerUnblocked);
    case null:
      break;
  }
}

enum _Action { report, block, unblock }
