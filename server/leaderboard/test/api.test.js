import { beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { cleanUp, echoReply, handle } from '../src/index.js';
import { scaleOf, scoreFor } from '../src/scoring.js';
import { resetContentCache, isDailySet } from '../src/content.js';
import { turkeyDayIndex } from '../src/days.js';
import { createD1 } from './d1.js';

// Day 3 = 2026-11-04, noon in Turkey.
const NOW = Date.UTC(2026, 10, 4, 9);
const DAY = 3;

const BANK = [
  { id: 'a', answer: 5137, kind: 'magnitude' },
  { id: 'b', answer: 1923, kind: 'year' },
  { id: 'c', answer: 85000000, kind: 'magnitude' },
  { id: 'd', answer: 1453, kind: 'year' },
  { id: 'e', answer: 42, kind: 'magnitude' },
  { id: 'f', answer: 10, kind: 'magnitude' },
];
const ALL_DAYS = [
  ['a', 'b', 'c', 'd', 'e'],
  ['f', 'e', 'd', 'c', 'b'],
  ['b', 'c', 'd', 'e', 'f'],
  ['a', 'b', 'c', 'd', 'e'],
];
const EXACT = { a: 5137, b: 1923, c: 85000000, d: 1453, e: 42, f: 10 };

let env;
let content;

function fakeFetch(url) {
  const name = new URL(url).pathname.split('/').pop();
  const body = {
    'manifest.json': {
      version: content.version,
      ...(content.scoringV2Day === undefined
        ? {}
        : { scoring_v2_day: content.scoringV2Day }),
      questions: 'questions.json',
      schedule: 'schedule.json',
    },
    'questions.json': BANK,
    'schedule.json': { days: content.days },
  }[name];
  return Promise.resolve(
    body ? Response.json(body) : new Response('nope', { status: 404 }),
  );
}

async function call(method, path, body, { now = NOW, ip = '1.2.3.4' } = {}) {
  const request = new Request(`https://lb.example${path}`, {
    method,
    headers: { 'cf-connecting-ip': ip },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const response = await handle(request, env, now, fakeFetch);
  return { status: response.status, body: await response.json() };
}

async function join(nickname, ip) {
  const r = await call('POST', '/v1/register', { nickname }, { ip });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  return r.body;
}

/** The first [exactCount] answers are exact, the rest timed out empty. */
function answers(exactCount = 5, day = DAY) {
  return content.days[day % content.days.length].map((q, i) =>
    i < exactCount
      ? { q, low: EXACT[q], high: EXACT[q] }
      : { q, low: null, high: null },
  );
}

beforeEach(() => {
  env = {
    DB: createD1(),
    FULL_BOARD_AT: '5',
    SMALL_BOARD: '2',
    FULL_BOARD: '3',
  };
  content = { version: 1, days: ALL_DAYS };
  resetContentCache();
});

test('day index counts in Turkey time', () => {
  assert.equal(turkeyDayIndex(NOW), DAY);
  assert.equal(turkeyDayIndex(Date.UTC(2026, 10, 1, 21)), 1); // 00:00 TR
  assert.equal(turkeyDayIndex(Date.UTC(2026, 10, 1, 20, 59)), 0);
});

test('register gives an id and token; nicknames are unique', async () => {
  const p = await join('Kaplan');
  assert.match(p.id, /^[0-9a-f-]{36}$/);
  assert.ok(p.token.length >= 40);
  assert.equal(p.nickname, 'Kaplan');
  const again = await call('POST', '/v1/register', { nickname: 'KAPLAN' });
  assert.deepEqual(again, { status: 409, body: { error: 'nickname_taken' } });
  const stored = env.DB.raw.prepare('SELECT token_hash FROM players').get();
  assert.notEqual(stored.token_hash, p.token); // only the hash is kept
});

test('register rejects bad and blocked nicknames', async () => {
  const short = await call('POST', '/v1/register', { nickname: 'x' });
  assert.equal(short.body.error, 'invalid_nickname');
  const rude = await call('POST', '/v1/register', { nickname: 'Siktir' });
  assert.equal(rude.body.error, 'blocked_nickname');
  assert.equal((await call('POST', '/v1/register', {})).status, 400);
});

test('register is rate limited per IP', async () => {
  for (const n of ['oyuncua', 'oyuncub', 'oyuncuc', 'oyuncud', 'oyuncue']) {
    await join(n, '9.9.9.9');
  }
  const r = await call(
    'POST',
    '/v1/register',
    { nickname: 'oyuncuf' },
    { ip: '9.9.9.9' },
  );
  assert.deepEqual(r, { status: 429, body: { error: 'rate_limited' } });
  await join('oyuncuf', '8.8.8.8');
  // An hour later the IP may register again.
  const later = await call(
    'POST',
    '/v1/register',
    { nickname: 'oyuncug' },
    { ip: '9.9.9.9', now: NOW + 3600001 },
  );
  assert.equal(later.status, 201);
});

test('submit computes the score on the server', async () => {
  const p = await join('Kaplan');
  const r = await call('POST', '/v1/submit', {
    id: p.id,
    token: p.token,
    day: DAY,
    answers: answers(4),
  });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.deepEqual(r.body, {
    day: DAY,
    points: 4 * 100 - 50,
    hits: 4,
    rank: 1,
    players: 1,
  });
});

test('a second submission keeps the first score', async () => {
  const p = await join('Kaplan');
  const base = { id: p.id, token: p.token, day: DAY };
  await call('POST', '/v1/submit', { ...base, answers: answers(1) });
  const r = await call('POST', '/v1/submit', { ...base, answers: answers(5) });
  assert.equal(r.body.points, 100 - 4 * 50);
});

test('submit checks the token, day, questions and bounds', async () => {
  const p = await join('Kaplan');
  const ok = { id: p.id, token: p.token, day: DAY, answers: answers() };
  const send = async (patch) =>
    (await call('POST', '/v1/submit', { ...ok, ...patch })).body.error;
  const withFirst = (first) =>
    ok.answers.map((a, i) => (i === 0 ? { q: a.q, ...first } : a));

  assert.equal(await send({ token: 'nope' }), 'unauthorized');
  assert.equal(await send({ day: DAY - 2 }), 'day_closed');
  assert.equal(await send({ day: DAY + 2 }), 'day_closed');
  assert.equal(
    await send({ answers: [...ok.answers].reverse() }),
    'wrong_questions',
  );
  assert.equal(await send({ answers: ok.answers.slice(1) }), 'bad_answers');
  assert.equal(
    await send({ answers: withFirst({ low: 6000, high: 5000 }) }),
    'bad_answers',
  );
  assert.equal(
    await send({ answers: withFirst({ low: 0, high: 5000 }) }),
    'bad_answers',
  );
  assert.equal(
    await send({ answers: withFirst({ low: 1, high: null }) }),
    'bad_answers',
  );
  assert.equal(
    await send({ answers: withFirst({ low: 1.5, high: 2 }) }),
    'bad_answers',
  );
  // Yesterday is still open (time zones, a retry after midnight).
  const yesterday = await call('POST', '/v1/submit', {
    ...ok,
    day: DAY - 1,
    answers: answers(5, DAY - 1),
  });
  assert.equal(yesterday.status, 200);
});

test('an app with an older, shorter schedule still matches', () => {
  // Day 5 on a 4-day schedule is days[1]; on a 3-day one, days[2].
  assert.ok(isDailySet(ALL_DAYS, 5, ALL_DAYS[1]));
  assert.ok(isDailySet(ALL_DAYS, 5, ALL_DAYS[2]));
  assert.ok(!isDailySet(ALL_DAYS, 5, ['a', 'a', 'a', 'a', 'a']));
  assert.ok(isDailySet(ALL_DAYS, -1, ALL_DAYS[3])); // closed test: from the end
});

test('board ranks by points, then by who sent first', async () => {
  const players = [];
  for (const [i, name] of ['Bir', 'İki', 'Üçüncü'].entries()) {
    players.push(await join(name, `10.0.0.${i}`));
  }
  const send = (p, exact, now) =>
    call(
      'POST',
      '/v1/submit',
      { id: p.id, token: p.token, day: DAY, answers: answers(exact) },
      { now },
    );
  await send(players[0], 3, NOW);
  await send(players[1], 5, NOW + 1);
  await send(players[2], 3, NOW - 1); // same as Bir, but earlier

  const r = await call('GET', `/v1/day/${DAY}?player=${players[0].id}`);
  assert.equal(r.status, 200);
  assert.equal(r.body.players, 3);
  assert.equal(r.body.limit, 2); // fewer than FULL_BOARD_AT players joined
  assert.deepEqual(
    r.body.top.map((e) => [e.rank, e.nickname, e.points, e.me]),
    [
      [1, 'İki', 500, false],
      [2, 'Üçüncü', 200, false],
    ],
  );
  assert.deepEqual(r.body.me, { rank: 3, points: 200, hits: 3 });

  const own = await call('GET', `/v1/day/${DAY}?player=${players[1].id}`);
  assert.equal(own.body.top[0].me, true);
});

test('the board grows once enough players have joined', async () => {
  for (const n of ['aaa', 'bbb', 'ccc', 'ddd', 'eee']) await join(n, n);
  const r = await call('GET', `/v1/day/${DAY}`);
  assert.equal(r.body.limit, 3);
  assert.equal(r.body.me, null);
});

test('each day has its own board', async () => {
  const p = await join('Kaplan');
  await call('POST', '/v1/submit', {
    id: p.id,
    token: p.token,
    day: DAY,
    answers: answers(),
  });
  const tomorrow = await call(
    'GET',
    `/v1/day/${DAY + 1}?player=${p.id}`,
    undefined,
    { now: NOW + 86400000 },
  );
  assert.deepEqual(
    [tomorrow.body.players, tomorrow.body.top, tomorrow.body.me],
    [0, [], null],
  );
  assert.equal((await call('GET', `/v1/day/${DAY + 5}`)).status, 404);
});

test('rename keeps scores; delete removes everything', async () => {
  const p = await join('Kaplan');
  const auth = { id: p.id, token: p.token };
  await join('Aslan', 'x');
  await call('POST', '/v1/submit', { ...auth, day: DAY, answers: answers() });
  const taken = await call('POST', '/v1/rename', { ...auth, nickname: 'Aslan' });
  assert.equal(taken.status, 409);
  const renamed = await call('POST', '/v1/rename', { ...auth, nickname: 'Pars' });
  assert.deepEqual(renamed.body, { nickname: 'Pars' });
  assert.equal((await call('GET', `/v1/day/${DAY}`)).body.top[0].nickname, 'Pars');

  const wrong = await call('POST', '/v1/delete', { id: p.id, token: 'x' });
  assert.equal(wrong.status, 401);
  const deleted = await call('POST', '/v1/delete', auth);
  assert.deepEqual(deleted.body, { deleted: true });
  assert.equal((await call('GET', `/v1/day/${DAY}`)).body.players, 0);
  const left = env.DB.raw
    .prepare('SELECT COUNT(*) AS n FROM players WHERE id = ?')
    .get(p.id);
  assert.equal(left.n, 0);
  await join('Pars', 'y'); // the nickname is free again
});

test('new content is picked up when the manifest version moves', async () => {
  const p = await join('Kaplan');
  await call('GET', '/v1/day/3');
  content = { version: 2, days: [...ALL_DAYS, ['f', 'a', 'b', 'c', 'd']] };
  const day4 = { id: p.id, token: p.token, day: 4, answers: answers(5, 4) };
  const later = NOW + 6 * 60 * 1000; // past the manifest cache
  const r = await call('POST', '/v1/submit', day4, { now: later });
  assert.equal(r.status, 200, JSON.stringify(r.body));
});

test('unknown routes and bad JSON', async () => {
  assert.equal((await call('GET', '/v1/nope')).status, 404);
  assert.equal((await call('PUT', '/v1/register', {})).status, 405);
  const bad = await handle(
    new Request('https://lb.example/v1/register', { method: 'POST', body: '{' }),
    env,
    NOW,
    fakeFetch,
  );
  assert.equal(bad.status, 400);
});

test('the daily clean-up drops IP hashes older than a day', async () => {
  await join('Kaplan', '1.1.1.1');
  await join('Aslan', '2.2.2.2');
  const count = () =>
    env.DB.raw.prepare('SELECT COUNT(*) AS n FROM register_log').get().n;
  await cleanUp(env, NOW + 1000);
  assert.equal(count(), 2);
  await cleanUp(env, NOW + 24 * 3600 * 1000 + 1);
  assert.equal(count(), 0);
});

const PHONE = 'a'.repeat(64);
const OTHER_PHONE = 'b'.repeat(64);

async function joinOn(device, nickname, ip = '1.2.3.4') {
  return call('POST', '/v1/register', { nickname, device }, { ip });
}

async function send(p, extra = {}) {
  return call('POST', '/v1/submit', {
    id: p.id,
    token: p.token,
    day: DAY,
    answers: answers(5),
    ...extra,
  });
}

test('a reinstalled app gets its account back, not a new one', async () => {
  const first = await joinOn(PHONE, 'Kaplan');
  assert.equal(first.status, 201);
  assert.equal(first.body.restored, false);
  assert.equal((await send(first.body, { device: PHONE })).status, 200);

  // Same phone, app data wiped: a new nickname is asked for, the old
  // account comes back with a fresh token.
  const again = await joinOn(PHONE, 'BaskaBiri');
  assert.equal(again.status, 200);
  assert.equal(again.body.restored, true);
  assert.equal(again.body.id, first.body.id);
  assert.equal(again.body.nickname, 'Kaplan');
  assert.equal((await send(first.body)).status, 401); // old token is gone

  // Replaying the day keeps the first score.
  const replay = await call('POST', '/v1/submit', {
    id: again.body.id,
    token: again.body.token,
    day: DAY,
    answers: answers(0),
    device: PHONE,
  });
  assert.equal(replay.status, 200);
  assert.equal(replay.body.points, 500);
  assert.equal(replay.body.players, 1);
  const players = env.DB.raw.prepare('SELECT COUNT(*) AS n FROM players').get();
  assert.equal(players.n, 1);
});

test('leaving and joining again does not send the same day twice', async () => {
  const first = (await joinOn(PHONE, 'Kaplan')).body;
  await send(first, { device: PHONE });
  await call('POST', '/v1/delete', { id: first.id, token: first.token });
  // The account and its scores are gone, the device may join again...
  const second = await joinOn(PHONE, 'Aslan');
  assert.equal(second.status, 201);
  // ...but not send today's set a second time.
  const r = await send(second.body, { device: PHONE });
  assert.deepEqual(r, { status: 422, body: { error: 'already_played' } });
  // Another day is fine.
  const tomorrow = await call('POST', '/v1/submit', {
    id: second.body.id,
    token: second.body.token,
    day: DAY + 1,
    answers: answers(5, DAY + 1),
    device: PHONE,
  });
  assert.equal(tomorrow.status, 200);
});

test('an account from an older app is tied to its device on submit', async () => {
  const old = await join('Kaplan'); // no device key
  assert.equal((await send(old, { device: PHONE })).status, 200);
  const restored = await joinOn(PHONE, 'Yeni');
  assert.equal(restored.body.restored, true);
  assert.equal(restored.body.id, old.id);
  // A second old account on the same phone cannot send the same day.
  const other = await join('Aslan');
  const r = await send(other, { device: PHONE });
  assert.equal(r.body.error, 'already_played');
  // Different phones do not affect each other.
  const elsewhere = await joinOn(OTHER_PHONE, 'Kartal');
  assert.equal((await send(elsewhere.body, { device: OTHER_PHONE })).status, 200);
});

test('device keys are checked; old apps can be turned away', async () => {
  const bad = await joinOn('nope', 'Kaplan');
  assert.deepEqual(bad, { status: 400, body: { error: 'bad_device' } });
  const stored = (await joinOn(PHONE, 'Kaplan')).body;
  const row = env.DB.raw.prepare('SELECT device_hash FROM players').get();
  assert.notEqual(row.device_hash, PHONE); // only a salted hash is kept
  assert.equal(row.device_hash.length, 64);
  assert.ok(stored.token);
  env.REQUIRE_DEVICE = '1';
  const legacy = await call('POST', '/v1/register', { nickname: 'Aslan' });
  assert.deepEqual(legacy, { status: 426, body: { error: 'update_required' } });
});

test('the daily clean-up drops device days the server no longer accepts', async () => {
  const p = (await joinOn(PHONE, 'Kaplan')).body;
  await send(p, { device: PHONE });
  const count = () =>
    env.DB.raw.prepare('SELECT COUNT(*) AS n FROM device_days').get().n;
  await cleanUp(env, NOW + 24 * 3600 * 1000); // tomorrow: still needed
  assert.equal(count(), 1);
  await cleanUp(env, NOW + 3 * 24 * 3600 * 1000);
  assert.equal(count(), 0);
});

test('a wiped app learns its account and the days its device sent', async () => {
  const unknown = await call('POST', '/v1/device', { device: OTHER_PHONE });
  assert.deepEqual(unknown, { status: 200, body: { account: null, days: [] } });
  const players = () =>
    env.DB.raw.prepare('SELECT COUNT(*) AS n FROM players').get().n;
  assert.equal(players(), 0); // a lookup stores nothing

  const p = (await joinOn(PHONE, 'Kaplan')).body;
  await send(p, { device: PHONE });
  const status = await call('POST', '/v1/device', { device: PHONE });
  assert.equal(status.status, 200);
  assert.equal(status.body.account.id, p.id);
  assert.equal(status.body.account.nickname, 'Kaplan');
  assert.deepEqual(status.body.days, [DAY]);
  // The new token works, the old one does not.
  assert.equal((await send(p)).status, 401);
  const again = await send(status.body.account, { device: PHONE });
  assert.equal(again.status, 200);

  // After leaving, the day is still known, the account is not.
  await call('POST', '/v1/delete', {
    id: p.id,
    token: status.body.account.token,
  });
  const left = await call('POST', '/v1/device', { device: PHONE });
  assert.deepEqual(left.body, { account: null, days: [DAY] });
  const bad = await call('POST', '/v1/device', { device: 'x' });
  assert.equal(bad.status, 400);
});

test('days from the switch day on are scored with the scale of each question', async () => {
  // Wide but honest intervals: ±10% for magnitudes, ±40 years.
  const wide = content.days[DAY % content.days.length].map((q) => {
    const a = EXACT[q];
    const year = BANK.find((b) => b.id === q).kind === 'year';
    return year
      ? { q, low: a - 40, high: a + 40 }
      : { q, low: Math.floor(a * 0.9), high: Math.ceil(a * 1.1) };
  });
  const expected = (scaled) =>
    wide.reduce((sum, a) => {
      const b = BANK.find((x) => x.id === a.q);
      const scale = scaled ? scaleOf(b.kind, b.category, b.answer) : null;
      return sum + scoreFor(b.kind, a.low, a.high, b.answer, scale);
    }, 0);

  const before = await join('Kaplan');
  content.scoringV2Day = DAY + 1; // tomorrow: today keeps the first rule
  resetContentCache();
  let r = await call('POST', '/v1/submit', {
    id: before.id,
    token: before.token,
    day: DAY,
    answers: wide,
  });
  assert.equal(r.body.points, expected(false));

  const after = await join('Aslan');
  content.scoringV2Day = DAY;
  resetContentCache();
  r = await call('POST', '/v1/submit', {
    id: after.id,
    token: after.token,
    day: DAY,
    answers: wide,
  });
  assert.equal(r.body.points, expected(true));
  assert.ok(expected(true) > expected(false)); // ±40 years is fair now
});

test('a nickname can change once every three days', async () => {
  const p = await join('Kaplan');
  const auth = { id: p.id, token: p.token };
  const first = await call('POST', '/v1/rename', { ...auth, nickname: 'Pars' });
  assert.equal(first.status, 200);
  // The same name again is not a change.
  const same = await call('POST', '/v1/rename', { ...auth, nickname: 'Pars' });
  assert.equal(same.status, 200);
  const soon = await call(
    'POST',
    '/v1/rename',
    { ...auth, nickname: 'Vaşak' },
    { now: NOW + 2 * 24 * 3600 * 1000 },
  );
  assert.equal(soon.status, 429);
  assert.equal(soon.body.error, 'rename_wait');
  assert.equal(soon.body.retry_at, NOW + 3 * 24 * 3600 * 1000);
  // Even a different case of the same letters waits.
  const cased = await call('POST', '/v1/rename', { ...auth, nickname: 'pars' });
  assert.equal(cased.status, 429);
  const later = await call(
    'POST',
    '/v1/rename',
    { ...auth, nickname: 'Vaşak' },
    { now: NOW + 3 * 24 * 3600 * 1000 },
  );
  assert.deepEqual(later.body, { nickname: 'Vaşak' });
});

test('very high scores are marked suspect', async () => {
  const perfect = await join('Kaplan');
  const honest = await join('Aslan', 'x');
  await call('POST', '/v1/submit', {
    id: perfect.id,
    token: perfect.token,
    day: DAY,
    answers: answers(),
  });
  await call('POST', '/v1/submit', {
    id: honest.id,
    token: honest.token,
    day: DAY,
    answers: answers(2),
  });
  const rows = env.DB.raw
    .prepare('SELECT player_id, suspect FROM scores ORDER BY points DESC')
    .all();
  assert.deepEqual(
    rows.map((r) => [r.player_id, r.suspect]),
    [
      [perfect.id, 1],
      [honest.id, 0],
    ],
  );
});

test('a hidden player sees themselves; nobody else does', async () => {
  const cheat = await join('Kaplan');
  const fair = await join('Aslan', 'x');
  await call('POST', '/v1/submit', {
    id: cheat.id,
    token: cheat.token,
    day: DAY,
    answers: answers(),
  });
  await call('POST', '/v1/submit', {
    id: fair.id,
    token: fair.token,
    day: DAY,
    answers: answers(3),
  });
  env.DB.raw.prepare('UPDATE players SET hidden = 1 WHERE id = ?').run(cheat.id);

  const everyone = (await call('GET', `/v1/day/${DAY}`)).body;
  assert.deepEqual(everyone.top.map((r) => r.nickname), ['Aslan']);
  assert.equal(everyone.players, 1);
  const fairView = (await call('GET', `/v1/day/${DAY}?player=${fair.id}`)).body;
  assert.equal(fairView.me.rank, 1);

  const own = (await call('GET', `/v1/day/${DAY}?player=${cheat.id}`)).body;
  assert.deepEqual(own.top.map((r) => r.nickname), ['Kaplan', 'Aslan']);
  assert.equal(own.top[0].me, true);
  assert.equal(own.me.rank, 1);
  assert.equal(own.players, 2);
});

test('duel rooms and the lobby are limited per address', async () => {
  const seen = [];
  env.DUEL_ROOMS = {};
  env.DUEL_LIMITER = {
    limit: async ({ key }) => {
      seen.push(key);
      return { success: seen.length <= 1 };
    },
  };
  const blocked = await call('POST', '/v1/duel/rooms', {});
  // The first call passes the limiter (the fake room namespace then fails).
  assert.notEqual(blocked.status, 429);
  const second = await call('POST', '/v1/duel/rooms', {});
  assert.equal(second.status, 429);
  assert.equal(second.body.error, 'rate_limited');
  assert.deepEqual(seen, ['duel:1.2.3.4', 'duel:1.2.3.4']);
});

test('the connection test echo answers pings and wants a WebSocket', async () => {
  assert.equal(echoReply('{"t":"ping"}'), '{"t":"pong"}');
  assert.equal(echoReply('hello'), null);
  const plain = await call('GET', '/v1/echo');
  assert.deepEqual(plain, { status: 426, body: { error: 'websocket_only' } });
});

test('kabaca.app serves the website, not the API', async () => {
  const served = [];
  const site = {
    ...env,
    ASSETS: {
      fetch: async (request) => {
        served.push(new URL(request.url).pathname);
        return new Response('<h1>Kabaca</h1>', {
          headers: { 'content-type': 'text/html' },
        });
      },
    },
  };
  const page = await handle(new Request('https://kabaca.app/'), site);
  assert.equal(page.status, 200);
  assert.equal(await page.text(), '<h1>Kabaca</h1>');
  assert.match(page.headers.get('cache-control'), /max-age=600/);
  const www = await handle(new Request('https://www.kabaca.app/x?lang=en'), site);
  assert.equal(www.status, 301);
  assert.equal(www.headers.get('location'), 'https://kabaca.app/x?lang=en');
  // The API host never serves the site.
  const api = await handle(new Request('https://api.kabaca.app/v1'), site);
  assert.deepEqual(await api.json(), { ok: true });
  assert.deepEqual(served, ['/']);
});

test('an invite link without the app gets the invite page', async () => {
  const served = [];
  const site = {
    ...env,
    ASSETS: {
      fetch: async (request) => {
        served.push(new URL(request.url).pathname);
        return new Response('<h1>Davet</h1>', {
          headers: { 'content-type': 'text/html' },
        });
      },
    },
  };
  for (const path of ['/d/K7M3P', '/t/k7m3p/']) {
    const r = await handle(new Request(`https://kabaca.app${path}`), site);
    assert.equal(r.status, 200);
    assert.match(r.headers.get('cache-control'), /max-age=600/);
  }
  // Not a room code: the path goes to the assets as it is (404 there).
  await handle(new Request('https://kabaca.app/d/K7MOP'), site);
  assert.deepEqual(served, ['/invite', '/invite', '/d/K7MOP']);
});

test('kabaca.app proves it belongs to the app (Digital Asset Links)', async () => {
  const r = await handle(
    new Request('https://kabaca.app/.well-known/assetlinks.json'),
    env,
  );
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('content-type'), 'application/json');
  const [link] = await r.json();
  assert.equal(link.target.package_name, 'com.yerdema.kabaca');
  assert.equal(link.target.sha256_cert_fingerprints.length, 4);
  for (const f of link.target.sha256_cert_fingerprints) {
    assert.match(f, /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/);
  }
});
