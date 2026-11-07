import 'package:flutter/material.dart';

import '../../core/nickname.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/leaderboard.dart';
import '../../data/settings_store.dart';
import '../leaderboard/join_sheet.dart';

/// The player's one name, used on the leaderboard, in duels and in
/// tournaments. It is typed only here (Settings); everywhere else shows it
/// and sends the player to Settings to choose or change it. It may change
/// once every three days ([nameChangeEvery]); while joined the server
/// checks that too and the leaderboard nickname changes with it.
Future<void> showUserNameSheet(
  BuildContext context,
  SettingsStore settings,
  LeaderboardStore? leaderboard,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _UserNameSheet(settings: settings, leaderboard: leaderboard),
);

/// Makes the name in Settings the leaderboard account's, when joined (an
/// older app kept them apart; a restored account brings its own).
Future<void> syncUserName(
  SettingsStore settings,
  LeaderboardStore? leaderboard,
) async {
  final nickname = leaderboard?.account?.nickname;
  if (nickname != null) await settings.adoptUserName(nickname);
}

String _problemText(NicknameProblem p) => switch (p) {
  NicknameProblem.tooShort => AppStrings.nicknameTooShort,
  NicknameProblem.tooLong => AppStrings.nicknameTooLong,
  NicknameProblem.badCharacters => AppStrings.nicknameBadCharacters,
};

class _UserNameSheet extends StatefulWidget {
  const _UserNameSheet({required this.settings, this.leaderboard});

  final SettingsStore settings;
  final LeaderboardStore? leaderboard;

  @override
  State<_UserNameSheet> createState() => _UserNameSheetState();
}

class _UserNameSheetState extends State<_UserNameSheet> {
  late final _controller = TextEditingController(
    text: widget.settings.userName ?? '',
  );
  late DateTime? _waitUntil = widget.settings.nextNameChange();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = widget.settings;
    final name = tidyNickname(_controller.text);
    if (name == settings.userName) {
      Navigator.of(context).pop();
      return;
    }
    final problem = nicknameProblem(name);
    if (problem != null) {
      setState(() => _error = _problemText(problem));
      return;
    }
    final leaderboard = widget.leaderboard;
    if (leaderboard == null || !leaderboard.joined) {
      await settings.setUserName(name);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // Joined: the leaderboard nickname changes too, and the server has the
    // last word (taken names, its own record of the last change).
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await leaderboard.rename(name);
      await settings.setUserName(leaderboard.account?.nickname ?? name);
      if (mounted) Navigator.of(context).pop();
    } on LeaderboardException catch (e) {
      final retryAt = e.retryAt;
      if (e.failure == LeaderboardFailure.renameWait && retryAt != null) {
        await settings.markNameChanged(retryAt.subtract(nameChangeEvery));
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.failure == LeaderboardFailure.renameWait) {
          _waitUntil = retryAt ?? _waitUntil;
          _error = null;
        } else {
          _error = leaderboardFailureText(e.failure);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waitUntil = _waitUntil;
    final locked = waitUntil != null;
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
          Text(AppStrings.userNameSection, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            locked ? AppStrings.renameWait(waitUntil) : AppStrings.userNameBody,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: !locked,
            enabled: !_busy && !locked,
            maxLength: nicknameMaxLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: AppStrings.userNameLabel,
              hintText: AppStrings.nicknameHint,
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || locked ? null : _save,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text(AppStrings.save),
          ),
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
