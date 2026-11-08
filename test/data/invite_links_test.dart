import 'package:aralik/core/invite_link.dart';
import 'package:aralik/data/invite_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an invite link waits until taken, other links are ignored', () {
    final links = InviteLinks.instance;
    var told = 0;
    void listener() => told++;
    links.addListener(listener);
    addTearDown(() => links.removeListener(listener));

    links.receive('https://kabaca.app/');
    links.receive(null);
    expect(links.pending, isNull);
    expect(told, 0);

    links.receive('https://kabaca.app/t/K7M3P');
    expect(told, 1);
    expect(links.take(), const Invite(InviteKind.tournament, 'K7M3P'));
    expect(links.take(), isNull);
  });
}
