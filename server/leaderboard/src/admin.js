// The moderation panel's API (public/admin.html, served at /admin on the
// API host). The same work as scripts/admin.mjs, from a browser.
//
// Every request carries `Authorization: Bearer <ADMIN_TOKEN>`; the token is
// a Worker secret (`npx wrangler secret put ADMIN_TOKEN`, 32+ random
// characters). Without the secret the panel and its API do not exist (404).
// Wrong tokens count against the per-IP limit (DUEL_LIMITER).
//
//   GET  /v1/admin/reports                 names reported in the last 7 days
//   GET  /v1/admin/suspects?days=3         suspect scores of the last days
//   GET  /v1/admin/players?q=AD            players whose name starts with AD
//   GET  /v1/admin/banned                  banned names
//   POST /v1/admin/action {action, name}   hide | unhide | ban | unban | dismiss
//
// dismiss: the reports were not right; they are deleted and the player is
// shown again (unless banned).

import { turkeyDayIndex } from './days.js';
import { cleanNickname, nicknameKey } from './nickname.js';

const ACTIONS = new Set(['hide', 'unhide', 'ban', 'unban', 'dismiss']);
const MIN_TOKEN_LENGTH = 24;

export class AdminError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

async function digest(text) {
  return new Uint8Array(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)),
  );
}

/** Whether the panel is switched on: a long enough ADMIN_TOKEN secret. */
export function adminEnabled(env) {
  return typeof env.ADMIN_TOKEN === 'string' && env.ADMIN_TOKEN.length >= MIN_TOKEN_LENGTH;
}

/**
 * Whether [request] carries the admin token. Hashes are compared in
 * constant time so the answer's timing tells nothing about the token.
 */
export async function isAdmin(request, env) {
  if (!adminEnabled(env)) return false;
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer (.+)$/.exec(header);
  if (!match) return false;
  const [a, b] = await Promise.all([digest(match[1]), digest(env.ADMIN_TOKEN)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function keyOf(raw) {
  const name = typeof raw === 'string' ? cleanNickname(raw) : null;
  if (!name) throw new AdminError(400, 'bad_name');
  return { name, key: nicknameKey(name) };
}

export async function reports(db) {
  const { results } = await db
    .prepare(
      `SELECT MAX(r.nickname) AS nickname, r.name_key AS key, COUNT(*) AS reports,
              GROUP_CONCAT(DISTINCT r.place) AS places, MAX(r.at) AS last,
              p.nickname AS player, COALESCE(p.hidden, 0) AS hidden,
              EXISTS (SELECT 1 FROM banned_names b WHERE b.name_key = r.name_key) AS banned
         FROM reports r LEFT JOIN players p ON p.nickname_key = r.name_key
        GROUP BY r.name_key ORDER BY reports DESC, last DESC LIMIT 200`,
    )
    .all();
  return results.map((r) => ({
    name: r.player ?? r.nickname,
    reports: r.reports,
    places: r.places ? String(r.places).split(',') : [],
    last: r.last,
    player: r.player !== null,
    hidden: r.hidden === 1,
    banned: r.banned === 1,
  }));
}

export async function suspects(db, days, now) {
  const span = Math.min(30, Math.max(1, Number.isFinite(days) ? days : 3));
  const from = turkeyDayIndex(now) - (span - 1);
  const { results } = await db
    .prepare(
      `SELECT s.day, p.nickname, s.points, s.hits, p.hidden
         FROM scores s JOIN players p ON p.id = s.player_id
        WHERE s.suspect = 1 AND s.day >= ?
        ORDER BY s.day DESC, s.points DESC LIMIT 200`,
    )
    .bind(from)
    .all();
  return results.map((r) => ({
    day: r.day,
    name: r.nickname,
    points: r.points,
    hits: r.hits,
    hidden: r.hidden === 1,
  }));
}

export async function players(db, query) {
  // The start of a name, folded the way names are kept unique, so "şey"
  // finds "Şeyma".
  const prefix =
    typeof query === 'string' ? nicknameKey(query.normalize('NFC').trim()).slice(0, 16) : '';
  if (!prefix) return [];
  const { results } = await db
    .prepare(
      `SELECT p.nickname, p.hidden, p.created_at,
              (SELECT COUNT(*) FROM scores s WHERE s.player_id = p.id) AS days,
              EXISTS (SELECT 1 FROM banned_names b WHERE b.name_key = p.nickname_key) AS banned
         FROM players p WHERE substr(p.nickname_key, 1, ?) = ?
        ORDER BY p.nickname_key LIMIT 50`,
    )
    .bind(prefix.length, prefix)
    .all();
  return results.map((r) => ({
    name: r.nickname,
    hidden: r.hidden === 1,
    banned: r.banned === 1,
    joined: r.created_at,
    days: r.days,
  }));
}

export async function banned(db) {
  const { results } = await db
    .prepare(
      `SELECT b.name_key AS key, b.at, p.nickname
         FROM banned_names b LEFT JOIN players p ON p.nickname_key = b.name_key
        ORDER BY b.at DESC LIMIT 200`,
    )
    .all();
  return results.map((r) => ({ name: r.nickname ?? r.key, at: r.at }));
}

/** Applies one moderation [action] to the name [raw]; returns the new state. */
export async function act(db, action, raw, now) {
  if (!ACTIONS.has(action)) throw new AdminError(400, 'bad_action');
  const { key } = keyOf(raw);
  const run = (sql, ...params) => db.prepare(sql).bind(...params).run();
  switch (action) {
    case 'hide':
    case 'unhide':
      await run(
        'UPDATE players SET hidden = ? WHERE nickname_key = ?',
        action === 'hide' ? 1 : 0,
        key,
      );
      break;
    case 'ban':
      await run(
        'INSERT OR IGNORE INTO banned_names (name_key, at) VALUES (?, ?)',
        key,
        now,
      );
      await run('UPDATE players SET hidden = 1 WHERE nickname_key = ?', key);
      break;
    case 'unban':
      await run('DELETE FROM banned_names WHERE name_key = ?', key);
      await run('DELETE FROM reports WHERE name_key = ?', key);
      await run('UPDATE players SET hidden = 0 WHERE nickname_key = ?', key);
      break;
    case 'dismiss':
      await run('DELETE FROM reports WHERE name_key = ?', key);
      await run(
        `UPDATE players SET hidden = 0 WHERE nickname_key = ?1
           AND NOT EXISTS (SELECT 1 FROM banned_names WHERE name_key = ?1)`,
        key,
      );
      break;
  }
  const player = await db
    .prepare('SELECT nickname, hidden FROM players WHERE nickname_key = ?')
    .bind(key)
    .first();
  const ban = await db
    .prepare('SELECT 1 AS b FROM banned_names WHERE name_key = ?')
    .bind(key)
    .first();
  return {
    name: player?.nickname ?? raw,
    player: player !== null,
    hidden: player?.hidden === 1,
    banned: ban !== null,
  };
}
