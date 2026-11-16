import 'dart:convert';

import 'strings.dart';

/// A quick reaction in duels and tournaments (2026-11-16): four mascot
/// faces and four fixed messages. Nothing is typed, so there is nothing to
/// moderate. The room passes it on as it is (server/leaderboard/src/
/// reactions.js, the same ids); older apps ignore the message.
enum Reaction {
  angry('angry'),
  laugh('laugh'),
  sad('sad'),
  wow('wow'),
  easy('easy'),
  close('close'),
  lucky('lucky'),
  congrats('congrats');

  const Reaction(this.id);

  /// On the wire.
  final String id;

  /// A mascot face rather than a message.
  bool get isFace => index < 4;

  /// The message, or the face's name for screen readers.
  String get label => switch (this) {
    angry => AppStrings.reactionAngry,
    laugh => AppStrings.reactionLaugh,
    sad => AppStrings.reactionSad,
    wow => AppStrings.reactionWow,
    easy => AppStrings.reactionEasy,
    close => AppStrings.reactionClose,
    lucky => AppStrings.reactionLucky,
    congrats => AppStrings.reactionCongrats,
  };

  static Reaction? fromId(Object? id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// What the app sends.
  String get message => jsonEncode({'t': 'react', 'r': id});
}

/// A reaction from another player: the seat in a duel, the player id in a
/// tournament.
typedef ReceivedReaction = ({int from, Reaction reaction});

/// [text] as a reaction from the room, or null if it is something else.
ReceivedReaction? parseReaction(String text) {
  if (!text.contains('"react"')) return null;
  try {
    final m = jsonDecode(text);
    if (m is! Map<String, dynamic> || m['t'] != 'react') return null;
    final from = m['seat'] ?? m['id'];
    final reaction = Reaction.fromId(m['r']);
    if (from is! int || reaction == null) return null;
    return (from: from, reaction: reaction);
  } on Object {
    return null;
  }
}

/// Between two reactions of this player; the room refuses sooner ones
/// (REACT_GAP_MS is 1.5 s).
const Duration reactionCooldown = Duration(seconds: 2);

/// How long a reaction stays on screen.
const Duration reactionShown = Duration(milliseconds: 2600);
