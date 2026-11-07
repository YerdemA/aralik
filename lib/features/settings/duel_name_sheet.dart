import 'package:flutter/material.dart';

import '../../core/nickname.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/settings_store.dart';

/// The name duel opponents see: the one chosen in Settings, else the
/// leaderboard nickname, else null (the lobby then asks for one).
String? duelNameOf(SettingsStore settings, String? leaderboardNickname) =>
    settings.duelName ?? leaderboardNickname;

/// Asks for the duel name and saves it. The only place it is typed: the
/// lobby shows it and sends the player here to change it.
Future<void> showDuelNameSheet(
  BuildContext context,
  SettingsStore settings, {
  String? initial,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DuelNameSheet(settings: settings, initial: initial),
);

class _DuelNameSheet extends StatefulWidget {
  const _DuelNameSheet({required this.settings, this.initial});

  final SettingsStore settings;
  final String? initial;

  @override
  State<_DuelNameSheet> createState() => _DuelNameSheetState();
}

class _DuelNameSheetState extends State<_DuelNameSheet> {
  late final _controller = TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = tidyNickname(_controller.text);
    final problem = nicknameProblem(name);
    if (problem != null) {
      setState(
        () => _error = switch (problem) {
          NicknameProblem.tooShort => AppStrings.nicknameTooShort,
          NicknameProblem.tooLong => AppStrings.nicknameTooLong,
          NicknameProblem.badCharacters => AppStrings.nicknameBadCharacters,
        },
      );
      return;
    }
    await widget.settings.setDuelName(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.duelNameTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: nicknameMaxLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: AppStrings.duelNameLabel,
              hintText: AppStrings.nicknameHint,
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text(AppStrings.save)),
        ],
      ),
    );
  }
}

/// The name opponents will see, and where to change it.
class PlayingAsCard extends StatelessWidget {
  const PlayingAsCard({super.key, required this.name, required this.onChange});

  final String name;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Palette.duelMe,
          foregroundColor: Colors.white,
          child: Text(name.characters.first.toUpperCase()),
        ),
        title: Text(name, style: theme.textTheme.titleMedium),
        subtitle: const Text(AppStrings.duelNameInSettings),
        trailing: const Icon(Icons.settings_rounded),
        onTap: onChange,
      ),
    );
  }
}

/// No name yet: duels and tournaments wait until one is chosen in
/// Settings.
class NameNeededCard extends StatelessWidget {
  const NameNeededCard({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.duelNameNeeded, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.settings_rounded),
              label: const Text(AppStrings.duelPickName),
            ),
          ],
        ),
      ),
    );
  }
}
