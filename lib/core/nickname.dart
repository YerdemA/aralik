// Leaderboard nickname rules (pure). The server applies the same rules
// (server/leaderboard/src/nickname.js) and also filters words; this copy
// only gives instant feedback while typing.

const int nicknameMinLength = 3;
const int nicknameMaxLength = 16;

final _format = RegExp(
  r'^[\p{L}\p{N}](?:[\p{L}\p{N}._-]| (?! ))*$',
  unicode: true,
);
final _letter = RegExp(r'\p{L}', unicode: true);

enum NicknameProblem { tooShort, tooLong, badCharacters }

/// Trimmed nickname with single spaces.
String tidyNickname(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// What is wrong with [raw] (after [tidyNickname]), or null if it is fine.
/// Letters (any alphabet), digits and `. _ -` and single spaces; starts
/// with a letter or digit and has at least one letter.
NicknameProblem? nicknameProblem(String raw) {
  final name = tidyNickname(raw);
  final length = name.runes.length;
  if (length < nicknameMinLength) return NicknameProblem.tooShort;
  if (length > nicknameMaxLength) return NicknameProblem.tooLong;
  if (!_format.hasMatch(name) || !_letter.hasMatch(name)) {
    return NicknameProblem.badCharacters;
  }
  return null;
}

/// How often the player's one name may change: the same everywhere
/// (leaderboard, duel, tournament) and the server's `RENAME_DAYS`.
const nameChangeEvery = Duration(days: 3);

/// When a name last changed at [changedAt] may change again, or null when
/// it may change now. The first choice of a name is not a change.
DateTime? nextNameChange(DateTime? changedAt, DateTime now) {
  if (changedAt == null) return null;
  final at = changedAt.add(nameChangeEvery);
  return now.isBefore(at) ? at : null;
}
