import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cleanNickname, isBlocked, nicknameKey } from '../src/nickname.js';

test('cleans and accepts good nicknames', () => {
  assert.equal(cleanNickname('  Şeyma  '), 'Şeyma');
  assert.equal(cleanNickname('Ali  Veli'), 'Ali Veli');
  assert.equal(cleanNickname('kaplan_34'), 'kaplan_34');
  assert.equal(cleanNickname('İğdır.Çiçek'), 'İğdır.Çiçek');
});

test('rejects bad formats and lengths', () => {
  for (const bad of ['ab', 'a'.repeat(17), '_ali', 'ali!', '1234', '', null, 42, 'a😀b']) {
    assert.equal(cleanNickname(bad), null, String(bad));
  }
  assert.equal(cleanNickname('a'.repeat(16)), 'a'.repeat(16));
});

test('keys fold Turkish case, accents and separators', () => {
  assert.equal(nicknameKey('ŞEYMA'), 'seyma');
  assert.equal(nicknameKey('S.e.y-m_a'), 'seyma');
  assert.equal(nicknameKey('IŞIK'), 'isik');
  assert.equal(nicknameKey('İnci'), 'inci');
  assert.equal(nicknameKey('Gül Öz'), 'guloz');
});

test('blocks words, also when disguised', () => {
  assert.ok(isBlocked(nicknameKey('S.i.k.t.i.r')));
  assert.ok(isBlocked(nicknameKey('AMK')));
  assert.ok(isBlocked(nicknameKey('Kabaca')));
  assert.ok(!isBlocked(nicknameKey('Sıkıcı Kedi')));
  assert.ok(!isBlocked(nicknameKey('Gotham')));
  assert.ok(!isBlocked(nicknameKey('Picasso')));
});
