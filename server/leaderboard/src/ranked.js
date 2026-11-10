// Monthly ranked duels: the rules as pure functions, and the D1 queries.
//
// Only duels with a random opponent count, and only when both players
// joined the leaderboard (their account is checked when they take their
// seat: ?pid=…&ptok=…). Only a room's first round counts, not rematches,
// so two friends who happen to meet cannot farm points off each other.
// Knowledge duels ('bank') and math duels ('math') have separate tables.
//
// Each month starts everyone at START. After a duel both ratings move by
// Elo (the favourite gains less for a win and loses more for a loss),
// scaled by the margin of the match: a crushing win moves them up to
// MARGIN_MAX times, a razor-thin one MARGIN_MIN times. A forfeit
// (resigning, leaving) counts at the plain size. Ratings never go below
// FLOOR.
//
// Kept per month, mode and player: rating, duels played, won, drawn, the
// sum of the player's match totals (for the average), hits and questions
// answered (hit rate), and the mascot code last used (for the month-end
// card). Two months are kept (the one that just ended is shown when the
// next begins); cleanUp deletes older ones.

import { turkeyDate } from './days.js';
import { isRanked } from './duel.js';

export const START = 1000;
export const FLOOR = 0;
export const K = 32;
export const MARGIN_MIN = 0.5;
export const MARGIN_MAX = 2;
/** The point difference at which the margin factor tops out. */
export const MARGIN_FULL_AT = 300;

/** The month of [now] in Turkey as YYYYMM (e.g. 202611). */
export function monthOf(now) {
  const d = turkeyDate(now);
  return d.year * 100 + d.month;
}

/** The month before [month] (YYYYMM). */
export function previousMonth(month) {
  const y = Math.floor(month / 100);
  const m = month % 100;
  return m === 1 ? (y - 1) * 100 + 12 : y * 100 + m - 1;
}

/** A valid YYYYMM, or null. */
export function parseMonth(raw) {
  const n = Number(raw);
  if (!Number.isInteger(n)) return null;
  const m = n % 100;
  return n >= 202601 && n <= 209912 && m >= 1 && m <= 12 ? n : null;
}

/** Elo's expected score of a player rated [a] against one rated [b]. */
export function expected(a, b) {
  return 1 / (1 + 10 ** ((b - a) / 400));
}

/**
 * How much the margin scales the change: MARGIN_MIN for a draw-like
 * finish up to MARGIN_MAX at MARGIN_FULL_AT points apart; 1 for a
 * forfeit.
 */
export function marginFactor(totals, forfeit) {
  if (forfeit) return 1;
  const diff = Math.min(Math.abs(totals[0] - totals[1]), MARGIN_FULL_AT);
  return MARGIN_MIN + ((MARGIN_MAX - MARGIN_MIN) * diff) / MARGIN_FULL_AT;
}

/**
 * The new ratings after a duel between [ratings] (by seat). [winner] is
 * 0, 1 or null (draw); [totals] the match points; [forfeit] when it did
 * not end by playing every question.
 */
export function rate(ratings, winner, totals, forfeit = false) {
  const factor = winner === null ? 1 : marginFactor(totals, forfeit);
  return [0, 1].map((seat) => {
    const score = winner === null ? 0.5 : winner === seat ? 1 : 0;
    const change = Math.round(
      K * factor * (score - expected(ratings[seat], ratings[1 - seat])),
    );
    return Math.max(FLOOR, ratings[seat] + change);
  });
}

/** Each seat's line of a finished duel: totals, hits, questions. */
export function matchLines(state) {
  return [0, 1].map((seat) => ({
    points: state.totals[seat],
    hits: state.results.filter((pair) => pair[seat]?.hit).length,
    answered: state.results.length,
  }));
}

/**
 * Whether a finished room's duel counts: a ranked room, its first round,
 * two different verified accounts, and at least one question revealed or
 * a forfeit.
 */
export function counts(state) {
  if (!state || state.phase !== 'over' || state.rated) return false;
  if (!isRanked(state)) return false;
  return state.results.length > 0 || state.reason !== 'done';
}

// --- D1 ---

async function sha256(text) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(text),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * The leaderboard account behind a duel connection's ?pid=…&ptok=…, as its
 * id, or null (none sent, unknown, wrong token). Errors count as none: the
 * duel is then simply not ranked.
 */
export async function accountOf(db, params) {
  const id = params.get('pid');
  const token = params.get('ptok');
  if (!db || !id || !token || id.length > 64 || token.length > 128) return null;
  try {
    const row = await db
      .prepare('SELECT token_hash FROM players WHERE id = ?')
      .bind(id)
      .first();
    return row && row.token_hash === (await sha256(token)) ? id : null;
  } catch {
    return null;
  }
}

/** A player's row this month, or a fresh one. */
async function rowOf(db, month, mode, playerId) {
  const row = await db
    .prepare(
      'SELECT rating, played, won, drawn, points, hits, answered FROM duel_ratings WHERE month = ? AND mode = ? AND player_id = ?',
    )
    .bind(month, mode, playerId)
    .first();
  return (
    row ?? {
      rating: START,
      played: 0,
      won: 0,
      drawn: 0,
      points: 0,
      hits: 0,
      answered: 0,
    }
  );
}

/**
 * Records a finished ranked duel and returns both seats' {before, after}
 * ratings, or null when it does not count.
 */
export async function record(db, state, now) {
  if (!counts(state)) return null;
  const month = monthOf(now);
  const mode = state.mode === 'math' ? 'math' : 'bank';
  const rows = await Promise.all(
    state.players.map((p) => rowOf(db, month, mode, p.pid)),
  );
  const before = rows.map((r) => r.rating);
  const after = rate(before, state.winner, state.totals, state.reason !== 'done');
  const lines = matchLines(state);
  await db.batch(
    state.players.map((p, seat) =>
      db
        .prepare(
          `INSERT INTO duel_ratings
             (month, mode, player_id, rating, played, won, drawn, points, hits, answered, look, updated_at)
           VALUES (?1, ?2, ?3, ?4, 1, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
           ON CONFLICT (month, mode, player_id) DO UPDATE SET
             rating = ?4,
             played = played + 1,
             won = won + ?5,
             drawn = drawn + ?6,
             points = points + ?7,
             hits = hits + ?8,
             answered = answered + ?9,
             look = COALESCE(?10, look),
             updated_at = ?11`,
        )
        .bind(
          month,
          mode,
          p.pid,
          after[seat],
          state.winner === seat ? 1 : 0,
          state.winner === null ? 1 : 0,
          lines[seat].points,
          lines[seat].hits,
          lines[seat].answered,
          p.look ?? null,
          now,
        ),
    ),
  );
  return before.map((b, seat) => ({ before: b, after: after[seat] }));
}

/** A row as the app sees it. */
function shown(row, rank) {
  return {
    rank,
    nickname: row.nickname,
    rating: row.rating,
    played: row.played,
    won: row.won,
    drawn: row.drawn,
    // The average match total, and the share of hit intervals.
    average: row.played ? Math.round(row.points / row.played) : 0,
    hitRate: row.answered ? Math.round((100 * row.hits) / row.answered) : 0,
    look: row.look ?? null,
  };
}

/**
 * The month's table: its top [limit], the number of players, and the
 * viewer's own line and place (also when hidden by moderation, like the
 * daily board). Ties: the earlier to get there first.
 */
export async function table(db, month, mode, viewerId, limit) {
  const visible = 'p.hidden = 0';
  const { results } = await db
    .prepare(
      `SELECT r.*, p.nickname FROM duel_ratings r JOIN players p ON p.id = r.player_id
        WHERE r.month = ? AND r.mode = ? AND ${visible}
        ORDER BY r.rating DESC, r.updated_at, r.player_id LIMIT ?`,
    )
    .bind(month, mode, limit)
    .all();
  const count = await db
    .prepare(
      `SELECT COUNT(*) AS n FROM duel_ratings r JOIN players p ON p.id = r.player_id
        WHERE r.month = ? AND r.mode = ? AND ${visible}`,
    )
    .bind(month, mode)
    .first();
  let me = null;
  if (viewerId) {
    const row = await db
      .prepare(
        `SELECT r.*, p.nickname FROM duel_ratings r JOIN players p ON p.id = r.player_id
          WHERE r.month = ? AND r.mode = ? AND r.player_id = ?`,
      )
      .bind(month, mode, viewerId)
      .first();
    if (row) {
      const above = await db
        .prepare(
          `SELECT COUNT(*) AS n FROM duel_ratings r JOIN players p ON p.id = r.player_id
            WHERE r.month = ?1 AND r.mode = ?2 AND ${visible} AND r.player_id != ?3
              AND (r.rating > ?4 OR (r.rating = ?4 AND (r.updated_at < ?5
                OR (r.updated_at = ?5 AND r.player_id < ?3))))`,
        )
        .bind(month, mode, viewerId, row.rating, row.updated_at)
        .first();
      me = shown(row, above.n + 1);
    }
  }
  return {
    month,
    mode,
    players: count.n,
    top: results.map((r, i) => shown(r, i + 1)),
    me,
  };
}

/** Deletes months older than the one before [now]'s. */
export async function cleanUp(db, now) {
  await db
    .prepare('DELETE FROM duel_ratings WHERE month < ?')
    .bind(previousMonth(monthOf(now)))
    .run();
}
