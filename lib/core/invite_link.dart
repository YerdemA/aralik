import 'duel.dart';

/// What an invite link opens.
enum InviteKind { duel, tournament }

/// A room someone was invited to with a link: https://kabaca.app/d/KOD for
/// a duel, /t/KOD for a tournament. The app opens these (an App Link, see
/// AndroidManifest.xml); without the app the site shows the code and the
/// store button (server/leaderboard/src/landing.js).
class Invite {
  const Invite(this.kind, this.code);

  final InviteKind kind;
  final String code;

  @override
  bool operator ==(Object other) =>
      other is Invite && other.kind == kind && other.code == code;

  @override
  int get hashCode => Object.hash(kind, code);

  @override
  String toString() => 'Invite($kind, $code)';
}

/// The site the links live on (also in AndroidManifest.xml and the
/// server's LANDING_HOSTS).
const String inviteHost = 'kabaca.app';

/// The link that invites to room [code].
String inviteLink(InviteKind kind, String code) =>
    'https://$inviteHost/${kind == InviteKind.duel ? 'd' : 't'}/$code';

/// The invite in [link], or null when it is not one (another page of the
/// site, a bad code, another host).
Invite? parseInvite(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'https') return null;
  if (uri.host != inviteHost && uri.host != 'www.$inviteHost') return null;
  final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (parts.length != 2) return null;
  final kind = switch (parts[0]) {
    'd' => InviteKind.duel,
    't' => InviteKind.tournament,
    _ => null,
  };
  final code = normalizeRoomCode(parts[1]);
  if (kind == null || code == null) return null;
  return Invite(kind, code);
}
