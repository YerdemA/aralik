// The lobby for random opponents: one Durable Object ("lobby") that every
// "find an opponent" connection goes to.
//
// A newcomer is paired with the longest-waiting player: the lobby opens a
// room, tells both {t: 'matched', code} and closes their sockets; the apps
// then join the room like friends do. Nobody waiting: the newcomer gets
// {t: 'searching'} and waits. Uses WebSocket Hibernation, so a quiet lobby
// costs nothing; each socket remembers its player and when it came.

import { DurableObject } from 'cloudflare:workers';
import { playerFrom } from './duel.js';
import { openRoom } from './rooms.js';

/** Waiting longer than this closes the socket (the app may search again). */
export const SEARCH_TIMEOUT_MS = 2 * 60_000;

export class DuelLobby extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
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
      await this.ctx.blockConcurrencyWhile(() => this.arrive(socket));
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  /** Pairs [socket] with the longest-waiting player, or lets it wait. */
  async arrive(socket) {
    const now = Date.now();
    const waiting = this.ctx
      .getWebSockets()
      .filter((s) => s !== socket && s.deserializeAttachment()?.since)
      .sort(
        (a, b) =>
          a.deserializeAttachment().since - b.deserializeAttachment().since,
      );
    for (const other of waiting) {
      if (now - other.deserializeAttachment().since > SEARCH_TIMEOUT_MS) {
        this.drop(other, 'timeout');
        continue;
      }
      const code = await openRoom(this.env);
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
    socket.serializeAttachment({ since: now });
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
