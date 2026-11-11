// The archive tab of the app's leaderboard (2026-11-11): who led each of
// the last ARCHIVE_DAYS finished days, and the top ARCHIVE_DUEL_TOP of
// the month that ended in both duel tables. Names, mascots and the
// numbers only; hidden players are left out, so the next one leads.
//
// A day's mascot is the one sent with that day's score (scores.look,
// apps from 1.1.6 on); older apps send none, so the player's latest duel
// mascot stands in, and the app draws the philosopher when there is
// neither.

import * as ranked from './ranked.js';

export const ARCHIVE_DAYS = 7;
export const ARCHIVE_DUEL_TOP = 3;

/** The leader of each finished day of the last week, newest first. */
export async function dayLeaders(db, today) {
  const from = Math.max(0, today - ARCHIVE_DAYS);
  const to = today - 1;
  if (to < from) return [];
  const { results } = await db
    .prepare(
      `SELECT day, nickname, look, points FROM (
         SELECT s.day, p.nickname, s.points,
                COALESCE(s.look, (
                  SELECT r.look FROM duel_ratings r
                   WHERE r.player_id = s.player_id AND r.look IS NOT NULL
                   ORDER BY r.updated_at DESC LIMIT 1)) AS look,
                ROW_NUMBER() OVER (
                  PARTITION BY s.day
                  ORDER BY s.points DESC, s.submitted_at ASC, s.player_id ASC
                ) AS place
           FROM scores s JOIN players p ON p.id = s.player_id
          WHERE s.day BETWEEN ? AND ? AND p.hidden = 0)
        WHERE place = 1
        ORDER BY day DESC`,
    )
    .bind(from, to)
    .all();
  return results.map((r) => ({
    day: r.day,
    nickname: r.nickname,
    points: r.points,
    look: r.look ?? null,
  }));
}

/** The first [ARCHIVE_DUEL_TOP] of [month]'s duel table in each mode. */
export async function duelPodiums(db, month) {
  const podium = async (mode) =>
    (await ranked.table(db, month, mode, null, ARCHIVE_DUEL_TOP)).top.map(
      (r) => ({
        rank: r.rank,
        nickname: r.nickname,
        rating: r.rating,
        look: r.look,
      }),
    );
  return { bank: await podium('bank'), math: await podium('math') };
}

/** The whole archive as of [today] (day index) and [month] (YYYYMM). */
export async function archive(db, today, month) {
  const previous = ranked.previousMonth(month);
  return {
    days: await dayLeaders(db, today),
    month: previous,
    duels: await duelPodiums(db, previous),
  };
}
