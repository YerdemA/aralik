// Day numbering, as in lib/core/daily.dart: day 0 is 2026-11-01.
// The server counts days in Turkey time (UTC+3, no DST); players in other
// zones are covered by accepting one day either side.

const EPOCH_UTC = Date.UTC(2026, 10, 1);
const TURKEY_OFFSET_MS = 3 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

export const QUESTIONS_PER_DAY = 5;

export function turkeyDayIndex(nowMs) {
  return Math.floor((nowMs + TURKEY_OFFSET_MS - EPOCH_UTC) / DAY_MS);
}

/** Days a score may be sent for: yesterday, today and tomorrow. */
export function acceptsDay(day, nowMs) {
  const today = turkeyDayIndex(nowMs);
  return Number.isInteger(day) && Math.abs(day - today) <= 1;
}

/** Days readable on the board: anything up to tomorrow. */
export function readableDay(day, nowMs) {
  return Number.isInteger(day) && day <= turkeyDayIndex(nowMs) + 1;
}
