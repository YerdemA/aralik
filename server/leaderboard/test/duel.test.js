import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as duel from '../src/duel.js';
import { handle } from '../src/index.js';
import { MIN_POINTS, scoreFor } from '../src/scoring.js';

const T0 = 1_000_000;

// Ten questions, two days of schedule (ids s1…s10 are scheduled ahead).
function makeContent() {
  const questions = new Map();
  const order = [];
  const add = (id, difficulty, kind = 'magnitude', answer = 100) => {
    questions.set(id, { answer, kind, difficulty });
    order.push(id);
  };
  for (let i = 1; i <= 10; i++) add(`s${i}`, ((i - 1) % 3) + 1);
  add('e1', 1);
  add('e2', 1, 'year', 1923);
  add('e3', 1);
  add('m1', 2);
  add('m2', 2);
  add('m3', 2);
  add('h1', 3);
  add('h2', 3, 'year', 1453);
  return {
    questions,
    order,
    days: [
      ['s1', 's2', 's3', 's4', 's5'],
      ['s6', 's7', 's8', 's9', 's10'],
    ],
  };
}

const content = makeContent();
const first = () => 0;
const pick = (limit) => duel.pickDuelQuestions(content, limit, 0, first);

function started() {
  let r = duel.createRoom('ABCDE', T0);
  r = duel.join(r.state, { name: 'Ayşe', bank: 99 }, T0, pick);
  r = duel.join(r.state, { name: 'Bora', bank: 99 }, T0 + 10, pick);
  return r;
}

test('room codes use the unambiguous alphabet and normalize', () => {
  let n = 0;
  const code = duel.newRoomCode(() => n++);
  assert.equal(code, 'ABCDE');
  assert.equal(duel.normalizeRoomCode(' ab cde '), 'ABCDE');
  assert.equal(duel.normalizeRoomCode('kq2zr'), 'KQ2ZR');
  assert.equal(duel.normalizeRoomCode('kq2zi'), null); // I is not used
  assert.equal(duel.normalizeRoomCode('ABCD0'), null); // 0 is not used
  assert.equal(duel.normalizeRoomCode('ABCD'), null);
  assert.equal(duel.normalizeRoomCode(null), null);
  for (let i = 0; i < 200; i++) {
    const k = duel.randomInt(31);
    assert.ok(k >= 0 && k < 31);
  }
});

test('checks the player of a connection', () => {
  const q = (s) => new URLSearchParams(s);
  assert.deepEqual(duel.playerFrom(q('v=1&name=%20Ay%C5%9Fe%20&bank=12')), {
    name: 'Ayşe',
    bank: 12,
  });
  assert.equal(duel.playerFrom(q('v=2&name=Ayse&bank=12')).error, 'version');
  assert.equal(duel.playerFrom(q('v=1&name=A&bank=12')).error, 'invalid_name');
  assert.equal(duel.playerFrom(q('v=1&name=Ayse&bank=0')).error, 'bad_request');
  assert.equal(duel.playerFrom(q('v=1&name=Ayse')).error, 'bad_request');
});

test('picks 2 easy, 2 medium, 1 hard outside the upcoming schedule', () => {
  const ids = duel.pickDuelQuestions(content, 999, 0, first);
  assert.deepEqual(ids, ['e1', 'e2', 'm1', 'm2', 'h1']);
});

test('uses only the first bankLimit questions (both apps hold them)', () => {
  // The first 15 ids: s1…s10, e1, e2, e3, m1, m2 – no hard question left.
  const ids = duel.pickDuelQuestions(content, 15, 0, first);
  assert.deepEqual(ids, ['e1', 'e2', 'e3', 'm1', 'm2']);
  assert.equal(duel.pickDuelQuestions(content, 12, 0, first), null);
});

test('the first player waits, the second starts the duel', () => {
  let r = duel.createRoom('ABCDE', T0);
  assert.equal(r.alarm, T0 + duel.JOIN_TIMEOUT_MS);
  r = duel.join(r.state, { name: 'Ayşe', bank: 15 }, T0, pick);
  assert.equal(r.seat, 0);
  assert.deepEqual(r.out, [{ to: 0, msg: { t: 'waiting', code: 'ABCDE' } }]);
  r = duel.join(r.state, { name: 'Bora', bank: 99 }, T0 + 5, pick);
  assert.equal(r.seat, 1);
  assert.equal(r.state.phase, 'question');
  // The smaller bank decides.
  assert.deepEqual(r.state.questions, ['e1', 'e2', 'e3', 'm1', 'm2']);
  const start = r.out.find((o) => o.to === 1).msg;
  assert.deepEqual(start.names, ['Ayşe', 'Bora']);
  assert.equal(start.you, 1);
  assert.deepEqual(r.out.at(-1).msg, {
    t: 'question',
    i: 0,
    ms: duel.QUESTION_MS,
  });
  assert.equal(r.alarm, T0 + 5 + duel.QUESTION_MS + duel.LOCK_GRACE_MS);
  assert.equal(duel.join(r.state, { name: 'Can', bank: 99 }, T0, pick).error, 'room_closed');
  assert.equal(duel.join(undefined, { name: 'Can', bank: 99 }, T0, pick).error, 'no_room');
});

test('both locks reveal at once, scored by the server', () => {
  let r = started();
  r = duel.lock(r.state, 0, { i: 0, low: 50, high: 200 }, T0 + 1000, content);
  assert.deepEqual(r.out, [{ to: 'all', msg: { t: 'locked', i: 0, seat: 0 } }]);
  assert.equal(r.state.phase, 'question');
  // A second lock of the same seat is ignored.
  const again = duel.lock(r.state, 0, { i: 0, low: 1, high: 2 }, T0, content);
  assert.equal(again.state, r.state);
  r = duel.lock(r.state, 1, { i: 0, low: 300, high: 400 }, T0 + 2000, content);
  assert.equal(r.state.phase, 'reveal');
  const reveal = r.out[0].msg;
  assert.equal(reveal.t, 'reveal');
  assert.deepEqual(reveal.results[0], {
    low: 50,
    high: 200,
    points: scoreFor('magnitude', 50, 200, 100),
    hit: true,
  });
  assert.equal(reveal.results[1].hit, false);
  assert.deepEqual(reveal.totals, [reveal.results[0].points, reveal.results[1].points]);
  assert.equal(r.alarm, T0 + 2000 + duel.REVEAL_MS);
});

test('bad bounds are refused, empty locks score the floor', () => {
  let r = started();
  const bad = duel.lock(r.state, 0, { i: 0, low: 0, high: 5 }, T0, content);
  assert.equal(bad.out[0].msg.code, 'bad_lock');
  assert.equal(bad.state.locks[0], null);
  r = duel.lock(r.state, 0, { i: 0, low: null, high: null }, T0, content);
  r = duel.alarm(r.state, T0 + 10 + duel.QUESTION_MS + duel.LOCK_GRACE_MS, content);
  const results = r.out[0].msg.results;
  assert.equal(results[0].points, MIN_POINTS);
  assert.equal(results[1].points, MIN_POINTS); // never locked
  assert.equal(results[1].hit, false);
});

test('the alarm waits for the deadline', () => {
  const r = started();
  const early = duel.alarm(r.state, T0 + 1000, content);
  assert.equal(early.state.phase, 'question');
  assert.equal(early.alarm, r.alarm);
});

test('next question when both are ready or the reveal times out', () => {
  let r = started();
  r = duel.alarm(r.state, r.alarm, content); // reveal 0
  r = duel.next(r.state, 0, { i: 0 }, T0 + 20_000);
  assert.equal(r.state.phase, 'reveal');
  r = duel.next(r.state, 1, { i: 0 }, T0 + 20_100);
  assert.equal(r.state.phase, 'question');
  assert.equal(r.state.index, 1);
  r = duel.alarm(r.state, r.alarm, content); // reveal 1
  r = duel.alarm(r.state, r.alarm, content); // nobody pressed: question 2
  assert.equal(r.state.index, 2);
  assert.equal(r.state.phase, 'question');
});

test('the duel ends after the fifth reveal with a winner', () => {
  let r = started();
  for (let i = 0; i < 5; i++) {
    const exact = content.questions.get(r.state.questions[i]).answer;
    r = duel.lock(r.state, 0, { i, low: exact, high: exact }, T0, content);
    r = duel.lock(r.state, 1, { i, low: null, high: null }, T0, content);
    if (i < 4) {
      r = duel.next(r.state, 0, { i }, T0);
      r = duel.next(r.state, 1, { i }, T0);
    }
  }
  assert.equal(r.state.phase, 'over');
  const end = r.out.at(-1).msg;
  assert.equal(end.t, 'end');
  assert.equal(end.winner, 0);
  assert.equal(end.reason, 'done');
  assert.deepEqual(end.totals, [500, 5 * MIN_POINTS]);
  assert.equal(r.alarm, T0 + duel.CLEANUP_MS);
  assert.equal(duel.alarm(r.state, r.alarm, content).wipe, true);
});

test('leaving mid-duel hands the win to the other player', () => {
  const r = duel.leave(started().state, 1, T0 + 500);
  assert.equal(r.state.phase, 'over');
  assert.deepEqual(r.out[0].msg, {
    t: 'end',
    totals: [0, 0],
    winner: 0,
    reason: 'left',
  });
});

test('the creator may drop out and come back while waiting', () => {
  let r = duel.createRoom('ABCDE', T0);
  r = duel.join(r.state, { name: 'Ayşe', bank: 99 }, T0, pick);
  r = duel.leave(r.state, 0, T0 + 100);
  assert.equal(r.state.phase, 'waiting');
  assert.equal(r.state.players.length, 0);
  r = duel.join(r.state, { name: 'Ayşe', bank: 99 }, T0 + 200, pick);
  assert.equal(r.seat, 0);
  assert.equal(duel.isFree(r.state, T0), false);
  assert.equal(duel.isFree(r.state, T0 + duel.JOIN_TIMEOUT_MS), true);
  const expired = duel.alarm(r.state, T0 + duel.JOIN_TIMEOUT_MS, content);
  assert.equal(expired.wipe, true);
  assert.equal(expired.out[0].msg.code, 'expired');
});

test('the worker creates rooms and refuses bad codes', async () => {
  const created = [];
  const env = {
    DUEL_ROOMS: {
      idFromName: (name) => name,
      get: (id) => ({
        fetch: async (url) => {
          if (typeof url === 'string' && url.includes('/create')) {
            // The first code is taken, the second is free.
            created.push(id);
            return new Response(null, { status: created.length === 1 ? 409 : 201 });
          }
          return new Response('room', { status: 200 });
        },
      }),
    },
  };
  const create = await handle(
    new Request('https://lb.example/v1/duel/rooms', { method: 'POST' }),
    env,
  );
  assert.equal(create.status, 201);
  const { code } = await create.json();
  assert.equal(code, created[1]);
  assert.equal(duel.normalizeRoomCode(code), code);

  const bad = await handle(
    new Request('https://lb.example/v1/duel/rooms/0000', {
      headers: { upgrade: 'websocket' },
    }),
    env,
  );
  assert.equal(bad.status, 404);
  const plain = await handle(
    new Request('https://lb.example/v1/duel/rooms/ABCDE'),
    env,
  );
  assert.equal(plain.status, 426);
  let lobbyCalls = 0;
  env.DUEL_LOBBY = {
    idFromName: (name) => name,
    get: (id) => ({
      fetch: async () => {
        lobbyCalls++;
        assert.equal(id, 'lobby');
        return new Response('lobby', { status: 200 });
      },
    }),
  };
  const random = await handle(
    new Request('https://lb.example/v1/duel/random?v=1', {
      headers: { upgrade: 'websocket' },
    }),
    env,
  );
  assert.equal(await random.text(), 'lobby');
  const randomPlain = await handle(
    new Request('https://lb.example/v1/duel/random'),
    env,
  );
  assert.equal(randomPlain.status, 426);
  assert.equal(lobbyCalls, 1);

  const ok = await handle(
    new Request('https://lb.example/v1/duel/rooms/abcde', {
      headers: { upgrade: 'websocket' },
    }),
    env,
  );
  assert.equal(await ok.text(), 'room');
});
