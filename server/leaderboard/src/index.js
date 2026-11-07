// Kabaca daily leaderboard: a Cloudflare Worker with a D1 database.
//
// Joining is optional and needs only a nickname. The app keeps a random
// id and a secret token; the server stores the token's SHA-256 only.
// Scores are computed here from the published questions, never taken from
// the app.
//
// One account per device: the app sends a device key (a hash of Android's
// per-app device id, which survives reinstalling and clearing the app's
// data). The server keeps only its salted hash. Registering again from the
// same device restores that account, and a device can send each day once,
// whatever account it uses. Each day has its own board, so it starts empty when the
// day's questions change.
//
//   POST /v1/register  {nickname, device}            → {id, token, nickname, restored}
//   POST /v1/rename    {id, token, nickname}         → {nickname}
//   POST /v1/submit    {id, token, day, answers[5], device}
//                                                    → {points, hits, rank, players}
//   GET  /v1/day/{n}?player={id}                     → board of day n
//   POST /v1/delete    {id, token}                   → {deleted: true}
//   POST /v1/device    {device}                      → {account, days}
//      Asked on launch by an app without an account (e.g. its data was
//      cleared): this device's account (with a new token) or null, and the
//      days it already sent, so the app does not offer them again. Nothing
//      is stored for a device that never joined.
//
// Real-time duels (no account needed; see duel.js for the protocol):
//   POST /v1/duel/rooms                              → {code}
//   GET  /v1/duel/rooms/{code}?v=1&name=…&bank=N     WebSocket to the room
//   GET  /v1/duel/random?v=1&name=…&bank=N           WebSocket to the lobby
//   POST /v1/tournament/rooms                        → {code}  (tournament.js)
//   GET  /v1/tournament/rooms/{code}?v=1&name=…&bank=N  WebSocket to the room

import {
  acceptsDay,
  readableDay,
  turkeyDayIndex,
  QUESTIONS_PER_DAY,
} from './days.js';
import { isDailySet, loadContent, scaleOn } from './content.js';
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
  // '1' refuses apps that send no device key (older than 1.0.3).
  REQUIRE_DEVICE: '0',
  // Days between two nickname changes.
  RENAME_DAYS: '3',
  // A day's score at or above this is marked suspect for a look
  // (scripts/admin.mjs); honest play rarely gets there.
  SUSPECT_POINTS: '470',
  // Seconds a day's board may be served from the edge cache.
  BOARD_CACHE_SECONDS: '30',
};

const HOUR_MS = 60 * 60 * 1000;
const MAX_BODY_BYTES = 4096;

class HttpError extends Error {
  constructor(status, code, extra = {}) {
    super(code);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

/**
 * Per-IP limit for requests that cost the server without an account:
 * opening duel rooms, joining them and the random lobby. Cloudflare's
 * rate limiting binding (wrangler.toml, DUEL_LIMITER); without it (tests,
 * local dev) nothing is limited.
 */
async function limitDuel(request, env) {
  if (!env.DUEL_LIMITER) return;
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const { success } = await env.DUEL_LIMITER.limit({ key: `duel:${ip}` });
  if (!success) throw new HttpError(429, 'rate_limited');
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
    .prepare(
      'SELECT id, nickname, token_hash, device_hash, renamed_at FROM players WHERE id = ?',
    )
    .bind(body.id)
    .first();
  if (!player || player.token_hash !== (await sha256(body.token))) {
    throw new HttpError(401, 'unauthorized');
  }
  return player;
}

/**
 * The stored hash of the app's device key, null when the app sent none
 * (apps older than 1.0.3). Throws on a malformed key.
 */
async function deviceHash(env, raw) {
  if (raw === undefined || raw === null) {
    if (setting(env, 'REQUIRE_DEVICE') === 1) {
      throw new HttpError(426, 'update_required');
    }
    return null;
  }
  if (typeof raw !== 'string' || !/^[0-9a-f]{64}$/.test(raw)) {
    throw new HttpError(400, 'bad_device');
  }
  return sha256(`${env.DEVICE_SALT ?? env.IP_SALT ?? 'kabaca'}:device:${raw}`);
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
  const device = await deviceHash(env, body.device);

  // This device already has an account (the app was reinstalled or its
  // data cleared): hand it back with a new token instead of a new one.
  if (device) {
    const owner = await db
      .prepare('SELECT id, nickname FROM players WHERE device_hash = ?')
      .bind(device)
      .first();
    if (owner) {
      const token = randomToken();
      await db
        .prepare('UPDATE players SET token_hash = ? WHERE id = ?')
        .bind(await sha256(token), owner.id)
        .run();
      return json(200, {
        id: owner.id,
        token,
        nickname: owner.nickname,
        restored: true,
      });
    }
  }

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
          'INSERT INTO players (id, token_hash, nickname, nickname_key, created_at, device_hash) VALUES (?, ?, ?, ?, ?, ?)',
        )
        .bind(id, await sha256(token), name, key, now, device),
      db
        .prepare('INSERT INTO register_log (ip_hash, at) VALUES (?, ?)')
        .bind(ipHash, now),
    ]);
  } catch (e) {
    if (String(e).includes('UNIQUE')) throw new HttpError(409, 'nickname_taken');
    throw e;
  }
  return json(201, { id, token, nickname: name, restored: false });
}

async function rename(request, env, now) {
  const body = await readBody(request);
  const player = await authenticate(env.DB, body);
  const { name, key } = await checkNickname(env.DB, body.nickname, player.id);
  if (name === player.nickname) return json(200, { nickname: name });
  // One change per RENAME_DAYS: no cycling names past the filter, no
  // grabbing other players' names.
  const wait = setting(env, 'RENAME_DAYS') * 24 * HOUR_MS;
  if (player.renamed_at !== null && now - player.renamed_at < wait) {
    throw new HttpError(429, 'rename_wait', {
      retry_at: player.renamed_at + wait,
    });
  }
  await env.DB.prepare(
    'UPDATE players SET nickname = ?, nickname_key = ?, renamed_at = ? WHERE id = ?',
  )
    .bind(name, key, now, player.id)
    .run();
  return json(200, { nickname: name });
}

async function submit(request, env, now, fetchFn) {
  const body = await readBody(request);
  const db = env.DB;
  const player = await authenticate(db, body);

  const day = body.day;
  if (!acceptsDay(day, now)) throw new HttpError(422, 'day_closed');
  const device = player.device_hash ?? (await deviceHash(env, body.device));

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
    points += scoreFor(q.kind, low, high, q.answer, scaleOn(content, q, day));
    if (isHit(low, high, q.answer)) hits++;
  }

  // The first submission of a day counts; a retry gets the same answer.
  const sent = await myScore(db, day, player.id);
  if (!sent && device) {
    // Another account on this device already sent this day.
    const played = await db
      .prepare('SELECT 1 AS x FROM device_days WHERE device_hash = ? AND day = ?')
      .bind(device, day)
      .first();
    if (played) throw new HttpError(422, 'already_played');
    if (!player.device_hash) await claimDevice(db, player.id, device);
  }
  await db.batch([
    db
      .prepare(
        'INSERT OR IGNORE INTO scores (day, player_id, points, hits, submitted_at, suspect) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .bind(
        day,
        player.id,
        points,
        hits,
        now,
        points >= setting(env, 'SUSPECT_POINTS') ? 1 : 0,
      ),
    ...(device
      ? [
          db
            .prepare(
              'INSERT OR IGNORE INTO device_days (device_hash, day) VALUES (?, ?)',
            )
            .bind(device, day),
        ]
      : []),
  ]);
  if (!sent) await dropCachedBoard(day);
  const mine = await myScore(db, day, player.id);
  return json(200, {
    day,
    points: mine.points,
    hits: mine.hits,
    rank: mine.rank,
    players: await dayPlayers(db, day, player.id),
  });
}

/** Players on [day]'s board: hidden ones count only for themselves. */
async function dayPlayers(db, day, viewerId = null) {
  const row = await db
    .prepare(
      `SELECT COUNT(*) AS n FROM scores s JOIN players p ON p.id = s.player_id
        WHERE s.day = ? AND (p.hidden = 0 OR p.id = ?)`,
    )
    .bind(day, viewerId)
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
      `SELECT COUNT(*) AS n FROM scores s JOIN players p ON p.id = s.player_id
        WHERE s.day = ?1 AND p.hidden = 0 AND (
         s.points > ?2
         OR (s.points = ?2 AND s.submitted_at < ?3)
         OR (s.points = ?2 AND s.submitted_at = ?3 AND s.player_id < ?4))`,
    )
    .bind(day, row.points, row.submitted_at, playerId)
    .first();
  return { rank: ahead.n + 1, points: row.points, hits: row.hits };
}

/** The edge cache of the boards; absent outside Workers (tests). */
function boardCache() {
  return globalThis.caches?.default ?? null;
}

function boardCacheKey(day) {
  return new Request(`https://board.cache/v1/day/${day}`);
}

/** A new score changes [day]'s board: the next read rebuilds it. */
async function dropCachedBoard(day) {
  await boardCache()?.delete(boardCacheKey(day));
}

/**
 * The top of [day]'s board as everyone sees it, or as [viewerId] sees it
 * when that player is hidden: a hidden player still finds themselves on
 * it, nobody else does.
 */
async function topOfBoard(env, day, viewerId) {
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
        WHERE s.day = ? AND (p.hidden = 0 OR p.id = ?)
        ORDER BY s.points DESC, s.submitted_at ASC, s.player_id ASC
        LIMIT ?`,
    )
    .bind(day, viewerId, limit)
    .all();
  return {
    players: await dayPlayers(db, day, viewerId),
    limit,
    top: results.map((r, i) => ({
      rank: i + 1,
      id: r.player_id,
      nickname: r.nickname,
      points: r.points,
      hits: r.hits,
    })),
  };
}

/** The shared top, from the edge cache for up to BOARD_CACHE_SECONDS. */
async function cachedTop(env, day) {
  const cache = boardCache();
  const key = boardCacheKey(day);
  const hit = await cache?.match(key);
  if (hit) return hit.json();
  const top = await topOfBoard(env, day, null);
  await cache?.put(
    key,
    json(200, top, `public, max-age=${setting(env, 'BOARD_CACHE_SECONDS')}`),
  );
  return top;
}

async function board(day, url, env, now) {
  if (!readableDay(day, now)) throw new HttpError(404, 'not_found');
  const db = env.DB;
  const playerId = url.searchParams.get('player');
  const viewer = playerId
    ? await db
        .prepare('SELECT hidden FROM players WHERE id = ?')
        .bind(playerId)
        .first()
    : null;
  const shared = viewer?.hidden
    ? await topOfBoard(env, day, playerId)
    : await cachedTop(env, day);
  // A hidden player is ranked among the visible ones, as if on the board.
  const me = playerId ? await myScore(db, day, playerId) : null;
  return json(
    200,
    {
      day,
      players: shared.players,
      limit: shared.limit,
      top: shared.top.map(({ id, ...row }) => ({
        ...row,
        me: id === playerId,
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

/** Opens a tournament room for its host and returns the code. */
async function createTournament(request, env) {
  if (!env.TOURNAMENT_ROOMS) throw new HttpError(404, 'not_found');
  await limitDuel(request, env);
  const code = await openRoom(env, undefined, env.TOURNAMENT_ROOMS);
  if (!code) throw new HttpError(503, 'busy');
  return json(201, { code });
}

async function connectTournament(request, env, code) {
  const room = normalizeRoomCode(code);
  if (!room) throw new HttpError(404, 'no_room');
  if (!env.TOURNAMENT_ROOMS) throw new HttpError(404, 'not_found');
  if (request.headers.get('upgrade') !== 'websocket') {
    throw new HttpError(426, 'websocket_only');
  }
  await limitDuel(request, env);
  return roomStub(env, room, env.TOURNAMENT_ROOMS).fetch(request);
}

async function createRoom(request, env) {
  if (!env.DUEL_ROOMS) throw new HttpError(404, 'not_found');
  await limitDuel(request, env);
  const code = await openRoom(env);
  if (!code) throw new HttpError(503, 'busy');
  return json(201, { code });
}

async function connectRoom(request, env, code) {
  const room = normalizeRoomCode(code);
  if (!room) throw new HttpError(404, 'no_room');
  requireWebSocket(request, env);
  await limitDuel(request, env);
  return roomStub(env, room).fetch(request);
}

function requireWebSocket(request, env) {
  if (!env.DUEL_ROOMS) throw new HttpError(404, 'not_found');
  if (request.headers.get('upgrade') !== 'websocket') {
    throw new HttpError(426, 'websocket_only');
  }
}

/** Random opponent: one lobby pairs up whoever is waiting. */
async function findOpponent(request, env) {
  requireWebSocket(request, env);
  await limitDuel(request, env);
  return env.DUEL_LOBBY.get(env.DUEL_LOBBY.idFromName('lobby')).fetch(request);
}

async function deviceStatus(request, env, now) {
  const body = await readBody(request);
  const device = await deviceHash(env, body.device);
  if (!device) throw new HttpError(400, 'bad_device');
  const db = env.DB;
  const owner = await db
    .prepare('SELECT id, nickname FROM players WHERE device_hash = ?')
    .bind(device)
    .first();
  let account = null;
  if (owner) {
    const token = randomToken();
    await db
      .prepare('UPDATE players SET token_hash = ? WHERE id = ?')
      .bind(await sha256(token), owner.id)
      .run();
    account = { id: owner.id, token, nickname: owner.nickname };
  }
  const { results } = await db
    .prepare(
      'SELECT day FROM device_days WHERE device_hash = ? AND day >= ? ORDER BY day',
    )
    .bind(device, turkeyDayIndex(now) - 1)
    .all();
  return json(200, { account, days: results.map((r) => r.day) });
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
      const cup = /^\/v1\/tournament\/rooms\/([^/]+)$/.exec(path);
      if (cup) return await connectTournament(request, env, cup[1]);
      if (path === '' || path === '/v1') return json(200, { ok: true });
      throw new HttpError(404, 'not_found');
    }
    if (request.method === 'POST') {
      switch (path) {
        case '/v1/register':
          return await register(request, env, now);
        case '/v1/rename':
          return await rename(request, env, now);
        case '/v1/submit':
          return await submit(request, env, now, fetchFn);
        case '/v1/delete':
          return await remove(request, env);
        case '/v1/device':
          return await deviceStatus(request, env, now);
        case '/v1/duel/rooms':
          return await createRoom(request, env);
        case '/v1/tournament/rooms':
          return await createTournament(request, env);
      }
      throw new HttpError(404, 'not_found');
    }
    throw new HttpError(405, 'method_not_allowed');
  } catch (e) {
    if (e instanceof HttpError) {
      return json(e.status, { error: e.code, ...e.extra });
    }
    console.error(e);
    return json(500, { error: 'server_error' });
  }
}

/** Daily clean-up: hashed IPs of the rate limit are kept one day at most. */
export async function cleanUp(env, now = Date.now()) {
  await env.DB.prepare('DELETE FROM register_log WHERE at < ?')
    .bind(now - 24 * HOUR_MS)
    .run();
  // Scores are accepted up to yesterday: older device days are not needed.
  await env.DB.prepare('DELETE FROM device_days WHERE day < ?')
    .bind(turkeyDayIndex(now) - 2)
    .run();
}

/**
 * Ties an account from an app older than 1.0.3 to its device, unless the
 * device already belongs to another account.
 */
async function claimDevice(db, playerId, device) {
  await db
    .prepare(
      `UPDATE players SET device_hash = ?1 WHERE id = ?2 AND device_hash IS NULL
         AND NOT EXISTS (SELECT 1 FROM players WHERE device_hash = ?1)`,
    )
    .bind(device, playerId)
    .run();
}

export default {
  fetch: (request, env) => handle(request, env),
  scheduled: (_event, env, ctx) => ctx.waitUntil(cleanUp(env)),
};
