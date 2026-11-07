// Tournament: up to eight players in one room, the rules as pure functions.
//
// One player opens a room and shares its code; whoever enters it joins and
// everyone sees the list. The first to join is the host (the creator, who
// connects right after opening it): they pick 5 or 10 questions, may remove
// a player (who cannot come back to this room) and start once three are in.
// Then it runs like a duel (duel.js) for everyone at once: 15 s per question,
// revealed when every connected player locked or time ran out, the next one
// when all are ready or after REVEAL_MS. At the end everyone gets the
// standings and the room is back in its lobby, ready to start again.
//
// A player whose connection drops during a match stays in it: the others
// play on, the questions they miss score the floor, and they may come back
// with their rejoin secret (?rejoin=… on the room URL) until the match
// ends, picking it up where it is. Not back by then, they are listed as
// left. The host's role passes to the earliest player still there. The room (tournament_room.js, a Durable Object) only
// stores the state, routes messages and runs the alarm.
//
// Every step returns {state, out, alarm, close?, wipe?}:
//   out    messages to send, [{to: id | 'all', msg}]
//   alarm  when to call alarm() next (ms), null for none, undefined to keep
//   close  player ids whose connection the room should close (removed)
//   wipe   true: the room is over, delete its storage
//
// Protocol (JSON, version TOURNAMENT_VERSION; see lib/core/tournament.dart):
//   app → room   {t: 'count', n}               host: 5 or 10 questions
//                {t: 'kick', id}               host, in the lobby
//                {t: 'start'}                  host, three or more players
//                {t: 'lock', i, low, high}     low/high null: nothing typed
//                {t: 'next', i}                ready for the next question
//   room → app   {t: 'welcome', you, rejoin}   your player id and secret
//                {t: 'room', code, host, count, players: [{id, name}], min, max}
//                {t: 'start', questions, questionMs, players: [{id, name}]}
//                {t: 'question', i, ms}
//                {t: 'locked', i, id}
//                {t: 'reveal', i, results: [{id, low, high, points, hit}], ms}
//                    ms absent after the last question
//                {t: 'end', standings: [{id, name, points, hits, left}], questions}
//                {t: 'kicked'}                 then the connection closes
//                {t: 'resume', you, rejoin, room, start, index, phase, ms,
//                    results, locked}
//                    to a player who came back mid-match: the room message,
//                    the start message, the open question (phase 'question'
//                    | 'reveal', ms left on it), every reveal so far and
//                    who locked the open question
//                {t: 'error', code}

import { scaleOn } from './content.js';
import { turkeyDayIndex } from './days.js';
import {
  LOCK_GRACE_MS,
  QUESTION_MS,
  REVEAL_MS,
  JOIN_TIMEOUT_MS,
} from './duel.js';
import { cleanNickname, isBlocked, nicknameKey } from './nickname.js';
import { isHit, MIN_POINTS, scoreFor, validBound } from './scoring.js';

export const TOURNAMENT_VERSION = 1;
export const MIN_PLAYERS = 3;
export const MAX_PLAYERS = 8;
export const QUESTION_COUNTS = [5, 10];
/** Difficulty mix per question count, easy to hard. */
export const LEVELS = {
  5: [1, 1, 2, 2, 3],
  10: [1, 1, 1, 1, 2, 2, 2, 2, 3, 3],
};
/** A lobby nobody touches closes after this. */
export const LOBBY_IDLE_MS = 30 * 60_000;

/**
 * The player of a connection's query (`v`, `name`, `bank`) as
 * {name, key, bank}, or {error}.
 */
export function playerFrom(params) {
  if (Number(params.get('v')) !== TOURNAMENT_VERSION) {
    return { error: 'version' };
  }
  const name = cleanNickname(params.get('name') ?? '');
  if (!name) return { error: 'invalid_name' };
  const key = nicknameKey(name);
  if (isBlocked(key)) return { error: 'blocked_name' };
  const bank = Number(params.get('bank'));
  if (!Number.isSafeInteger(bank) || bank < 1) return { error: 'bad_request' };
  return { name, key, bank };
}

function step(state, out = [], alarm = undefined, extra = {}) {
  return { state, out, alarm, ...extra };
}

function idleAlarm(state) {
  return (
    state.touchedAt +
    (state.players.length > 0 ? LOBBY_IDLE_MS : JOIN_TIMEOUT_MS)
  );
}

/** The room as everyone sees it in the lobby. */
function roomMessage(state) {
  return {
    to: 'all',
    msg: {
      t: 'room',
      code: state.code,
      host: state.host,
      count: state.count,
      players: state.players.map(({ id, name }) => ({ id, name })),
      min: MIN_PLAYERS,
      max: MAX_PLAYERS,
    },
  };
}

/** A lobby step: the room message and the idle alarm. */
function lobbyStep(state, now, out = [], extra = {}) {
  const touched = { ...state, touchedAt: now };
  return step(touched, [...out, roomMessage(touched)], idleAlarm(touched), extra);
}

/** A new, empty room. */
export function createRoom(code, now) {
  const state = {
    v: TOURNAMENT_VERSION,
    code,
    phase: 'lobby',
    createdAt: now,
    touchedAt: now,
    nextId: 1,
    host: null,
    count: 5,
    players: [],
    banned: [],
    match: null,
  };
  return step(state, [], idleAlarm(state));
}

/** Whether a new room may take the place of [state] (its code is free). */
export function isFree(state, now) {
  return (
    !state ||
    (state.phase === 'lobby' &&
      state.players.length === 0 &&
      now >= state.touchedAt + JOIN_TIMEOUT_MS)
  );
}

/** Seats a player in the lobby. Returns {id, ...step} or {error}. */
export function join(state, { name, key, bank, token = null }, now) {
  if (!state) return { error: 'no_room' };
  if (state.phase !== 'lobby') return { error: 'in_progress' };
  if (state.banned.includes(key)) return { error: 'kicked' };
  if (state.players.some((p) => p.key === key)) return { error: 'name_taken' };
  if (state.players.length >= MAX_PLAYERS) return { error: 'room_full' };
  const id = state.nextId;
  const players = [...state.players, { id, name, key, bank, token }];
  const joined = {
    ...state,
    nextId: id + 1,
    players,
    host: state.host ?? id,
  };
  return {
    id,
    ...lobbyStep(joined, now, [
      { to: id, msg: { t: 'welcome', you: id, rejoin: token } },
    ]),
  };
}

/** The host picks 5 or 10 questions. */
export function setCount(state, id, { n }, now) {
  if (state.phase !== 'lobby' || id !== state.host) return step(state);
  if (!QUESTION_COUNTS.includes(n) || n === state.count) return step(state);
  return lobbyStep({ ...state, count: n }, now);
}

/** The host removes [target]; they cannot join this room again. */
export function kick(state, id, { id: target }, now) {
  if (state.phase !== 'lobby' || id !== state.host || target === id) {
    return step(state);
  }
  const player = state.players.find((p) => p.id === target);
  if (!player) return step(state);
  return lobbyStep(
    {
      ...state,
      players: state.players.filter((p) => p.id !== target),
      banned: [...state.banned, player.key],
    },
    now,
    [{ to: target, msg: { t: 'kicked' } }],
    { close: [target] },
  );
}

/**
 * The host starts a match. [pick](bankLimit, levels) returns the question
 * ids (duel.pickDuelQuestions) or null.
 */
export function start(state, id, now, pick) {
  if (state.phase !== 'lobby' || id !== state.host) return step(state);
  if (state.players.length < MIN_PLAYERS) {
    return step(state, [{ to: id, msg: { t: 'error', code: 'too_few' } }]);
  }
  const bankLimit = Math.min(...state.players.map((p) => p.bank));
  const questions = pick(bankLimit, LEVELS[state.count]);
  if (!questions) {
    return step(state, [{ to: id, msg: { t: 'error', code: 'no_questions' } }]);
  }
  const players = state.players.map(({ id: pid, name }) => ({ id: pid, name }));
  const match = {
    questions,
    players: state.players.map(({ id: pid, name, key, bank, token }) => ({
      id: pid,
      name,
      key,
      bank,
      token,
      left: false,
      points: 0,
      hits: 0,
    })),
    index: -1,
    deadline: null,
    locks: {},
    ready: [],
    reveals: [],
  };
  const started = { ...state, phase: 'question', match };
  const out = [
    {
      to: 'all',
      msg: { t: 'start', questions, questionMs: QUESTION_MS, players },
    },
  ];
  const first = askQuestion(started, 0, now);
  return step(first.state, [...out, ...first.out], first.alarm);
}

/** Players of the match still connected. */
function present(match) {
  return match.players.filter((p) => !p.left);
}

function askQuestion(state, index, now) {
  const deadline = now + QUESTION_MS;
  return step(
    {
      ...state,
      phase: 'question',
      match: { ...state.match, index, deadline, locks: {}, ready: [] },
    },
    [{ to: 'all', msg: { t: 'question', i: index, ms: QUESTION_MS } }],
    deadline + LOCK_GRACE_MS,
  );
}

/** A player locks question [i]; null bounds mean nothing was typed. */
export function lock(state, id, { i, low, high }, now, content) {
  const match = state.match;
  if (state.phase !== 'question' || i !== match.index) return step(state);
  const player = match.players.find((p) => p.id === id);
  if (!player || player.left || match.locks[id]) return step(state);
  const q = content.questions.get(match.questions[i]);
  const empty = low === null && high === null;
  if (
    !empty &&
    !(validBound(q.kind, low) && validBound(q.kind, high) && low <= high)
  ) {
    return step(state, [{ to: id, msg: { t: 'error', code: 'bad_lock' } }]);
  }
  const locks = {
    ...match.locks,
    [id]: empty ? { low: null, high: null } : { low, high },
  };
  const locked = { ...state, match: { ...match, locks } };
  if (present(locked.match).every((p) => locks[p.id])) {
    return reveal(locked, now, content);
  }
  return step(locked, [{ to: 'all', msg: { t: 'locked', i, id } }]);
}

function reveal(state, now, content) {
  const match = state.match;
  const q = content.questions.get(match.questions[match.index]);
  const scale = scaleOn(content, q, turkeyDayIndex(now));
  const results = match.players.map((p) => {
    const l = match.locks[p.id];
    const low = l?.low ?? null;
    const high = l?.high ?? null;
    return {
      id: p.id,
      low,
      high,
      points:
        low === null
          ? MIN_POINTS
          : scoreFor(q.kind, low, high, q.answer, scale),
      hit: isHit(low, high, q.answer),
    };
  });
  const players = match.players.map((p, k) => ({
    ...p,
    points: p.points + results[k].points,
    hits: p.hits + (results[k].hit ? 1 : 0),
  }));
  const last = match.index === match.questions.length - 1;
  const msg = { t: 'reveal', i: match.index, results };
  if (!last) msg.ms = REVEAL_MS;
  const revealed = {
    ...state,
    phase: 'reveal',
    match: {
      ...match,
      players,
      deadline: now + REVEAL_MS,
      reveals: [...(match.reveals ?? []), results],
    },
  };
  if (last) return finish(revealed, now, [{ to: 'all', msg }]);
  return step(revealed, [{ to: 'all', msg }], revealed.match.deadline);
}

/** Standings, best first: points, then hits, then who joined first.
 * Only public fields: never the players' secrets. */
export function standingsOf(players) {
  return [...players]
    .sort((a, b) => b.points - a.points || b.hits - a.hits || a.id - b.id)
    .map(({ id, name, points, hits, left }) => ({
      id,
      name,
      points,
      hits,
      left,
    }));
}

/** The match is over: standings to all, the room back in its lobby. */
function finish(state, now, out = []) {
  const match = state.match;
  const end = {
    t: 'end',
    standings: standingsOf(match.players),
    questions: match.questions.length,
  };
  const lobby = { ...state, phase: 'lobby', match: null };
  return lobbyStep(lobby, now, [...out, { to: 'all', msg: end }]);
}

/** A player is ready for the question after [i]. */
export function next(state, id, { i }, now) {
  const match = state.match;
  if (state.phase !== 'reveal' || i !== match.index) return step(state);
  if (match.ready.includes(id)) return step(state);
  const ready = [...match.ready, id];
  const waiting = { ...state, match: { ...match, ready } };
  if (present(match).every((p) => ready.includes(p.id))) {
    return askQuestion(waiting, match.index + 1, now);
  }
  return step(waiting);
}

/** The earliest player still in the room, or null. */
function nextHost(players) {
  return players.length === 0 ? null : players[0].id;
}

/** A player's connection closed. */
export function leave(state, id, now, content) {
  if (!state) return step(state);
  const players = state.players.filter((p) => p.id !== id);
  if (players.length === state.players.length) return step(state);
  const host = state.host === id ? nextHost(players) : state.host;
  if (players.length === 0) return { wipe: true, ...step(state) };
  const rest = { ...state, players, host };
  if (state.phase === 'lobby') return lobbyStep(rest, now);

  // In a match: the player stays in its standings, marked as left.
  const match = {
    ...state.match,
    players: state.match.players.map((p) =>
      p.id === id ? { ...p, left: true } : p,
    ),
  };
  const left = { ...rest, match };
  const out = [roomMessage(left)];
  if (state.phase === 'question' && present(match).every((p) => match.locks[p.id])) {
    const r = reveal(left, now, content);
    return step(r.state, [...out, ...r.out], r.alarm);
  }
  if (state.phase === 'reveal' && present(match).every((p) => match.ready.includes(p.id))) {
    const r = askQuestion(left, match.index + 1, now);
    return step(r.state, [...out, ...r.out], r.alarm);
  }
  return step(left, out);
}

/** What a player who came back needs to pick the match up again. */
function resumeMessage(state, id, now) {
  const match = state.match;
  const room = roomMessage(state).msg;
  return {
    t: 'resume',
    you: id,
    rejoin: match.players.find((p) => p.id === id).token,
    room,
    start: {
      t: 'start',
      questions: match.questions,
      questionMs: QUESTION_MS,
      players: match.players.map(({ id: pid, name }) => ({ id: pid, name })),
    },
    index: match.index,
    phase: state.phase,
    ms: Math.max(0, match.deadline - now),
    results: match.reveals ?? [],
    locked: Object.keys(match.locks).map(Number),
  };
}

/**
 * A player comes back mid-match with their secret. Returns {id, ...step}
 * or {error}; after the match the code works as usual instead.
 */
export function rejoin(state, token, now) {
  if (!state || typeof token !== 'string' || token.length === 0) {
    return { error: 'no_room' };
  }
  if (state.phase === 'lobby' || !state.match) return { error: 'rejoin_over' };
  const player = state.match.players.find((p) => p.token === token);
  if (!player) return { error: 'no_room' };
  const id = player.id;
  const match = {
    ...state.match,
    players: state.match.players.map((p) =>
      p.id === id ? { ...p, left: false } : p,
    ),
  };
  const players = state.players.some((p) => p.id === id)
    ? state.players
    : [
        ...state.players,
        {
          id,
          name: player.name,
          key: player.key,
          bank: player.bank,
          token,
        },
      ];
  const back = {
    ...state,
    players,
    host: state.host ?? id,
    match,
  };
  return {
    id,
    ...step(back, [
      { to: id, msg: resumeMessage(back, id, now) },
      roomMessage(back),
    ]),
  };
}

/** The alarm went off. */
export function alarm(state, now, content) {
  if (!state) return { wipe: true, ...step(state) };
  switch (state.phase) {
    case 'lobby':
      if (now < idleAlarm(state)) return step(state, [], idleAlarm(state));
      return {
        wipe: true,
        ...step(state, [{ to: 'all', msg: { t: 'error', code: 'expired' } }]),
      };
    case 'question':
      if (now < state.match.deadline + LOCK_GRACE_MS) {
        return step(state, [], state.match.deadline + LOCK_GRACE_MS);
      }
      return reveal(state, now, content);
    case 'reveal':
      if (now < state.match.deadline) return step(state, [], state.match.deadline);
      return askQuestion(state, state.match.index + 1, now);
    default:
      return { wipe: true, ...step(state) };
  }
}
