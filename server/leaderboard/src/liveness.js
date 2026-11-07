// Noticing dead connections.
//
// A phone that loses its network (airplane mode, a tunnel, a frozen app)
// does not close its socket: nothing reaches the server, which would keep
// waiting for it forever. So the app pings: every PING_EVERY_MS it sends
// PING, which the Cloudflare runtime answers with PONG by itself (the room
// is not even woken; see setWebSocketAutoResponse) and stamps with the
// time. A room checks those stamps on a timer while someone may be gone and
// closes a connection silent for longer than STALE_MS; from then on it is a
// dropped connection like any other (duel: the clock stops and the player
// may come back; tournament: the match goes on without them).
//
// The app does the same from its side: no word from the room (a pong or
// anything else) for long enough and it drops the connection and comes back.
//
// Only connections that say they ping (?hb=1) are checked: older apps
// (1.0.4) do not, and must not be closed for it.

export const PING = '{"t":"ping"}';
export const PONG = '{"t":"pong"}';

/** How often the app pings (lib/data/duel_client.dart, duelPingEvery). */
export const PING_EVERY_MS = 3_000;

/** Silent longer than this: the connection is dead. */
export const STALE_MS = 10_000;

/** How often a room in play checks; a room waiting for players checks
 * less often. */
export const CHECK_MS = 4_000;
export const IDLE_CHECK_MS = 15_000;

/** Whether the connection's query says the app pings. */
export function pings(params) {
  return params.get('hb') === '1';
}

/**
 * Whether a pinging connection seated at [seatedAt] (ms) whose last pong
 * went out at [pongAt] (ms, or null for none yet) is dead at [now].
 */
export function isStale(seatedAt, pongAt, now) {
  return now - Math.max(seatedAt ?? 0, pongAt ?? 0) > STALE_MS;
}

/**
 * When a room's alarm should go off: its rules' own time [due] (ms, or
 * null), or sooner for a check [every] ms from [now] (null: no check).
 */
export function nextAlarm(due, every, now) {
  const check = every === null ? null : now + every;
  if (due === null || due === undefined) return check;
  if (check === null) return due;
  return Math.min(due, check);
}
