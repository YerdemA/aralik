// One duel room: a Durable Object named after its code.
//
// Uses the WebSocket Hibernation API, so an idle room (players thinking)
// costs nothing: the state lives in storage, each socket remembers its seat,
// and the alarm drives the clock. The rules are in duel.js.
//
// The alarm does two jobs: the rules' own times (stored as 'due') and, while
// someone may be gone, a check for connections that went silent
// (liveness.js); whichever comes first.

import { DurableObject } from 'cloudflare:workers';
import { loadContent } from './content.js';
import { turkeyDayIndex } from './days.js';
import * as duel from './duel.js';
import {
  CHECK_MS,
  IDLE_CHECK_MS,
  isStale,
  nextAlarm,
  PING,
  PONG,
  pings,
} from './liveness.js';

const DEFAULT_CONTENT_BASE = 'https://yerdema.github.io/aralik/content/';
const MAX_MESSAGE_BYTES = 512;

export class DuelRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.env = env;
    // Answered by the runtime itself, without waking the room.
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair(PING, PONG),
    );
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
        if (!duel.isFree(state, now)) return new Response(null, { status: 409 });
        const code = url.searchParams.get('code');
        await this.ctx.storage.deleteAll();
        await this.apply(duel.createRoom(code, now));
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
    const player = duel.playerFrom(params);
    if (player.error) return refuse(player.error);
    const { name, bank, rematch } = player;
    const seat = (n) =>
      socket.serializeAttachment({ seat: n, hb: pings(params), at: now });

    const state = await this.ctx.storage.get('state');
    const token = params.get('rejoin');
    if (token && params.get('resign') === '1') {
      // Left the app mid-duel and gave up from the home screen.
      const gone = duel.resignWith(state, token, now);
      if (gone.error) return refuse(gone.error);
      this.drop(gone.seat);
      seat(gone.seat);
      return this.apply(gone);
    }
    if (token) {
      // Back after a dropped connection.
      const back = duel.rejoin(state, token, now);
      if (back.error) return refuse(back.error);
      this.drop(back.seat);
      seat(back.seat);
      return this.apply(back);
    }
    let content;
    try {
      content = await this.content(now);
    } catch {
      return refuse('server_error');
    }
    const today = turkeyDayIndex(now);
    const result = duel.join(
      state,
      { name, bank, token: duel.secret(), rematch },
      now,
      (limit) => duel.pickDuelQuestions(content, limit, today, duel.randomInt),
    );
    if (result.error) return refuse(result.error);
    seat(result.seat);
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
    const seat = socket.deserializeAttachment()?.seat;
    if (seat !== 0 && seat !== 1) return;
    const now = Date.now();
    const state = await this.ctx.storage.get('state');
    if (!state) return;
    if (msg?.t === 'lock') {
      const content = await this.content(now);
      await this.apply(duel.lock(state, seat, msg, now, content));
    } else if (msg?.t === 'next') {
      await this.apply(duel.next(state, seat, msg, now));
    } else if (msg?.t === 'resign') {
      await this.apply(duel.resign(state, seat, now));
    } else if (msg?.t === 'rematch') {
      let content;
      try {
        content = await this.content(now);
      } catch {
        return;
      }
      const today = turkeyDayIndex(now);
      const pick = (limit, exclude) =>
        duel.pickDuelQuestions(
          content,
          limit,
          today,
          duel.randomInt,
          duel.DUEL_LEVELS,
          exclude,
        );
      await this.apply(duel.rematch(state, seat, now, pick, duel.secret));
    } else if (msg?.t === 'rematch_no') {
      await this.apply(duel.declineRematch(state, seat));
    }
  }

  /** Closes an older connection of [seat] that has not noticed it is dead. */
  drop(seat) {
    for (const s of this.ctx.getWebSockets()) {
      if (s.deserializeAttachment()?.seat === seat) {
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
    const seat = socket.deserializeAttachment()?.seat;
    if (seat !== 0 && seat !== 1) return;
    socket.serializeAttachment({});
    const state = await this.ctx.storage.get('state');
    await this.apply(duel.leave(state, seat, Date.now()));
  }

  /**
   * Closes the connections that went silent (no network) and treats them
   * as dropped: the clock stops and the player may come back.
   */
  async checkLiveness(now) {
    for (const s of this.ctx.getWebSockets()) {
      const a = s.deserializeAttachment();
      if (!a?.hb || (a.seat !== 0 && a.seat !== 1)) continue;
      const pong = this.ctx.getWebSocketAutoResponseTimestamp(s);
      const heard = Math.max(a.at ?? 0, pong?.getTime() ?? 0);
      if (!isStale(a.at, pong?.getTime() ?? null, now)) continue;
      s.serializeAttachment({});
      try {
        s.close(4003, 'timeout');
      } catch {
        // already closed
      }
      const state = await this.ctx.storage.get('state');
      // Gone since it was last heard from: that time is given back.
      await this.apply(duel.leave(state, a.seat, now, heard));
    }
  }

  async alarm() {
    const now = Date.now();
    await this.checkLiveness(now);
    const state = await this.ctx.storage.get('state');
    const due = await this.ctx.storage.get('due');
    // undefined: a room from before 'due' was kept; its alarm was the rules'.
    if (due !== undefined && (due === null || now < due)) {
      return this.schedule(state, now);
    }
    const content = state?.phase === 'question' ? await this.content(now) : null;
    const result = duel.alarm(state, now, content);
    if (result.wipe) {
      this.send(result.out);
      for (const s of this.ctx.getWebSockets()) s.close(1000, 'closed');
      await this.ctx.storage.deleteAll();
      return;
    }
    await this.apply(result);
  }

  /** Stores the new state, sends its messages and sets the alarm. */
  async apply({ state, out, alarm }) {
    if (state) await this.ctx.storage.put('state', state);
    this.send(out);
    if (alarm !== undefined) await this.ctx.storage.put('due', alarm);
    await this.schedule(state ?? (await this.ctx.storage.get('state')));
  }

  /** The alarm: the rules' time, or sooner for a liveness check. */
  async schedule(state, now = Date.now()) {
    const due = (await this.ctx.storage.get('due')) ?? null;
    const watched = this.ctx
      .getWebSockets()
      .some((s) => s.deserializeAttachment()?.hb);
    const every = watched
      ? duel.watchEvery(state, { play: CHECK_MS, idle: IDLE_CHECK_MS })
      : null;
    const at = nextAlarm(due, every, now);
    if (at === null) await this.ctx.storage.deleteAlarm();
    else await this.ctx.storage.setAlarm(at);
  }

  send(out) {
    if (!out?.length) return;
    const sockets = this.ctx.getWebSockets();
    for (const { to, msg } of out) {
      const text = JSON.stringify(msg);
      for (const s of sockets) {
        const seat = s.deserializeAttachment()?.seat;
        if (seat === undefined) continue;
        if (to === 'all' || to === seat) {
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
