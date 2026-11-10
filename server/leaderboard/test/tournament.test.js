import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as t from '../src/tournament.js';
import { pickDuelQuestions } from '../src/duel.js';
import { handle } from '../src/index.js';
import { MIN_POINTS } from '../src/scoring.js';

const T0 = 1_000_000;

// Twelve unscheduled questions of each difficulty: enough for ten.
function makeContent() {
  const questions = new Map();
  const order = [];
  for (const level of [1, 2, 3]) {
    for (let k = 1; k <= 6; k++) {
      const id = `q${level}${k}`;
      questions.set(id, { answer: 100, kind: 'magnitude', difficulty: level });
      order.push(id);
    }
  }
  return { questions, order, days: [] };
}

const content = makeContent();
const pick = (limit, levels) =>
  pickDuelQuestions(content, limit, 0, () => 0, levels);

function player(name, bank = 99) {
  return t.playerFrom(
    new URLSearchParams({ v: `${t.TOURNAMENT_VERSION}`, name, bank: `${bank}` }),
  );
}

/** A lobby with [names] in it; returns the last step and the ids. */
function lobby(...names) {
  let r = t.createRoom('ABCDE', T0);
  const ids = [];
  for (const name of names) {
    r = t.join(r.state, player(name), T0);
    ids.push(r.id);
  }
  return { r, ids };
}

function sent(r, to = 'all') {
  return r.out.filter((o) => o.to === to).map((o) => o.msg);
}

test('the first to join hosts; everyone sees the list', () => {
  const { r, ids } = lobby('Ayşe', 'Bora', 'Cem');
  assert.deepEqual(ids, [1, 2, 3]);
  assert.equal(r.state.host, 1);
  const room = sent(r).find((m) => m.t === 'room');
  assert.deepEqual(
    room.players.map((p) => p.name),
    ['Ayşe', 'Bora', 'Cem'],
  );
  assert.equal(room.host, 1);
  assert.equal(room.min, 3);
  assert.equal(room.max, 8);
  assert.deepEqual(sent(r, 3), [{ t: 'welcome', you: 3, rejoin: null }]);
});

test('joining is refused when full, taken, kicked or playing', () => {
  const { r } = lobby('A1a', 'B1b', 'C1c', 'D1d', 'E1e', 'F1f', 'G1g', 'H1h');
  assert.equal(t.join(r.state, player('Ilk'), T0).error, 'room_full');
  const small = lobby('Ayşe', 'Bora', 'Cem').r.state;
  assert.equal(t.join(small, player('ayşe'), T0).error, 'name_taken');
  assert.equal(t.join(null, player('Deniz'), T0).error, 'no_room');
  const started = t.start(small, 1, T0, pick).state;
  assert.equal(t.join(started, player('Deniz'), T0).error, 'in_progress');
});

test('only the host kicks, and a kicked name stays out', () => {
  const { r } = lobby('Ayşe', 'Bora', 'Cem');
  assert.equal(t.kick(r.state, 2, { id: 3 }, T0).state, r.state);
  assert.equal(t.kick(r.state, 1, { id: 1 }, T0).state, r.state);
  const kicked = t.kick(r.state, 1, { id: 2 }, T0);
  assert.deepEqual(kicked.close, [2]);
  assert.deepEqual(sent(kicked, 2), [{ t: 'kicked' }]);
  assert.deepEqual(
    kicked.state.players.map((p) => p.name),
    ['Ayşe', 'Cem'],
  );
  assert.equal(t.join(kicked.state, player('BORA'), T0).error, 'kicked');
});

test('the host picks 5 or 10 questions and starts with three or more', () => {
  const two = lobby('Ayşe', 'Bora').r.state;
  const early = t.start(two, 1, T0, pick);
  assert.equal(early.state.phase, 'lobby');
  assert.deepEqual(sent(early, 1), [{ t: 'error', code: 'too_few' }]);

  let state = lobby('Ayşe', 'Bora', 'Cem').r.state;
  assert.equal(t.setCount(state, 2, { n: 10 }, T0).state.count, 5);
  assert.equal(t.setCount(state, 1, { n: 7 }, T0).state.count, 5);
  state = t.setCount(state, 1, { n: 10 }, T0).state;
  assert.equal(state.count, 10);
  assert.equal(t.start(state, 2, T0, pick).state.phase, 'lobby');

  const r = t.start(state, 1, T0, pick);
  const start = sent(r).find((m) => m.t === 'start');
  assert.equal(start.questions.length, 10);
  const level = (id) => content.questions.get(id).difficulty;
  assert.deepEqual(
    start.questions.map(level),
    [1, 1, 1, 1, 2, 2, 2, 2, 3, 3],
  );
  assert.deepEqual(sent(r).at(-1), { t: 'question', i: 0, ms: 15_000 });
});

/** Everyone in [state]'s match locks question [i] with [bounds](id). */
function lockAll(state, i, bounds, now = T0) {
  let r = { state };
  for (const p of state.match.players) {
    if (p.left) continue;
    r = t.lock(r.state, p.id, { i, ...bounds(p.id) }, now, content);
  }
  return r;
}

function readyAll(state, i, now = T0) {
  let r = { state };
  for (const p of state.match.players) {
    if (!p.left) r = t.next(r.state, p.id, { i }, now);
  }
  return r;
}

test('a question opens when everyone locked; the last one ends it', () => {
  let state = t.start(lobby('Ayşe', 'Bora', 'Cem').r.state, 1, T0, pick).state;
  for (let i = 0; i < 5; i++) {
    const r = lockAll(state, i, (id) =>
      id === 1
        ? { low: 100, high: 100 }
        : id === 2
          ? { low: 50, high: 200 }
          : { low: 1, high: 2 },
    );
    if (i < 4) {
      assert.equal(r.state.phase, 'reveal');
      const reveal = sent(r).find((m) => m.t === 'reveal');
      assert.deepEqual(reveal.results.map((x) => x.hit), [true, true, false]);
      assert.equal(reveal.ms, 12_000);
      state = readyAll(r.state, i).state;
      assert.equal(state.match.index, i + 1);
    } else {
      // Back in the lobby, standings sent, ready to start again.
      assert.equal(r.state.phase, 'lobby');
      assert.equal(r.state.match, null);
      const end = sent(r).find((m) => m.t === 'end');
      assert.equal(end.questions, 5);
      assert.deepEqual(
        end.standings.map((s) => [s.name, s.points, s.hits]),
        [
          ['Ayşe', 500, 5],
          ['Bora', end.standings[1].points, 5],
          ['Cem', end.standings[2].points, 0],
        ],
      );
      assert.ok(end.standings[1].points < 500);
      assert.equal(t.start(r.state, 1, T0, pick).state.phase, 'question');
    }
  }
});

test('time running out opens the question; empty locks score the floor', () => {
  const started = t.start(lobby('Ayşe', 'Bora', 'Cem').r.state, 1, T0, pick);
  const one = t.lock(started.state, 1, { i: 0, low: 100, high: 100 }, T0, content);
  assert.equal(one.state.phase, 'question');
  assert.deepEqual(sent(one), [{ t: 'locked', i: 0, id: 1 }]);
  const early = t.alarm(one.state, T0 + 1000, content);
  assert.equal(early.state.phase, 'question');
  const late = t.alarm(one.state, T0 + 20_000, content);
  assert.equal(late.state.phase, 'reveal');
  const reveal = sent(late).find((m) => m.t === 'reveal');
  assert.deepEqual(
    reveal.results.map((x) => x.points),
    [100, MIN_POINTS, MIN_POINTS],
  );
});

test('a player who leaves mid-match stays in the standings', () => {
  let state = t.start(lobby('Ayşe', 'Bora', 'Cem').r.state, 1, T0, pick).state;
  state = t.lock(state, 1, { i: 0, low: 100, high: 100 }, T0, content).state;
  state = t.lock(state, 2, { i: 0, low: 100, high: 100 }, T0, content).state;
  // The host leaves; the question opens because the rest all locked.
  const gone = t.leave(state, 3, T0, content);
  assert.equal(gone.state.phase, 'reveal');
  state = t.leave(gone.state, 1, T0, content).state;
  assert.equal(state.host, 2);
  for (let i = 1; i < 5; i++) {
    state = readyAll(state, i - 1).state;
    state = lockAll(state, i, () => ({ low: 100, high: 100 })).state;
  }
  // Ended: the leavers are listed and gone from the lobby.
  assert.equal(state.phase, 'lobby');
  assert.deepEqual(state.players.map((p) => p.name), ['Bora']);
});

test('a dropped player comes back mid-match where it is', () => {
  let r = t.createRoom('ABCDE', T0);
  for (const [name, token] of [
    ['Ayşe', 'tA'],
    ['Bora', 'tB'],
    ['Cem', 'tC'],
  ]) {
    r = t.join(r.state, { ...player(name), token }, T0);
  }
  assert.deepEqual(sent(r, 3)[0], { t: 'welcome', you: 3, rejoin: 'tC' });
  let state = t.start(r.state, 1, T0, pick).state;
  // Cem drops; the other two play the first question without him.
  state = t.leave(state, 3, T0 + 1000, content).state;
  state = lockAll(state, 0, () => ({ low: 100, high: 100 })).state;
  assert.equal(state.phase, 'reveal');
  assert.equal(t.rejoin(state, 'nope', T0).error, 'no_room');

  const back = t.rejoin(state, 'tC', T0 + 3000);
  assert.equal(back.id, 3);
  const resume = sent(back, 3)[0];
  assert.equal(resume.t, 'resume');
  assert.equal(resume.rejoin, 'tC');
  assert.equal(resume.phase, 'reveal');
  assert.equal(resume.index, 0);
  assert.equal(resume.results.length, 1);
  assert.equal(resume.results[0].find((x) => x.id === 3).points, MIN_POINTS);
  assert.equal(resume.start.questions.length, 5);
  assert.deepEqual(
    resume.room.players.map((p) => p.name),
    ['Ayşe', 'Bora', 'Cem'],
  );
  assert.ok(!JSON.stringify(resume.room).includes('tA'));
  // He plays on and is not listed as left.
  state = readyAll(back.state, 0).state;
  for (let i = 1; i < 5; i++) {
    state = lockAll(state, i, () => ({ low: 100, high: 100 })).state;
    if (i < 4) state = readyAll(state, i).state;
  }
  assert.equal(state.phase, 'lobby');
  assert.deepEqual(state.players.map((p) => p.name), ['Ayşe', 'Bora', 'Cem']);
  // After the match the secret takes him back to his seat in the lobby;
  // one without a seat no longer works (the code does).
  assert.equal(t.rejoin(state, 'tC', T0).id, 3);
  assert.equal(t.rejoin(state, 'nope', T0).error, 'rejoin_over');
});

/** A lobby whose players have secrets: Ayşe (tA, host), Bora, Cem. */
function lobbyWithSecrets(...names) {
  let r = t.createRoom('ABCDE', T0);
  for (const name of names) {
    r = t.join(r.state, { ...player(name), token: `t${name[0]}` }, T0);
  }
  return r.state;
}

test('a player dropped in the lobby keeps their seat for a while', () => {
  let state = lobbyWithSecrets('Ayşe', 'Bora', 'Cem');
  // The host's app goes to the background.
  const gone = t.leave(state, 1, T0 + 1000);
  state = gone.state;
  assert.equal(state.host, 1);
  const room = sent(gone).find((m) => m.t === 'room');
  assert.deepEqual(room.players[0], { id: 1, name: 'Ayşe', away: true });
  assert.deepEqual(room.players[1], { id: 2, name: 'Bora' });
  assert.equal(gone.alarm, T0 + 1000 + t.AWAY_MS);
  // Back with the secret: the same seat, still the host.
  const back = t.rejoin(state, 'tA', T0 + 60_000);
  assert.equal(back.id, 1);
  assert.deepEqual(sent(back, 1)[0], { t: 'welcome', you: 1, rejoin: 'tA' });
  assert.equal(back.state.host, 1);
  assert.ok(back.state.players.every((p) => p.away == null));
  assert.ok(!JSON.stringify(sent(back)).includes('away'));
});

test('an away seat ends after AWAY_MS and the host role passes', () => {
  let state = lobbyWithSecrets('Ayşe', 'Bora', 'Cem');
  state = t.leave(state, 1, T0).state;
  const early = t.alarm(state, T0 + t.AWAY_MS - 1, content);
  assert.equal(early.state.players.length, 3);
  const late = t.alarm(state, T0 + t.AWAY_MS, content);
  assert.deepEqual(late.state.players.map((p) => p.name), ['Bora', 'Cem']);
  assert.equal(late.state.host, 2);
  assert.equal(sent(late).find((m) => m.t === 'room').host, 2);
  assert.equal(t.rejoin(late.state, 'tA', T0).error, 'rejoin_over');
  // Everyone away for good: the room closes.
  let all = lobbyWithSecrets('Ayşe');
  all = t.leave(all, 1, T0).state;
  assert.equal(t.alarm(all, T0 + t.AWAY_MS, content).wipe, true);
});

test('the same name takes an away seat back; a present one is taken', () => {
  let state = lobbyWithSecrets('Ayşe', 'Bora', 'Cem');
  assert.equal(t.join(state, player('bora'), T0).error, 'name_taken');
  state = t.leave(state, 2, T0).state;
  const again = t.join(state, { ...player('Bora'), token: 'tB2' }, T0);
  assert.equal(again.id, 2);
  assert.deepEqual(sent(again, 2)[0], { t: 'welcome', you: 2, rejoin: 'tB2' });
  assert.equal(again.state.players.length, 3);
  assert.ok(again.state.players.every((p) => p.away == null));
});

test('a match started while someone is away lists them as left', () => {
  let state = lobbyWithSecrets('Ayşe', 'Bora', 'Cem', 'Deniz');
  state = t.leave(state, 4, T0).state;
  state = t.start(state, 1, T0, pick).state;
  assert.equal(state.match.players.find((p) => p.id === 4).left, true);
  // The question opens without waiting for Deniz.
  state = lockAll(state, 0, () => ({ low: 100, high: 100 })).state;
  assert.equal(state.phase, 'reveal');
  // Deniz comes back into the match.
  const back = t.rejoin(state, 'tD', T0 + 1000);
  assert.equal(sent(back, 4)[0].t, 'resume');
  assert.equal(back.state.match.players.find((p) => p.id === 4).left, false);
});

test('a player dropped mid-match is still seated after it', () => {
  let state = lobbyWithSecrets('Ayşe', 'Bora', 'Cem');
  state = t.start(state, 1, T0, pick).state;
  state = t.leave(state, 3, T0, content).state;
  for (let i = 0; i < 5; i++) {
    const r = lockAll(state, i, () => ({ low: 100, high: 100 }));
    state = i < 4 ? readyAll(r.state, i).state : r.state;
  }
  assert.equal(state.phase, 'lobby');
  const cem = state.players.find((p) => p.id === 3);
  assert.notEqual(cem.away, null);
  assert.equal(t.rejoin(state, 'tC', T0 + 2000).id, 3);
});

test('standings never carry the secrets', () => {
  let r = t.createRoom('ABCDE', T0);
  for (const [name, token] of [
    ['Ayşe', 'tA'],
    ['Bora', 'tB'],
    ['Cem', 'tC'],
  ]) {
    r = t.join(r.state, { ...player(name), token }, T0);
  }
  let state = t.start(r.state, 1, T0, pick).state;
  let last;
  for (let i = 0; i < 5; i++) {
    last = lockAll(state, i, () => ({ low: 100, high: 100 }));
    state = i < 4 ? readyAll(last.state, i).state : last.state;
  }
  const text = JSON.stringify(last.out);
  for (const token of ['tA', 'tB', 'tC']) assert.ok(!text.includes(token));
});

test('the room closes when its last player leaves or the lobby idles', () => {
  const { r } = lobby('Ayşe');
  assert.equal(t.leave(r.state, 1, T0).wipe, true);
  const idle = t.alarm(r.state, T0 + t.LOBBY_IDLE_MS, content);
  assert.equal(idle.wipe, true);
  assert.equal(t.alarm(r.state, T0 + 1000, content).wipe, undefined);
  assert.equal(t.isFree(r.state, T0), false);
  assert.equal(t.isFree(t.createRoom('X', T0).state, T0 + 11 * 60_000), true);
});

test('rooms are checked for dead connections in a match or a lobby', () => {
  const every = { play: 4, idle: 15 };
  assert.equal(t.watchEvery(null, every), null);
  const empty = t.createRoom('ABCDE', 0).state;
  assert.equal(t.watchEvery(empty, every), null);
  assert.equal(
    t.watchEvery({ ...empty, players: [{ id: 1 }] }, every),
    15,
  );
  assert.equal(
    t.watchEvery({ ...empty, phase: 'question' }, every),
    4,
  );
});

test('the worker routes tournament rooms', async () => {
  const created = [];
  const env = {
    TOURNAMENT_ROOMS: {
      idFromName: (code) => code,
      get: (code) => ({
        fetch: async () => {
          created.push(code);
          return new Response(null, { status: 201 });
        },
      }),
    },
  };
  const r = await handle(
    new Request('https://lb.example/v1/tournament/rooms', { method: 'POST' }),
    env,
  );
  assert.equal(r.status, 201);
  const { code } = await r.json();
  assert.deepEqual(created, [code]);
  const plain = await handle(
    new Request(`https://lb.example/v1/tournament/rooms/${code}`),
    env,
  );
  assert.equal(plain.status, 426);
});
