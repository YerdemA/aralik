import assert from 'node:assert/strict';
import test from 'node:test';

import { cleanUp, handle } from '../src/index.js';
import * as duel from '../src/duel.js';
import * as ranked from '../src/ranked.js';
import { createD1 } from './d1.js';

// 2026-11-10, noon in Turkey.
const NOW = Date.UTC(2026, 10, 10, 9);

test('months in Turkey time', () => {
  assert.equal(ranked.monthOf(NOW), 202611);
  // 30 Nov 22:30 UTC is already 1 December in Turkey.
  assert.equal(ranked.monthOf(Date.UTC(2026, 10, 30, 22, 30)), 202612);
  assert.equal(ranked.previousMonth(202611), 202610);
  assert.equal(ranked.previousMonth(202701), 202612);
  assert.equal(ranked.parseMonth('202611'), 202611);
  assert.equal(ranked.parseMonth('202613'), null);
  assert.equal(ranked.parseMonth('abc'), null);
});

test('equal players: the winner gains what the loser loses', () => {
  const [a, b] = ranked.rate([1000, 1000], 0, [300, 250]);
  assert.ok(a > 1000);
  assert.equal(a - 1000, 1000 - b);
});

test('a crushing win moves more than a narrow one', () => {
  const narrow = ranked.rate([1000, 1000], 0, [300, 290])[0] - 1000;
  const wide = ranked.rate([1000, 1000], 0, [450, 50])[0] - 1000;
  assert.ok(wide > narrow * 3, `${wide} vs ${narrow}`);
  // At most MARGIN_MAX times the plain change (16 at equal ratings).
  assert.equal(wide, Math.round(ranked.K * ranked.MARGIN_MAX * 0.5));
  assert.equal(narrow, Math.round(ranked.K * 0.55 * 0.5));
});

test('the favourite gains little; an upset gains a lot', () => {
  const favourite = ranked.rate([1400, 1000], 0, [400, 200])[0] - 1400;
  const upset = ranked.rate([1000, 1400], 0, [400, 200])[0] - 1000;
  assert.ok(upset > favourite * 5, `${upset} vs ${favourite}`);
});

test('a draw pulls the ratings together; a forfeit counts plain', () => {
  const [a, b] = ranked.rate([1200, 1000], null, [200, 200]);
  assert.ok(a < 1200 && b > 1000);
  const forfeit = ranked.rate([1000, 1000], 1, [400, 0], true);
  assert.deepEqual(forfeit, [984, 1016]);
});

test('ratings never go below the floor', () => {
  // A 32-point loss from 5 stops at 0; the winner still gains 32.
  assert.deepEqual(ranked.rate([5, 5], 1, [0, 500]), [ranked.FLOOR, 37]);
});

/** A finished first round between [pids]. */
function over(pids, { totals = [320, 180], winner = 0, reason = 'done', round = 1 } = {}) {
  return {
    ranked: true,
    mode: 'bank',
    phase: 'over',
    round,
    players: pids.map((pid, i) => ({ name: `P${i}`, pid, look: i ? null : '011100000' })),
    results: [
      [{ points: 80, hit: true }, { points: 40, hit: true }],
      [{ points: 90, hit: true }, { points: -50, hit: false }],
    ],
    totals,
    winner,
    reason,
  };
}

test('what counts: ranked room, first round, two different accounts', () => {
  assert.equal(ranked.counts(over(['a', 'b'])), true);
  assert.equal(ranked.counts({ ...over(['a', 'b']), ranked: false }), false);
  assert.equal(ranked.counts(over(['a', 'b'], { round: 2 })), false);
  assert.equal(ranked.counts(over(['a', null])), false);
  assert.equal(ranked.counts(over(['a', 'a'])), false);
  assert.equal(ranked.counts({ ...over(['a', 'b']), rated: true }), false);
  assert.equal(ranked.counts({ ...over(['a', 'b']), phase: 'reveal' }), false);
  assert.deepEqual(ranked.matchLines(over(['a', 'b'])), [
    { points: 320, hits: 2, answered: 2 },
    { points: 180, hits: 1, answered: 2 },
  ]);
});

test('start says ranked only when both accounts are known', () => {
  const pick = () => ['q1', 'q2', 'q3', 'q4', 'q5'];
  let r = duel.createRoom('ABCDE', NOW, 'bank', true);
  r = duel.join(r.state, { name: 'Ayşe', bank: 9, pid: 'a' }, NOW, pick);
  r = duel.join(r.state, { name: 'Bora', bank: 9, pid: 'b' }, NOW, pick);
  assert.equal(r.out.find((o) => o.msg.t === 'start').msg.ranked, true);
  let f = duel.createRoom('ABCDE', NOW, 'bank', true);
  f = duel.join(f.state, { name: 'Ayşe', bank: 9, pid: 'a' }, NOW, pick);
  f = duel.join(f.state, { name: 'Bora', bank: 9 }, NOW, pick);
  assert.equal(f.out.find((o) => o.msg.t === 'start').msg.ranked, undefined);
});

async function withPlayers(...ids) {
  const db = createD1();
  for (const id of ids) {
    db.raw
      .prepare(
        'INSERT INTO players (id, token_hash, nickname, nickname_key, created_at) VALUES (?, ?, ?, ?, ?)',
      )
      .run(id, 'x', id.toUpperCase(), id, 0);
  }
  return db;
}

test('records both sides and builds the month table', async () => {
  const db = await withPlayers('a', 'b', 'c');
  const first = await ranked.record(db, over(['a', 'b']), NOW);
  assert.equal(first[0].before, 1000);
  assert.ok(first[0].after > 1000 && first[1].after < 1000);
  await ranked.record(db, over(['c', 'b'], { winner: null, totals: [200, 200] }), NOW + 1);
  const t = await ranked.table(db, 202611, 'bank', 'b', 50);
  assert.equal(t.players, 3);
  assert.deepEqual(t.top.map((r) => r.nickname), ['A', 'C', 'B']);
  assert.equal(t.top[0].played, 1);
  assert.equal(t.top[0].won, 1);
  assert.equal(t.top[0].average, 320);
  assert.equal(t.top[0].hitRate, 100);
  assert.equal(t.top[0].look, '011100000');
  assert.equal(t.me.rank, 3);
  assert.equal(t.me.played, 2);
  assert.equal(t.me.drawn, 1);
  assert.equal(t.me.average, 190);
  assert.equal(t.me.hitRate, 50);
  // Math has its own table.
  assert.equal((await ranked.table(db, 202611, 'math', null, 50)).players, 0);
});

test('a hidden player sees their place; others do not see them', async () => {
  const db = await withPlayers('a', 'b');
  await ranked.record(db, over(['a', 'b']), NOW);
  db.raw.prepare("UPDATE players SET hidden = 1 WHERE id = 'a'").run();
  const t = await ranked.table(db, 202611, 'bank', 'a', 50);
  assert.deepEqual(t.top.map((r) => r.nickname), ['B']);
  assert.equal(t.me.rank, 1);
});

test('the account is checked against its token', async () => {
  const db = createD1();
  const env = { DB: db };
  const reg = await handle(
    new Request('https://lb.example/v1/register', {
      method: 'POST',
      headers: { 'cf-connecting-ip': '1.1.1.1' },
      body: JSON.stringify({ nickname: 'Ayşe' }),
    }),
    env,
    NOW,
  );
  const { id, token } = await reg.json();
  const q = (s) => new URLSearchParams(s);
  assert.equal(await ranked.accountOf(db, q(`pid=${id}&ptok=${token}`)), id);
  assert.equal(await ranked.accountOf(db, q(`pid=${id}&ptok=wrong`)), null);
  assert.equal(await ranked.accountOf(db, q('')), null);
  assert.equal(await ranked.accountOf(null, q(`pid=${id}&ptok=${token}`)), null);
});

test('GET /v1/duel/ranked serves this month and the last; delete wipes', async () => {
  const db = await withPlayers('a', 'b');
  const env = { DB: db };
  await ranked.record(db, over(['a', 'b']), NOW);
  const get = async (path, now = NOW) => {
    const r = await handle(new Request(`https://lb.example${path}`), env, now);
    return { status: r.status, body: await r.json() };
  };
  const now = await get('/v1/duel/ranked?player=b');
  assert.equal(now.status, 200);
  assert.equal(now.body.month, 202611);
  assert.equal(now.body.current, 202611);
  assert.equal(now.body.me.rank, 2);
  // In December, November is still readable; October is not.
  const dec = Date.UTC(2026, 11, 2, 9);
  const last = await get('/v1/duel/ranked?month=202611', dec);
  assert.equal(last.body.players, 2);
  assert.equal(last.body.current, 202612);
  assert.equal((await get('/v1/duel/ranked?month=202610', dec)).status, 404);
  assert.equal((await get('/v1/duel/ranked', dec)).body.players, 0);
  // January: November is gone after the clean-up.
  await cleanUp({ DB: db }, Date.UTC(2027, 0, 2, 9));
  const left = db.raw.prepare('SELECT COUNT(*) AS n FROM duel_ratings').get();
  assert.equal(left.n, 0);
});
