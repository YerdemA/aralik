/**
 * Quick reactions in duels and tournaments (2026-11-16): four mascot faces
 * and four fixed messages, nothing typed, so there is nothing to moderate.
 * The app sends {t: 'react', r: ID}; the room passes it on to the other
 * players as {t: 'react', seat|id, r: ID}. Older apps ignore the message.
 * The ids are the same as lib/core/reaction.dart (Reaction.id).
 */

export const REACTIONS = new Set([
  'angry', 'laugh', 'sad', 'wow',
  'easy', 'close', 'lucky', 'congrats',
]);

/** At least this long between two reactions of one player. */
export const REACT_GAP_MS = 1500;
/** At most REACT_MAX reactions in any REACT_WINDOW_MS. */
export const REACT_WINDOW_MS = 60_000;
export const REACT_MAX = 12;

/**
 * Whether a player who sent reactions at [times] (ms, oldest first) may send
 * [id] at [now]; returns the times to keep.
 */
export function allowReaction(times, id, now) {
  const recent = (Array.isArray(times) ? times : []).filter(
    (t) => Number.isFinite(t) && now - t < REACT_WINDOW_MS && t <= now,
  );
  if (!REACTIONS.has(id)) return { ok: false, times: recent };
  const last = recent.at(-1);
  if (last !== undefined && now - last < REACT_GAP_MS) return { ok: false, times: recent };
  if (recent.length >= REACT_MAX) return { ok: false, times: recent };
  return { ok: true, times: [...recent, now] };
}
