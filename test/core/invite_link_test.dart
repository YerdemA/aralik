import 'package:aralik/core/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('links for both kinds', () {
    expect(inviteLink(InviteKind.duel, 'AB2CD'), 'https://kabaca.app/d/AB2CD');
    expect(
      inviteLink(InviteKind.tournament, 'XY9ZW'),
      'https://kabaca.app/t/XY9ZW',
    );
  });

  test('a link reads back as its invite', () {
    for (final kind in InviteKind.values) {
      expect(parseInvite(inviteLink(kind, 'K7M3P')), Invite(kind, 'K7M3P'));
    }
  });

  test('lower case, www and a trailing slash are fine', () {
    expect(
      parseInvite('https://www.kabaca.app/d/k7m3p/'),
      const Invite(InviteKind.duel, 'K7M3P'),
    );
    expect(
      parseInvite('https://kabaca.app/t/K7M3P?x=1'),
      const Invite(InviteKind.tournament, 'K7M3P'),
    );
  });

  test('anything else is not an invite', () {
    for (final link in [
      '',
      'kabaca.app/d/K7M3P',
      'http://kabaca.app/d/K7M3P',
      'https://example.com/d/K7M3P',
      'https://api.kabaca.app/d/K7M3P',
      'https://kabaca.app/',
      'https://kabaca.app/x/K7M3P',
      'https://kabaca.app/d/K7M3',
      'https://kabaca.app/d/K7M3PP',
      'https://kabaca.app/d/K7MOP', // O is not in the code alphabet
      'https://kabaca.app/d/K7M3P/more',
    ]) {
      expect(parseInvite(link), isNull, reason: link);
    }
  });
}
