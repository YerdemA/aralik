// The published question bank and schedule (GitHub Pages, docs/content/).
// Scores are computed from these, never taken from the app.

import { QUESTIONS_PER_DAY } from './days.js';

const MANIFEST_TTL_MS = 5 * 60 * 1000;

/** Content loaded per isolate, refreshed when the manifest version moves. */
let cache = null; // { version, checkedAt, questions: Map, days: string[][] }

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
      bank.map((q) => [q.id, { answer: q.answer, kind: q.kind }]),
    ),
    days: schedule.days,
  };
  return cache;
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
