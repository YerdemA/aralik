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
