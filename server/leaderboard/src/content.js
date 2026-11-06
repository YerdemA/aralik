// The published question bank and schedule (GitHub Pages, docs/content/).
// Scores are computed from these, never taken from the app.

import { QUESTIONS_PER_DAY } from './days.js';
import { scaleOf } from './scoring.js';

const MANIFEST_TTL_MS = 5 * 60 * 1000;

/** Content loaded per isolate, refreshed when the manifest version moves. */
// { version, checkedAt, questions: Map id → {answer, kind, difficulty, retired},
//   order: string[] (bank order), days: string[][] }
let cache = null;

export function resetContentCache() {
  cache = null;
}

async function getJson(fetchFn, url) {
  const response = await fetchFn(url, { cf: { cacheTtl: 300 } });
  if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
  return response.json();
}

export async function loadContent(base, fetchFn, nowMs) {
  if (cache && nowMs - cache.checkedAt < MANIFEST_TTL_MS) return cache;
  const manifest = await getJson(fetchFn, new URL('manifest.json', base));
  if (cache && cache.version === manifest.version) {
    cache.checkedAt = nowMs;
    cache.scoringV2Day = scoringDay(manifest);
    return cache;
  }
  const [bank, schedule] = await Promise.all([
    getJson(fetchFn, new URL(manifest.questions, base)),
    getJson(fetchFn, new URL(manifest.schedule, base)),
  ]);
  cache = {
    version: manifest.version,
    checkedAt: nowMs,
    questions: new Map(
      bank.map((q) => [
        q.id,
        {
          answer: q.answer,
          kind: q.kind,
          category: q.category,
          difficulty: q.difficulty ?? 2,
          retired: q.retired === true,
        },
      ]),
    ),
    order: bank.map((q) => q.id),
    scoringV2Day: scoringDay(manifest),
    days: schedule.days,
  };
  return cache;
}

/** First day of the scaled rule (`scoring_v2_day`), or null. */
function scoringDay(manifest) {
  return Number.isInteger(manifest.scoring_v2_day)
    ? manifest.scoring_v2_day
    : null;
}

/** Whether [day] uses the scaled rule (lib/core/answer_scale.dart). */
export function scaledOn(content, day) {
  return content.scoringV2Day !== null && content.scoringV2Day !== undefined
    && day >= content.scoringV2Day;
}

/** The scale of [q] on [day], or null under the first rule. */
export function scaleOn(content, q, day) {
  return scaledOn(content, day) ? scaleOf(q.kind, q.category, q.answer) : null;
}

function mod(a, n) {
  return ((a % n) + n) % n;
}

/**
 * Whether [ids] are the daily set of [day]. The app wraps around a
 * schedule that ran out (`days[day % length]`, see Schedule.idsFor), and an
 * app may still hold an older, shorter schedule; the published one only
 * ever grows, so every earlier length is tried too.
 */
export function isDailySet(days, day, ids) {
  if (ids.length !== QUESTIONS_PER_DAY) return false;
  for (let length = days.length; length >= 1; length--) {
    const set = days[mod(day, length)];
    if (set.length === ids.length && set.every((id, i) => id === ids[i])) {
      return true;
    }
  }
  return false;
}

/**
 * Ids of the [horizon] days starting with [today], wrapping like the app's
 * Schedule.upcomingIds: questions kept away from free play and duels so
 * the next daily sets are not spoiled.
 */
export function upcomingIds(days, today, horizon = 60) {
  const ids = new Set();
  if (days.length === 0) return ids;
  for (let d = today; d < today + horizon && d < today + days.length; d++) {
    for (const id of days[mod(d, days.length)]) ids.add(id);
  }
  return ids;
}
