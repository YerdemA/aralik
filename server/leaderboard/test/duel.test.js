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
    rematch: false,
    math: false,
  });
  assert.equal(duel.playerFrom(q('v=1&name=Ayse&bank=12&math=1')).math, true);
  assert.equal(duel.playerFrom(q('v=1&name=Ayse&bank=12&rm=1')).rematch, true);
  assert.equal(duel.playerFrom(q('v=2&name=Ayse&bank=12')).error, 'version');
  assert.equal(duel.playerFrom(q('v=1&name=A&bank=12')).error, 'invalid_name');
  assert.equal(duel.playerFrom(q('v=1&name=Ayse&bank=0')).error, 'bad_request');
  assert.equal(duel.playerFrom(q('v=1&name=Ayse')).error, 'bad_request');
});

test('picks 2 easy, 2 medium, 1 hard outside the upcoming schedule', () => {
  const ids = duel.pickDuelQuestions(content, 999, 0, first);
  assert.deepEqual(ids, ['e1', 'e2', 'm1', 'm2', 'h1']);
});

test('never picks a retired question', () => {
  const withRetired = makeContent();
  withRetired.questions.get('e1').retired = true;
  const ids = duel.pickDuelQuestions(withRetired, 999, 0, first);
  assert.deepEqual(ids, ['e2', 'e3', 'm1', 'm2', 'h1']);
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
  assert.equal(reveal.ms, duel.REVEAL_MS); // the app counts it down
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

/** A started duel whose players carry rejoin secrets. */
function startedWithTokens() {
  let r = duel.createRoom('ABCDE', T0);
  r = duel.join(r.state, { name: 'Ayşe', bank: 99, token: 'tA' }, T0, pick);
  r = duel.join(r.state, { name: 'Bora', bank: 99, token: 'tB' }, T0 + 10, pick);
  return r;
}

test('each player gets a secret to come back with', () => {
  const r = startedWithTokens();
  const starts = r.out.filter((o) => o.msg.t === 'start');
  assert.deepEqual(
    starts.map((o) => [o.to, o.msg.rejoin]),
    [
      [0, 'tA'],
      [1, 'tB'],
    ],
  );
});

test('a drop does not stop the open question; out of time away, they lose', () => {
  const r = duel.leave(startedWithTokens().state, 1, T0 + 5_010);
  assert.equal(r.state.phase, 'question');
  // The question runs on for both.
  assert.equal(r.state.deadline, T0 + 10 + duel.QUESTION_MS);
  assert.equal(r.state.paused, null);
  assert.deepEqual(r.out, [
    { to: 0, msg: { t: 'away', seat: 1, ms: duel.AWAY_BUDGET_MS } },
  ]);
  assert.equal(r.alarm, r.state.deadline + duel.LOCK_GRACE_MS);
  // The other one answers; time runs out for the one away: the floor.
  let q = duel.lock(r.state, 0, { i: 0, low: 90, high: 110 }, T0 + 6_000, content);
  q = duel.alarm(q.state, q.alarm, content);
  assert.equal(q.state.phase, 'reveal');
  assert.equal(q.state.results[0][1].points, MIN_POINTS);
  // The reveal waits for them: no next question while they are away.
  assert.equal(q.state.deadline, null);
  assert.equal(q.state.paused.ms, duel.REVEAL_MS);
  q = duel.next(q.state, 0, { i: 0 }, T0 + 17_000);
  assert.equal(q.state.phase, 'reveal');
  assert.equal(q.alarm, T0 + 5_010 + duel.AWAY_BUDGET_MS);
  const over = duel.alarm(q.state, q.alarm, content);
  assert.equal(over.state.phase, 'over');
  assert.equal(over.out[0].msg.winner, 0);
  assert.equal(over.out[0].msg.reason, 'left');
  // Coming back afterwards shows how it ended.
  const late = duel.rejoin(over.state, 'tB', q.alarm + 5);
  assert.equal(late.seat, 1);
  assert.equal(late.out[0].msg.t, 'end');
});

test('back during the question: only the seconds left on it', () => {
  let r = startedWithTokens();
  r = duel.lock(r.state, 0, { i: 0, low: 90, high: 110 }, T0 + 2_000, content);
  r = duel.leave(r.state, 1, T0 + 5_010);
  const t1 = T0 + 9_010; // 4 s away
  const back = duel.rejoin(r.state, 'tB', t1);
  assert.equal(back.seat, 1);
  assert.equal(back.state.deadline, T0 + 10 + duel.QUESTION_MS);
  assert.equal(back.state.budget[1], duel.AWAY_BUDGET_MS - 4_000);
  const resume = back.out.find((o) => o.to === 1).msg;
  assert.equal(resume.t, 'resume');
  assert.equal(resume.phase, 'question');
  assert.equal(resume.ms, duel.QUESTION_MS - 9_000);
  assert.deepEqual(resume.locked, [true, false]);
  assert.equal(resume.budget, duel.AWAY_BUDGET_MS - 4_000);
  assert.deepEqual(back.out.find((o) => o.to === 0).msg, {
    t: 'back',
    seat: 1,
    ms: duel.QUESTION_MS - 9_000,
  });
  const done = duel.lock(back.state, 1, { i: 0, low: 1, high: 2 }, t1, content);
  assert.equal(done.state.phase, 'reveal');
});

test('dropping out to look an answer up gains no time', () => {
  let r = startedWithTokens();
  r = duel.leave(r.state, 1, T0 + 2_000);
  // Back 30 s later: the question's time is long gone, a lock is ignored.
  const back = duel.rejoin(r.state, 'tB', T0 + 32_000);
  assert.equal(back.state.phase, 'question');
  const late = duel.lock(back.state, 1, { i: 0, low: 99, high: 101 }, T0 + 32_100, content);
  assert.equal(late.state.locks[1], null);
  const revealed = duel.alarm(late.state, T0 + 32_200, content);
  assert.equal(revealed.state.phase, 'reveal');
  assert.equal(revealed.state.results[0][1].points, MIN_POINTS);
});

test('time away adds up over the whole duel', () => {
  let r = startedWithTokens();
  r = duel.leave(r.state, 1, T0 + 1_000);
  r = duel.rejoin(r.state, 'tB', T0 + 31_000); // 30 s away
  assert.equal(r.state.budget[1], duel.AWAY_BUDGET_MS - 30_000);
  r = duel.leave(r.state, 1, T0 + 40_000);
  assert.equal(r.out[0].msg.ms, duel.AWAY_BUDGET_MS - 30_000);
  assert.equal(r.state.away[1].until, T0 + 40_000 + duel.AWAY_BUDGET_MS - 30_000);
  r = duel.rejoin(r.state, 'tB', T0 + 50_000); // 10 s more
  assert.equal(r.state.budget[1], duel.AWAY_BUDGET_MS - 40_000);
  // Noticed late, with less left than that: over at once.
  const gone = duel.leave(r.state, 1, T0 + 70_000, T0 + 60_000);
  assert.equal(gone.state.phase, 'over');
  assert.equal(gone.state.winner, 0);
});

test('a wrong secret is refused; both out of time away wipes the room', () => {
  const r = startedWithTokens();
  assert.equal(duel.rejoin(r.state, 'nope', T0).error, 'no_room');
  assert.equal(duel.rejoin(r.state, '', T0).error, 'no_room');
  let gone = duel.leave(r.state, 0, T0 + 100);
  gone = duel.leave(gone.state, 1, T0 + 200);
  // Both gone: the question still times out and its reveal waits.
  gone = duel.alarm(gone.state, gone.alarm, content);
  assert.equal(gone.state.phase, 'reveal');
  assert.equal(gone.alarm, T0 + 100 + duel.AWAY_BUDGET_MS);
  const later = T0 + 200 + duel.AWAY_BUDGET_MS;
  assert.equal(duel.alarm(gone.state, later, content).wipe, true);
});

test('a reveal waits until they are back, then goes on', () => {
  let r = startedWithTokens();
  r = duel.lock(r.state, 1, { i: 0, low: 90, high: 110 }, T0 + 1_000, content);
  r = duel.lock(r.state, 0, { i: 0, low: 90, high: 110 }, T0 + 2_000, content);
  assert.equal(r.state.phase, 'reveal');
  r = duel.leave(r.state, 1, T0 + 5_000);
  assert.equal(r.state.paused.ms, duel.REVEAL_MS - 3_000);
  assert.equal(r.alarm, T0 + 5_000 + duel.AWAY_BUDGET_MS);
  // Both said "devam": the next question still waits for them.
  r = duel.next(r.state, 0, { i: 0 }, T0 + 6_000);
  r = duel.next(r.state, 1, { i: 0 }, T0 + 6_000);
  assert.equal(r.state.phase, 'reveal');
  const back = duel.rejoin(r.state, 'tB', T0 + 10_000);
  assert.equal(back.state.phase, 'question');
  assert.equal(back.state.index, 1);
});

test('a reveal stopped by a drop runs again on coming back', () => {
  let r = startedWithTokens();
  r = duel.lock(r.state, 1, { i: 0, low: 90, high: 110 }, T0 + 1_000, content);
  r = duel.lock(r.state, 0, { i: 0, low: 90, high: 110 }, T0 + 2_000, content);
  r = duel.leave(r.state, 1, T0 + 5_000);
  const back = duel.rejoin(r.state, 'tB', T0 + 10_000);
  assert.equal(back.state.deadline, T0 + 10_000 + duel.REVEAL_MS - 3_000);
  const resume = back.out.find((o) => o.to === 1).msg;
  assert.equal(resume.phase, 'reveal');
  assert.equal(resume.results.length, 1);
});

test('a silent connection noticed late counts its time away from then', () => {
  const r = duel.leave(startedWithTokens().state, 1, T0 + 12_000, T0 + 2_010);
  assert.equal(r.state.away[1].since, T0 + 2_010);
  assert.equal(r.out[0].msg.ms, duel.AWAY_BUDGET_MS - 9_990);
});

test('giving up ends the duel at once; the other one wins', () => {
  let r = startedWithTokens();
  r = duel.resign(r.state, 0, T0 + 3_000);
  assert.equal(r.state.phase, 'over');
  assert.deepEqual(r.out[0].msg, {
    t: 'end',
    totals: [0, 0],
    winner: 1,
    reason: 'left',
  });
  // Twice changes nothing.
  assert.equal(duel.resign(r.state, 1, T0 + 4_000).out.length, 0);
});

test('a player who closed the app may give up with their secret', () => {
  let r = startedWithTokens();
  r = duel.leave(r.state, 1, T0 + 2_000);
  const gone = duel.resignWith(r.state, 'tB', T0 + 20_000);
  assert.equal(gone.seat, 1);
  assert.equal(gone.state.phase, 'over');
  assert.equal(gone.state.winner, 0);
  assert.equal(gone.out[0].to, 'all');
  assert.equal(duel.resignWith(r.state, 'nope', T0).error, 'no_room');
  // Already over: only told how it ended.
  const late = duel.resignWith(gone.state, 'tB', T0 + 21_000);
  assert.equal(late.seat, 1);
  assert.deepEqual(
    late.out.map((o) => [o.to, o.msg.t]),
    [[1, 'end']],
  );
});

test('rooms are checked for dead connections while in play', () => {
  const every = { play: 4, idle: 15 };
  assert.equal(duel.watchEvery(null, every), null);
  assert.equal(duel.watchEvery(duel.createRoom('ABCDE', T0).state, every), 15);
  assert.equal(duel.watchEvery(startedWithTokens().state, every), 4);
  const over = duel.resign(startedWithTokens().state, 0, T0);
  assert.equal(duel.watchEvery(over.state, every), null);
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

/** A duel played to the end; [rematch] whether each app knows rematches. */
function finished(rematch = [true, true]) {
  let r = duel.createRoom('ABCDE', T0);
  r = duel.join(r.state, { name: 'Ayşe', bank: 99, token: 'tA', rematch: rematch[0] }, T0, pick);
  r = duel.join(r.state, { name: 'Bora', bank: 99, token: 'tB', rematch: rematch[1] }, T0, pick);
  for (let i = 0; i < 5; i++) {
    const exact = content.questions.get(r.state.questions[i]).answer;
    r = duel.lock(r.state, 0, { i, low: exact, high: exact }, T0, content);
    r = duel.lock(r.state, 1, { i, low: null, high: null }, T0, content);
    if (i < 4) {
      r = duel.next(r.state, 0, { i }, T0);
      r = duel.next(r.state, 1, { i }, T0);
    }
  }
  return r;
}

// Any five questions this room has not asked yet.
const pickAgain = (limit, exclude) =>
  content.order.filter((id) => !exclude.has(id)).slice(0, 5);
let tokens = 0;
const newToken = () => `n${++tokens}`;

test('a rematch is offered only between apps that know it', () => {
  const both = finished();
  assert.equal(both.out.at(-1).msg.rematch, true);
  const old = finished([true, false]);
  assert.equal(old.out.at(-1).msg.rematch, undefined);
  // Nothing happens when asked anyway.
  const asked = duel.rematch(old.state, 0, T0, pickAgain, newToken);
  assert.deepEqual(asked.out, []);
});

test('one asks, the other is told; both want it and the room starts again', () => {
  const end = finished();
  const before = end.state.questions;
  const now = T0 + 50_000; // the room would be wiped at T0 + 60 s
  let r = duel.rematch(end.state, 1, now, pickAgain, newToken);
  assert.deepEqual(r.out, [{ to: 0, msg: { t: 'rematch', seat: 1 } }]);
  assert.equal(r.alarm, now + duel.REMATCH_ANSWER_MS); // time to answer
  // Asking twice changes nothing.
  assert.deepEqual(duel.rematch(r.state, 1, now, pickAgain, newToken).out, []);
  r = duel.rematch(r.state, 0, now + 1000, pickAgain, newToken);
  const starts = r.out.filter((o) => o.msg.t === 'start');
  assert.equal(starts.length, 2);
  assert.equal(starts[0].msg.round, 2);
  assert.notDeepEqual(starts[0].msg.questions, before);
  for (const id of starts[0].msg.questions) assert.ok(!before.includes(id));
  // New secrets: the old ones no longer bring anyone back.
  assert.notEqual(starts[0].msg.rejoin, 'tA');
  assert.notEqual(starts[0].msg.rejoin, starts[1].msg.rejoin);
  assert.equal(r.out.at(-1).msg.t, 'question');
  assert.equal(r.state.phase, 'question');
  assert.deepEqual(r.state.totals, [0, 0]);
  assert.deepEqual(r.state.results, []);
  assert.deepEqual(r.state.budget, [duel.AWAY_BUDGET_MS, duel.AWAY_BUDGET_MS]);
  assert.deepEqual(r.state.played, before);
});

test('saying no, leaving or running out of time ends the offer', () => {
  const end = finished();
  const no = duel.declineRematch(end.state, 0);
  assert.deepEqual(no.out, [
    { to: 1, msg: { t: 'rematch_no', seat: 0, reason: 'no' } },
  ]);
  assert.deepEqual(duel.rematch(no.state, 1, T0, pickAgain, newToken).out, []);

  const gone = duel.leave(end.state, 1, T0 + 5000);
  assert.deepEqual(gone.out, [
    { to: 0, msg: { t: 'rematch_no', seat: 1, reason: 'left' } },
  ]);

  const asked = duel.rematch(end.state, 0, T0 + 1000, pickAgain, newToken);
  const early = duel.alarm(asked.state, T0 + duel.CLEANUP_MS - 1, content);
  assert.equal(early.wipe, undefined);
  const late = duel.alarm(asked.state, T0 + duel.CLEANUP_MS, content);
  assert.equal(late.wipe, true);
  assert.deepEqual(late.out, [
    { to: 'all', msg: { t: 'rematch_no', seat: null, reason: 'expired' } },
  ]);
});

test('no rematch when the bank has no new questions left', () => {
  const end = finished();
  let r = duel.rematch(end.state, 0, T0, pick, newToken);
  r = duel.rematch(r.state, 1, T0, (limit, exclude) =>
    duel.pickDuelQuestions(content, limit, 0, first, duel.DUEL_LEVELS, exclude),
  newToken);
  assert.equal(r.state.phase, 'over');
  assert.deepEqual(r.out, [
    { to: 'all', msg: { t: 'rematch_no', seat: null, reason: 'no_questions' } },
  ]);
});

test('coming back after the end hears of a rematch request', () => {
  const end = finished();
  const asked = duel.rematch(end.state, 1, T0, pickAgain, newToken);
  const back = duel.rejoin(asked.state, 'tA', T0 + 100);
  assert.deepEqual(
    back.out.map((o) => o.msg.t),
    ['end', 'rematch'],
  );
  assert.equal(back.out[0].msg.rematch, true);
});

test('a math duel: computed questions, 60 s each, ÷2 … ×2 and no minus', () => {
  const ids = [
    'math:carpma:1:12345',
    'math:faktoriyel:1:7',
    'math:turev:2:9',
    'math:olasilik:2:11',
    'math:integral:3:5',
  ];
  const pickMath = () => ids;
  let r = duel.createRoom('ABCDE', T0, 'math');
  // An app that cannot play math duels is turned away.
  assert.equal(
    duel.join(r.state, { name: 'Eski', bank: 99 }, T0, pickMath).error,
    'version',
  );
  r = duel.join(r.state, { name: 'Ayşe', bank: 99, math: true }, T0, pickMath);
  r = duel.join(r.state, { name: 'Bora', bank: 99, math: true }, T0, pickMath);
  const start = r.out.find((o) => o.msg.t === 'start').msg;
  assert.deepEqual(start.questions, ids);
  assert.equal(start.questionMs, duel.MATH_QUESTION_MS);
  assert.equal(r.out.at(-1).msg.ms, duel.MATH_QUESTION_MS);
  // 18 × 37? Whatever it is: exact scores high, nothing typed scores 0.
  const answer = duel.questionOf(content, ids[0]).answer;
  r = duel.lock(r.state, 0, { i: 0, low: answer, high: answer }, T0, content);
  r = duel.lock(r.state, 1, { i: 0, low: null, high: null }, T0, content);
  const [mine, theirs] = r.out.at(-1).msg.results;
  assert.equal(mine.points, 100);
  assert.equal(theirs.points, 0);
  // Far off: 0, not −50.
  r = duel.next(r.state, 0, { i: 0 }, T0);
  r = duel.next(r.state, 1, { i: 0 }, T0);
  r = duel.lock(r.state, 0, { i: 1, low: 1, high: 2 }, T0, content);
  r = duel.lock(r.state, 1, { i: 1, low: 1, high: 2 }, T0, content);
  assert.deepEqual(
    r.out.at(-1).msg.results.map((x) => x.points),
    [0, 0],
  );
});

test('a math id is scored with math rules, a bank id as before', () => {
  const m = duel.questionOf(content, 'math:olasilik:1:3');
  assert.equal(m.math, true);
  assert.equal(m.unit, '%');
  assert.equal(duel.questionOf(content, 'e1').math, undefined);
});
