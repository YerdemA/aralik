import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createD1 } from './d1.js';
import { handle } from '../src/index.js';
import * as archive from '../src/archive.js';

// 2026-11-11 12:00 in Turkey: day 10, November.
const NOW = Date.UTC(2026, 10, 11, 9);

function seed() {
  const db = createD1();
  const player = db.raw.prepare(
    'INSERT INTO players (id, token_hash, nickname, nickname_key, created_at, hidden) VALUES (?, ?, ?, ?, 0, ?)',
  );
  player.run('a', 'x', 'Aslan', 'aslan', 0);
  player.run('b', 'x', 'Bora', 'bora', 0);
  player.run('h', 'x', 'Gizli', 'gizli', 1);
  const score = db.raw.prepare(
    'INSERT INTO scores (day, player_id, points, hits, submitted_at, look) VALUES (?, ?, ?, ?, ?, ?)',
  );
  score.run(9, 'a', 300, 4, 5, '111111111');
  score.run(9, 'b', 300, 4, 2, null); // same points, earlier: leads
  score.run(8, 'h', 500, 5, 1, null); // hidden: the next one leads
  score.run(8, 'a', 200, 3, 1, null);
  score.run(10, 'a', 480, 5, 1, null); // today: not finished
  score.run(2, 'b', 400, 5, 1, null); // more than a week ago
  const rating = db.raw.prepare(
    "INSERT INTO duel_ratings (month, mode, player_id, rating, played, won, drawn, points, hits, answered, look, updated_at) VALUES (?, ?, ?, ?, 1, 1, 0, 300, 3, 5, ?, ?)",
  );
  rating.run(202610, 'bank', 'a', 40, '011100000', 1);
  rating.run(202610, 'bank', 'b', 60, '100000000', 2);
  rating.run(202610, 'bank', 'h', 90, null, 3);
  rating.run(202610, 'math', 'b', 10, null, 4);
  rating.run(202611, 'bank', 'a', 99, '022200000', 9);
  return db;
}

test('the last week of day leaders, newest first, hidden left out', async () => {
  const leaders = await archive.dayLeaders(seed(), 10);
  assert.deepEqual(leaders, [
    // Bora sent no mascot: their latest duel one stands in.
    { day: 9, nickname: 'Bora', points: 300, look: '100000000' },
    // Aslan's latest duel mascot is this month's.
    { day: 8, nickname: 'Aslan', points: 200, look: '022200000' },
  ]);
  assert.deepEqual(await archive.dayLeaders(seed(), 0), []);
});

test('GET /v1/archive: day leaders and last month podiums', async () => {
  const r = await handle(new Request('https://lb.example/v1/archive'), { DB: seed() }, NOW);
  assert.equal(r.status, 200);
  const body = await r.json();
  assert.equal(body.month, 202610);
  assert.deepEqual(body.days.map((d) => d.day), [9, 8]);
  assert.deepEqual(body.duels.bank, [
    { rank: 1, nickname: 'Bora', rating: 60, look: '100000000' },
    { rank: 2, nickname: 'Aslan', rating: 40, look: '011100000' },
  ]);
  assert.deepEqual(body.duels.math.map((d) => d.nickname), ['Bora']);
});
