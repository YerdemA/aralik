import 'package:flutter/material.dart';

import '../../core/nickname.dart';
import '../../core/strings.dart';
import '../../data/leaderboard.dart';

/// Text for a failed leaderboard request.
String leaderboardFailureText(LeaderboardFailure failure) => switch (failure) {
  LeaderboardFailure.offline => AppStrings.leaderboardOffline,
  LeaderboardFailure.nicknameInvalid => AppStrings.nicknameBadCharacters,
  LeaderboardFailure.nicknameBlocked => AppStrings.nicknameBlocked,
  LeaderboardFailure.nicknameTaken => AppStrings.nicknameTaken,
  LeaderboardFailure.rateLimited => AppStrings.rateLimited,
  LeaderboardFailure.unauthorized => AppStrings.leaderboardMissing,
  LeaderboardFailure.rejected ||
  LeaderboardFailure.server => AppStrings.leaderboardError,
};

String _problemText(NicknameProblem p) => switch (p) {
  NicknameProblem.tooShort => AppStrings.nicknameTooShort,
  NicknameProblem.tooLong => AppStrings.nicknameTooLong,
  NicknameProblem.badCharacters => AppStrings.nicknameBadCharacters,
};

/// Asks for a nickname and joins (or renames, when already joined).
/// Resolves to true on success.
Future<bool> showNicknameSheet(
  BuildContext context,
  LeaderboardStore store,
) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NicknameSheet(store: store),
  );
  return done ?? false;
}

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet({required this.store});

  final LeaderboardStore store;

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  late final _controller = TextEditingController(
    text: widget.store.account?.nickname ?? '',
  );
  late final bool _renaming = widget.store.joined;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = tidyNickname(_controller.text);
    final problem = nicknameProblem(name);
    if (problem != null) {
      setState(() => _error = _problemText(problem));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var restored = false;
      if (_renaming) {
        await widget.store.rename(name);
      } else {
        restored = await widget.store.join(name);
      }
      if (!mounted) return;
      if (restored) {
        // A reinstalled app: this device's earlier account is back.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.leaderboardRestored(widget.store.account!.nickname),
            ),
          ),
        );
      }
      Navigator.of(context).pop(true);
    } on LeaderboardException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = leaderboardFailureText(e.failure);
        });
      }
    }
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
          Text(
            _renaming
                ? AppStrings.changeNickname
                : AppStrings.leaderboardJoinTitle,
            style: theme.textTheme.titleLarge,
          ),
          if (!_renaming) ...[
            const SizedBox(height: 8),
            Text(
              AppStrings.leaderboardJoinBody,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            maxLength: nicknameMaxLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: AppStrings.nicknameLabel,
              hintText: AppStrings.nicknameHint,
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(_renaming ? AppStrings.save : AppStrings.join),
          ),
        ],
      ),
    );
  }
}
