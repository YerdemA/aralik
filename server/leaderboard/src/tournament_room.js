// One tournament room: a Durable Object named after its code.
//
// Like duel_room.js: WebSocket Hibernation (an idle room costs nothing),
// the state in storage, each socket remembers its player id, the alarm
// drives the clock. The rules are in tournament.js.

import { DurableObject } from 'cloudflare:workers';
import { loadContent } from './content.js';
import { turkeyDayIndex } from './days.js';
import { pickDuelQuestions, randomInt, secret } from './duel.js';
import * as tournament from './tournament.js';

const DEFAULT_CONTENT_BASE = 'https://yerdema.github.io/aralik/content/';
const MAX_MESSAGE_BYTES = 512;

export class TournamentRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
  }

  content(now) {
    return loadContent(
      this.env.CONTENT_BASE ?? DEFAULT_CONTENT_BASE,
      fetch,
      now,
    );
  }

  async fetch(request) {
    const url = new URL(request.url);
    const now = Date.now();
    if (url.pathname === '/create') {
      return this.ctx.blockConcurrencyWhile(async () => {
        const state = await this.ctx.storage.get('state');
        if (!tournament.isFree(state, now)) {
          return new Response(null, { status: 409 });
        }
        await this.ctx.storage.deleteAll();
        await this.apply(
          tournament.createRoom(url.searchParams.get('code'), now),
        );
        return new Response(null, { status: 201 });
      });
    }
    if (request.headers.get('upgrade') !== 'websocket') {
      return new Response(null, { status: 426 });
    }
    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server);
    await this.ctx.blockConcurrencyWhile(() =>
      this.seat(server, url.searchParams, now),
    );
    return new Response(null, { status: 101, webSocket: client });
  }

  async seat(socket, params, now) {
    const refuse = (code) => {
      socket.send(JSON.stringify({ t: 'error', code }));
      socket.close(4000, code);
    };
    const player = tournament.playerFrom(params);
    if (player.error) return refuse(player.error);
    const state = await this.ctx.storage.get('state');
    const token = params.get('rejoin');
    if (token) {
      // Back after a dropped connection.
      const back = tournament.rejoin(state, token, now);
      if (back.error) return refuse(back.error);
      this.drop(back.id);
      socket.serializeAttachment({ id: back.id });
      return this.apply(back);
    }
    const result = tournament.join(
      state,
      { ...player, token: secret() },
      now,
    );
    if (result.error) return refuse(result.error);
    socket.serializeAttachment({ id: result.id });
    await this.apply(result);
  }

  async webSocketMessage(socket, raw) {
    if (typeof raw !== 'string' || raw.length > MAX_MESSAGE_BYTES) return;
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    const id = socket.deserializeAttachment()?.id;
    if (!Number.isInteger(id)) return;
    const now = Date.now();
    const state = await this.ctx.storage.get('state');
    if (!state) return;
    switch (msg?.t) {
      case 'count':
        return this.apply(tournament.setCount(state, id, msg, now));
      case 'kick':
        return this.apply(tournament.kick(state, id, msg, now));
      case 'start': {
        const content = await this.content(now);
        const today = turkeyDayIndex(now);
        return this.apply(
          tournament.start(state, id, now, (limit, levels) =>
            pickDuelQuestions(content, limit, today, randomInt, levels),
          ),
        );
      }
      case 'lock':
        return this.apply(
          tournament.lock(state, id, msg, now, await this.content(now)),
        );
      case 'next':
        return this.apply(tournament.next(state, id, msg, now));
    }
  }

  /** Closes an older connection of player [id] that has not noticed it is dead. */
  drop(id) {
    for (const s of this.ctx.getWebSockets()) {
      if (s.deserializeAttachment()?.id === id) {
        s.serializeAttachment({});
        try {
          s.close(4002, 'replaced');
        } catch {
          // already closed
        }
      }
    }
  }

  async webSocketClose(socket) {
    await this.left(socket);
  }

  async webSocketError(socket) {
    await this.left(socket);
  }

  async left(socket) {
    const id = socket.deserializeAttachment()?.id;
    if (!Number.isInteger(id)) return;
    socket.serializeAttachment({});
    const now = Date.now();
    const state = await this.ctx.storage.get('state');
    const content =
      state && state.phase !== 'lobby' ? await this.content(now) : null;
    await this.apply(tournament.leave(state, id, now, content));
  }

  async alarm() {
    const now = Date.now();
    const state = await this.ctx.storage.get('state');
    const content =
      state?.phase === 'question' ? await this.content(now) : null;
    await this.apply(tournament.alarm(state, now, content));
  }

  /** Stores the new state, sends its messages, closes and sets the alarm. */
  async apply({ state, out, alarm, close, wipe }) {
    this.send(out);
    if (wipe) {
      for (const s of this.ctx.getWebSockets()) s.close(1000, 'closed');
      await this.ctx.storage.deleteAll();
      return;
    }
    if (state) await this.ctx.storage.put('state', state);
    for (const id of close ?? []) {
      for (const s of this.ctx.getWebSockets()) {
        if (s.deserializeAttachment()?.id === id) {
          s.serializeAttachment({});
          s.close(4001, 'kicked');
        }
      }
    }
    if (alarm === null) await this.ctx.storage.deleteAlarm();
    else if (alarm !== undefined) await this.ctx.storage.setAlarm(alarm);
  }

  send(out) {
    if (!out?.length) return;
    const sockets = this.ctx.getWebSockets();
    for (const { to, msg } of out) {
      const text = JSON.stringify(msg);
      for (const s of sockets) {
        const id = s.deserializeAttachment()?.id;
        if (!Number.isInteger(id)) continue;
        if (to === 'all' || to === id) {
          try {
            s.send(text);
          } catch {
            // closing; webSocketClose handles it
          }
        }
      }
    }
  }
}
