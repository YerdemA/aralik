// The lobby for random opponents: one Durable Object ("lobby") that every
// "find an opponent" connection goes to.
//
// A newcomer is paired with the longest-waiting player: the lobby opens a
// room, tells both {t: 'matched', code} and closes their sockets; the apps
// then join the room like friends do. Nobody waiting: the newcomer gets
// {t: 'searching'} and waits. Uses WebSocket Hibernation, so a quiet lobby
// costs nothing; each socket remembers its player and when it came.
// A searcher whose connection went silent (no network; liveness.js) is
// passed over and closed instead of being matched with someone.

import { DurableObject } from 'cloudflare:workers';
import { playerFrom } from './duel.js';
import { isStale, PING, PONG, pings } from './liveness.js';
import { openRoom } from './rooms.js';

/** 'math' for a math duel, else 'bank' (each has its own lobby). */
export function duelMode(params) {
  return params.get('mode') === 'math' ? 'math' : 'bank';
}

/** Waiting longer than this closes the socket (the app may search again). */
export const SEARCH_TIMEOUT_MS = 2 * 60_000;

export class DuelLobby extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair(PING, PONG),
    );
  }

  async fetch(request) {
    const url = new URL(request.url);
    const [client, socket] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(socket);
    const player = playerFrom(url.searchParams);
    if (player.error) {
      socket.send(JSON.stringify({ t: 'error', code: player.error }));
      socket.close(4000, player.error);
    } else {
      await this.ctx.blockConcurrencyWhile(() =>
        this.arrive(socket, pings(url.searchParams), duelMode(url.searchParams)),
      );
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  /** Pairs [socket] with the longest-waiting player, or lets it wait. */
  async arrive(socket, hb, mode = 'bank') {
    const now = Date.now();
    const waiting = this.ctx
      .getWebSockets()
      .filter((s) => s !== socket && s.deserializeAttachment()?.since)
      .sort(
        (a, b) =>
          a.deserializeAttachment().since - b.deserializeAttachment().since,
      );
    for (const other of waiting) {
      const { since, hb: pinging } = other.deserializeAttachment();
      if (now - since > SEARCH_TIMEOUT_MS) {
        this.drop(other, 'timeout');
        continue;
      }
      const pong = this.ctx.getWebSocketAutoResponseTimestamp(other);
      if (pinging && isStale(since, pong?.getTime() ?? null, now)) {
        this.drop(other, 'gone'); // no network any more: not a partner
        continue;
      }
      const code = await openRoom(this.env, undefined, undefined, mode);
      if (!code) break;
      const matched = JSON.stringify({ t: 'matched', code });
      try {
        other.send(matched);
      } catch {
        this.drop(other, 'gone'); // closed meanwhile: try the next one
        continue;
      }
      this.drop(other, 'matched');
      socket.send(matched);
      this.drop(socket, 'matched');
      return;
    }
    socket.serializeAttachment({ since: now, hb });
    socket.send(JSON.stringify({ t: 'searching' }));
    await this.ctx.storage.setAlarm(now + SEARCH_TIMEOUT_MS);
  }

  drop(socket, reason) {
    socket.serializeAttachment({});
    try {
      socket.close(1000, reason);
    } catch {
      // already closed
    }
  }

  webSocketMessage() {
    // The lobby only talks.
  }

  webSocketClose(socket) {
    socket.serializeAttachment({});
  }

  webSocketError(socket) {
    socket.serializeAttachment({});
  }

  /** Closes searches that waited too long. */
  async alarm() {
    const now = Date.now();
    let next = null;
    for (const s of this.ctx.getWebSockets()) {
      const since = s.deserializeAttachment()?.since;
      if (!since) continue;
      if (now - since >= SEARCH_TIMEOUT_MS) {
        try {
          s.send(JSON.stringify({ t: 'error', code: 'no_opponent' }));
        } catch {
          // gone
        }
        this.drop(s, 'timeout');
      } else {
        next = Math.min(next ?? Infinity, since + SEARCH_TIMEOUT_MS);
      }
    }
    if (next !== null) await this.ctx.storage.setAlarm(next);
  }
}
