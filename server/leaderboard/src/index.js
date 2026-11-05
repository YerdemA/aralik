// Kabaca daily leaderboard: a Cloudflare Worker with a D1 database.
//
// Joining is optional and needs only a nickname. The app keeps a random
// id and a secret token; the server stores the token's SHA-256 only.
// Scores are computed here from the published questions, never taken from
// the app. Each day has its own board, so it starts empty when the
// day's questions change.
//
//   POST /v1/register  {nickname}                    → {id, token, nickname}
//   POST /v1/rename    {id, token, nickname}         → {nickname}
//   POST /v1/submit    {id, token, day, answers[5]}  → {points, hits, rank, players}
//   GET  /v1/day/{n}?player={id}                     → board of day n
//   POST /v1/delete    {id, token}                   → {deleted: true}
//
// Real-time duels (no account needed; see duel.js for the protocol):
//   POST /v1/duel/rooms                              → {code}
//   GET  /v1/duel/rooms/{code}?v=1&name=…&bank=N     WebSocket to the room
//   GET  /v1/duel/random?v=1&name=…&bank=N           WebSocket to the lobby

import { acceptsDay, readableDay, QUESTIONS_PER_DAY } from './days.js';
import { isDailySet, loadContent } from './content.js';
import { cleanNickname, isBlocked, nicknameKey } from './nickname.js';
import { isHit, scoreFor, validBound } from './scoring.js';
import { normalizeRoomCode } from './duel.js';
import { openRoom, roomStub } from './rooms.js';

const DEFAULTS = {
  CONTENT_BASE: 'https://yerdema.github.io/aralik/content/',
  // Until this many players have joined, the board shows the top 10;
  // from then on the top 50.
  FULL_BOARD_AT: '100',
  SMALL_BOARD: '10',
  FULL_BOARD: '50',
  // New nicknames per IP address per hour.
  REGISTER_LIMIT: '5',
};

const HOUR_MS = 60 * 60 * 1000;
const MAX_BODY_BYTES = 4096;

class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

function json(status, body, cache = 'no-store') {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': cache,
    },
  });
}

function setting(env, name) {
  return Number(env[name] ?? DEFAULTS[name]);
}

async function sha256(text) {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function randomToken(bytes = 32) {
  const raw = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...raw))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function readBody(request) {
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) throw new HttpError(413, 'too_large');
  try {
    const body = JSON.parse(text);
    if (body && typeof body === 'object' && !Array.isArray(body)) return body;
  } catch {
    // fall through
  }
  throw new HttpError(400, 'bad_request');
}

/** The player behind {id, token}, or a 401. */
async function authenticate(db, body) {
  if (typeof body.id !== 'string' || typeof body.token !== 'string') {
    throw new HttpError(401, 'unauthorized');
  }
  const player = await db
    .prepare('SELECT id, nickname, token_hash FROM players WHERE id = ?')
    .bind(body.id)
    .first();
  if (!player || player.token_hash !== (await sha256(body.token))) {
    throw new HttpError(401, 'unauthorized');
  }
  return player;
}

/** A valid, free nickname as {name, key}; throws otherwise. */
async function checkNickname(db, raw, exceptId = null) {
  const name = cleanNickname(raw);
  if (!name) throw new HttpError(400, 'invalid_nickname');
  const key = nicknameKey(name);
  if (isBlocked(key)) throw new HttpError(400, 'blocked_nickname');
  const owner = await db
    .prepare('SELECT id FROM players WHERE nickname_key = ?')
    .bind(key)
    .first();
  if (owner && owner.id !== exceptId) {
    throw new HttpError(409, 'nickname_taken');
  }
  return { name, key };
}

async function register(request, env, now) {
  const body = await readBody(request);
  const db = env.DB;

  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const ipHash = await sha256(`${env.IP_SALT ?? 'kabaca'}:${ip}`);
  await db
    .prepare('DELETE FROM register_log WHERE at < ?')
    .bind(now - 24 * HOUR_MS)
    .run();
  const recent = await db
    .prepare(
      'SELECT COUNT(*) AS n FROM register_log WHERE ip_hash = ? AND at >= ?',
    )
    .bind(ipHash, now - HOUR_MS)
    .first();
  if (recent.n >= setting(env, 'REGISTER_LIMIT')) {
    throw new HttpError(429, 'rate_limited');
  }

  const { name, key } = await checkNickname(db, body.nickname);
  const id = crypto.randomUUID();
  const token = randomToken();
  try {
    await db.batch([
      db
        .prepare(
          'INSERT INTO players (id, token_hash, nickname, nickname_key, created_at) VALUES (?, ?, ?, ?, ?)',
        )
        .bind(id, await sha256(token), name, key, now),
      db
        .prepare('INSERT INTO register_log (ip_hash, at) VALUES (?, ?)')
        .bind(ipHash, now),
    ]);
  } catch (e) {
    if (String(e).includes('UNIQUE')) throw new HttpError(409, 'nickname_taken');
    throw e;
  }
  return json(201, { id, token, nickname: name });
}

async function rename(request, env) {
  const body = await readBody(request);
  const player = await authenticate(env.DB, body);
  const { name, key } = await checkNickname(env.DB, body.nickname, player.id);
  await env.DB.prepare(
    'UPDATE players SET nickname = ?, nickname_key = ? WHERE id = ?',
  )
    .bind(name, key, player.id)
    .run();
  return json(200, { nickname: name });
}

async function submit(request, env, now, fetchFn) {
  const body = await readBody(request);
  const db = env.DB;
  const player = await authenticate(db, body);

  const day = body.day;
  if (!acceptsDay(day, now)) throw new HttpError(422, 'day_closed');

  const answers = body.answers;
  if (!Array.isArray(answers) || answers.length !== QUESTIONS_PER_DAY) {
    throw new HttpError(400, 'bad_answers');
  }
  const content = await loadContent(
    env.CONTENT_BASE ?? DEFAULTS.CONTENT_BASE,
    fetchFn,
    now,
  );
  const ids = answers.map((a) => a?.q);
  if (!isDailySet(content.days, day, ids)) {
    throw new HttpError(422, 'wrong_questions');
  }

  let points = 0;
  let hits = 0;
  for (const a of answers) {
    const q = content.questions.get(a.q);
    if (!q) throw new HttpError(422, 'wrong_questions');
    const empty = a.low === null && a.high === null;
    if (
      !empty &&
      !(validBound(q.kind, a.low) && validBound(q.kind, a.high) && a.low <= a.high)
    ) {
      throw new HttpError(400, 'bad_answers');
    }
    const low = empty ? null : a.low;
    const high = empty ? null : a.high;
    points += scoreFor(q.kind, low, high, q.answer);
    if (isHit(low, high, q.answer)) hits++;
  }

  // The first submission of a day counts; a retry gets the same answer.
  await db
    .prepare(
      'INSERT OR IGNORE INTO scores (day, player_id, points, hits, submitted_at) VALUES (?, ?, ?, ?, ?)',
    )
    .bind(day, player.id, points, hits, now)
    .run();
  const mine = await myScore(db, day, player.id);
  return json(200, {
    day,
    points: mine.points,
    hits: mine.hits,
    rank: mine.rank,
    players: await dayPlayers(db, day),
  });
}

async function dayPlayers(db, day) {
  const row = await db
    .prepare('SELECT COUNT(*) AS n FROM scores WHERE day = ?')
    .bind(day)
    .first();
  return row.n;
}

/**
 * The player's score and rank on [day], or null. Ties go to whoever sent
 * first, so ranks are unique.
 */
async function myScore(db, day, playerId) {
  const row = await db
    .prepare(
      'SELECT points, hits, submitted_at FROM scores WHERE day = ? AND player_id = ?',
    )
    .bind(day, playerId)
    .first();
  if (!row) return null;
  const ahead = await db
    .prepare(
      `SELECT COUNT(*) AS n FROM scores WHERE day = ?1 AND (
         points > ?2
         OR (points = ?2 AND submitted_at < ?3)
         OR (points = ?2 AND submitted_at = ?3 AND player_id < ?4))`,
    )
    .bind(day, row.points, row.submitted_at, playerId)
    .first();
  return { rank: ahead.n + 1, points: row.points, hits: row.hits };
}

async function board(day, url, env, now) {
  if (!readableDay(day, now)) throw new HttpError(404, 'not_found');
  const db = env.DB;
  const total = await db.prepare('SELECT COUNT(*) AS n FROM players').first();
  const limit =
    total.n >= setting(env, 'FULL_BOARD_AT')
      ? setting(env, 'FULL_BOARD')
      : setting(env, 'SMALL_BOARD');
  const { results } = await db
    .prepare(
      `SELECT s.player_id, p.nickname, s.points, s.hits
         FROM scores s JOIN players p ON p.id = s.player_id
        WHERE s.day = ?
        ORDER BY s.points DESC, s.submitted_at ASC, s.player_id ASC
        LIMIT ?`,
    )
    .bind(day, limit)
    .all();
  const playerId = url.searchParams.get('player');
  const me = playerId ? await myScore(db, day, playerId) : null;
  return json(
    200,
    {
      day,
      players: await dayPlayers(db, day),
      limit,
      top: results.map((r, i) => ({
        rank: i + 1,
        nickname: r.nickname,
        points: r.points,
        hits: r.hits,
        me: r.player_id === playerId,
      })),
      me,
    },
    'no-store',
  );
}

async function remove(request, env) {
  const body = await readBody(request);
  const player = await authenticate(env.DB, body);
  await env.DB.batch([
    env.DB.prepare('DELETE FROM scores WHERE player_id = ?').bind(player.id),
    env.DB.prepare('DELETE FROM players WHERE id = ?').bind(player.id),
  ]);
  return json(200, { deleted: true });
}

async function createRoom(env) {
  if (!env.DUEL_ROOMS) throw new HttpError(404, 'not_found');
  const code = await openRoom(env);
  if (!code) throw new HttpError(503, 'busy');
  return json(201, { code });
}

function connectRoom(request, env, code) {
  const room = normalizeRoomCode(code);
  if (!room) throw new HttpError(404, 'no_room');
  requireWebSocket(request, env);
  return roomStub(env, room).fetch(request);
}

function requireWebSocket(request, env) {
  if (!env.DUEL_ROOMS) throw new HttpError(404, 'not_found');
  if (request.headers.get('upgrade') !== 'websocket') {
    throw new HttpError(426, 'websocket_only');
  }
}

/** Random opponent: one lobby pairs up whoever is waiting. */
function findOpponent(request, env) {
  requireWebSocket(request, env);
  return env.DUEL_LOBBY.get(env.DUEL_LOBBY.idFromName('lobby')).fetch(request);
}

/** Routes one request. [now] and [fetchFn] are replaceable in tests. */
export async function handle(request, env, now = Date.now(), fetchFn = fetch) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '');
  try {
    if (request.method === 'GET') {
      const match = /^\/v1\/day\/(-?\d+)$/.exec(path);
      if (match) return await board(Number(match[1]), url, env, now);
      const room = /^\/v1\/duel\/rooms\/([^/]+)$/.exec(path);
      if (room) return await connectRoom(request, env, room[1]);
      if (path === '/v1/duel/random') return await findOpponent(request, env);
      if (path === '' || path === '/v1') return json(200, { ok: true });
      throw new HttpError(404, 'not_found');
    }
    if (request.method === 'POST') {
      switch (path) {
        case '/v1/register':
          return await register(request, env, now);
        case '/v1/rename':
          return await rename(request, env);
        case '/v1/submit':
          return await submit(request, env, now, fetchFn);
        case '/v1/delete':
          return await remove(request, env);
        case '/v1/duel/rooms':
          return await createRoom(env);
      }
      throw new HttpError(404, 'not_found');
    }
    throw new HttpError(405, 'method_not_allowed');
  } catch (e) {
    if (e instanceof HttpError) return json(e.status, { error: e.code });
    console.error(e);
    return json(500, { error: 'server_error' });
  }
}

/** Daily clean-up: hashed IPs of the rate limit are kept one day at most. */
export async function cleanUp(env, now = Date.now()) {
  await env.DB.prepare('DELETE FROM register_log WHERE at < ?')
    .bind(now - 24 * HOUR_MS)
    .run();
}

export default {
  fetch: (request, env) => handle(request, env),
  scheduled: (_event, env, ctx) => ctx.waitUntil(cleanUp(env)),
};
