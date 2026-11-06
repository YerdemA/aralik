// Real-time 1v1 duel: the rules of one room as pure functions.
//
// Two players answer the same five questions at the same time. Each
// question has 15 s; it is revealed when both locked or time ran out.
// Points are computed here with scoring.js, never taken from the app.
// The room (duel_room.js, a Durable Object) only stores the state, routes
// messages and runs the alarm; everything it decides comes from here.
//
// Every step returns {state, out, alarm}:
//   state  the new state (the old one is never changed),
//   out    messages to send, [{to: 0 | 1 | 'all', msg}],
//   alarm  when to call alarm() next (ms), null for none, undefined to
//          leave it as it is.
//
// Protocol (JSON, version DUEL_VERSION; see lib/core/duel.dart):
//   app → room   {t: 'lock', i, low, high}   low/high null: nothing typed
//                {t: 'next', i}              ready for the next question
//   room → app   {t: 'waiting', code}
//                {t: 'start', you, names, questions, questionMs}
//                {t: 'question', i, ms}
//                {t: 'locked', i, seat}      someone locked (no values)
//                {t: 'reveal', i, results: [r0, r1], totals, ms}
//                    ms: the next question comes after this long at most
//                    (absent after the last question)
//                    r = {low, high, points, hit}
//                {t: 'end', totals, winner, reason}
//                    winner 0 | 1 | null (draw); reason 'done' | 'left'
//                {t: 'error', code}
//
// Random opponents go through the lobby first (duel_lobby.js):
//   lobby → app  {t: 'searching'}
//                {t: 'matched', code}      then connect to that room

import { scaleOn, upcomingIds } from './content.js';
import { QUESTIONS_PER_DAY, turkeyDayIndex } from './days.js';
import { isHit, MIN_POINTS, scoreFor, validBound } from './scoring.js';
import { cleanNickname, isBlocked, nicknameKey } from './nickname.js';

export const DUEL_VERSION = 1;
export const QUESTION_MS = 15_000;
/** Network slack after a question's deadline before it is revealed. */
export const LOCK_GRACE_MS = 1_500;
/** Longest stay on a revealed question when a player does not go on. */
export const REVEAL_MS = 12_000;
/** A room nobody joins closes after this. */
export const JOIN_TIMEOUT_MS = 10 * 60_000;
/** A finished room is wiped after this. */
export const CLEANUP_MS = 60_000;

/** No I, L, O, 0 or 1: nothing to mix up when read aloud. */
export const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const CODE_LENGTH = 5;

/** A uniform random integer 0 ≤ k < n (n ≤ 2^16). */
export function randomInt(n) {
  const limit = 0x100000000 - (0x100000000 % n);
  const buffer = new Uint32Array(1);
  do crypto.getRandomValues(buffer);
  while (buffer[0] >= limit);
  return buffer[0] % n;
}

/**
 * The player of a connection's query (`v`, `name`, `bank`) as
 * {name, bank}, or {error} with the code to refuse it with.
 */
export function playerFrom(params) {
  if (Number(params.get('v')) !== DUEL_VERSION) return { error: 'version' };
  const name = cleanNickname(params.get('name') ?? '');
  if (!name) return { error: 'invalid_name' };
  if (isBlocked(nicknameKey(name))) return { error: 'blocked_name' };
  const bank = Number(params.get('bank'));
  if (!Number.isSafeInteger(bank) || bank < 1) return { error: 'bad_request' };
  return { name, bank };
}

/** A random room code; [randomInt](n) gives 0 ≤ k < n. */
export function newRoomCode(randomInt) {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

/** [raw] as a room code (upper case, no spaces), or null if it is not one. */
export function normalizeRoomCode(raw) {
  if (typeof raw !== 'string') return null;
  const code = raw.replace(/\s+/g, '').toUpperCase();
  if (code.length !== CODE_LENGTH) return null;
  for (const c of code) if (!CODE_ALPHABET.includes(c)) return null;
  return code;
}

/**
 * The duel's five question ids, easy to hard: two easy, two medium and one
 * hard where the pool allows.
 *
 * Only the first [bankLimit] questions of the bank are used. The bank is
 * append-only, so both apps hold these with the same ids (bankLimit is the
 * smaller of their bank sizes). Questions of the next days' daily sets are
 * kept out, as in free play, and so are retired questions.
 */
export function pickDuelQuestions(content, bankLimit, today, randomInt) {
  const upcoming = upcomingIds(content.days, today);
  const pool = content.order
    .slice(0, Math.max(0, bankLimit))
    .filter((id) => !upcoming.has(id) && !content.questions.get(id).retired);
  const byLevel = { 1: [], 2: [], 3: [] };
  for (const id of pool) {
    const level = content.questions.get(id).difficulty;
    (byLevel[level] ?? byLevel[2]).push(id);
  }
  const picked = [];
  const take = (list) => {
    if (list.length === 0) return false;
    const k = randomInt(list.length);
    const [id] = list.splice(k, 1);
    picked.push(id);
    return true;
  };
  for (const level of [1, 1, 2, 2, 3]) take(byLevel[level]);
  // A thin pool: fill up from whatever is left.
  const rest = [...byLevel[1], ...byLevel[2], ...byLevel[3]];
  while (picked.length < QUESTIONS_PER_DAY && take(rest));
  if (picked.length < QUESTIONS_PER_DAY) return null;
  const level = (id) => content.questions.get(id).difficulty;
  return picked.sort((a, b) => level(a) - level(b));
}

function step(state, out = [], alarm = undefined) {
  return { state, out, alarm };
}

function error(code) {
  return { error: code };
}

/** A new room waiting for its two players. */
export function createRoom(code, now) {
  return step(
    {
      v: DUEL_VERSION,
      code,
      phase: 'waiting',
      createdAt: now,
      players: [],
      questions: [],
      index: -1,
      deadline: null,
      locks: [null, null],
      ready: [false, false],
      results: [],
      totals: [0, 0],
      winner: null,
      reason: null,
    },
    [],
    now + JOIN_TIMEOUT_MS,
  );
}

/**
 * Seats a player. [pick](bankLimit) returns the five ids (see
 * pickDuelQuestions) and is called once both are in, which starts the
 * duel. Returns {error} for a full, closed or unknown room.
 */
export function join(state, { name, bank }, now, pick) {
  if (!state) return error('no_room');
  if (state.phase !== 'waiting') return error('room_closed');
  if (state.players.length >= 2) return error('room_full');
  const seat = state.players.length;
  const players = [...state.players, { name, bank }];
  if (players.length < 2) {
    return {
      seat,
      ...step({ ...state, players }, [
        { to: seat, msg: { t: 'waiting', code: state.code } },
      ], state.createdAt + JOIN_TIMEOUT_MS),
    };
  }
  const questions = pick(Math.min(players[0].bank, players[1].bank));
  if (!questions) return error('no_questions');
  const started = { ...state, players, questions };
  const out = [0, 1].map((you) => ({
    to: you,
    msg: {
      t: 'start',
      you,
      names: players.map((p) => p.name),
      questions,
      questionMs: QUESTION_MS,
    },
  }));
  const first = askQuestion(started, 0, now);
  return { seat, ...step(first.state, [...out, ...first.out], first.alarm) };
}

function askQuestion(state, index, now) {
  const deadline = now + QUESTION_MS;
  return step(
    {
      ...state,
      phase: 'question',
      index,
      deadline,
      locks: [null, null],
      ready: [false, false],
    },
    [{ to: 'all', msg: { t: 'question', i: index, ms: QUESTION_MS } }],
    deadline + LOCK_GRACE_MS,
  );
}

/** A player locks question [i]; null bounds mean nothing was typed. */
export function lock(state, seat, { i, low, high }, now, content) {
  if (state.phase !== 'question' || i !== state.index) return step(state);
  if (state.locks[seat]) return step(state);
  const q = content.questions.get(state.questions[i]);
  const empty = low === null && high === null;
  if (
    !empty &&
    !(validBound(q.kind, low) && validBound(q.kind, high) && low <= high)
  ) {
    return step(
      state,
      [{ to: seat, msg: { t: 'error', code: 'bad_lock' } }],
      state.deadline + LOCK_GRACE_MS,
    );
  }
  const locks = [...state.locks];
  locks[seat] = empty ? { low: null, high: null } : { low, high };
  const locked = { ...state, locks };
  if (locks[0] && locks[1]) return reveal(locked, now, content);
  return step(
    locked,
    [{ to: 'all', msg: { t: 'locked', i, seat } }],
    state.deadline + LOCK_GRACE_MS,
  );
}

function reveal(state, now, content) {
  const q = content.questions.get(state.questions[state.index]);
  const results = state.locks.map((l) => {
    const low = l?.low ?? null;
    const high = l?.high ?? null;
    return {
      low,
      high,
      points:
        low === null
          ? MIN_POINTS
          : scoreFor(
              q.kind,
              low,
              high,
              q.answer,
              scaleOn(content, q, turkeyDayIndex(now)),
            ),
      hit: isHit(low, high, q.answer),
    };
  });
  const totals = state.totals.map((t, seat) => t + results[seat].points);
  const revealed = {
    ...state,
    phase: 'reveal',
    deadline: now + REVEAL_MS,
    results: [...state.results, results],
    totals,
  };
  const last = state.index === state.questions.length - 1;
  const msg = { t: 'reveal', i: state.index, results, totals };
  if (!last) msg.ms = REVEAL_MS;
  const out = [{ to: 'all', msg }];
  if (last) {
    const over = finish(revealed, 'done', now);
    return step(over.state, [...out, ...over.out], over.alarm);
  }
  return step(revealed, out, revealed.deadline);
}

function winnerOf(totals) {
  if (totals[0] === totals[1]) return null;
  return totals[0] > totals[1] ? 0 : 1;
}

/** Ends the duel; the alarm then wipes the room. */
function finish(state, reason, now, winner = winnerOf(state.totals)) {
  return step(
    { ...state, phase: 'over', winner, reason, deadline: null },
    [
      {
        to: 'all',
        msg: { t: 'end', totals: state.totals, winner, reason },
      },
    ],
    now + CLEANUP_MS,
  );
}

/** A player is ready for the question after [i]. */
export function next(state, seat, { i }, now) {
  if (state.phase !== 'reveal' || i !== state.index) return step(state);
  const ready = [...state.ready];
  ready[seat] = true;
  if (ready[0] && ready[1]) return askQuestion(state, state.index + 1, now);
  return step({ ...state, ready }, [], state.deadline);
}

/** A player's connection closed. */
export function leave(state, seat, now) {
  if (!state || state.phase === 'over') return step(state);
  if (state.phase === 'waiting') {
    // The creator may be sharing the code from another app: the room stays
    // open until it times out, and they can connect again.
    return step(
      { ...state, players: state.players.filter((_, s) => s !== seat) },
      [],
      state.createdAt + JOIN_TIMEOUT_MS,
    );
  }
  return finish(state, 'left', now, 1 - seat);
}

/**
 * The alarm went off. Returns {wipe: true} when the room's storage should
 * be deleted.
 */
export function alarm(state, now, content) {
  if (!state) return { wipe: true, ...step(state) };
  switch (state.phase) {
    case 'waiting':
      if (now < state.createdAt + JOIN_TIMEOUT_MS) {
        return step(state, [], state.createdAt + JOIN_TIMEOUT_MS);
      }
      return {
        wipe: true,
        ...step(state, [{ to: 'all', msg: { t: 'error', code: 'expired' } }]),
      };
    case 'question':
      if (now < state.deadline + LOCK_GRACE_MS) {
        return step(state, [], state.deadline + LOCK_GRACE_MS);
      }
      return reveal(state, now, content);
    case 'reveal':
      if (now < state.deadline) return step(state, [], state.deadline);
      return askQuestion(state, state.index + 1, now);
    default:
      return { wipe: true, ...step(state) };
  }
}

/** Whether a new room may take the place of [state] (code is free). */
export function isFree(state, now) {
  return (
    !state ||
    state.phase === 'over' ||
    (state.phase === 'waiting' && now >= state.createdAt + JOIN_TIMEOUT_MS)
  );
}
