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
//                {t: 'resign'}               gives up: the other one wins
//                {"t":"ping"}                every few seconds with ?hb=1;
//                    the runtime answers {"t":"pong"} (liveness.js)
//                {t: 'rematch'}              after the end: wants a rematch
//                    (or accepts the other's); needs ?rm=1 from both apps
//                {t: 'rematch_no'}           does not (declines or takes
//                    their own request back): no rematch in this room
//   room → app   {t: 'waiting', code}
//                {t: 'start', you, names, questions, questionMs, rejoin}
//                    rejoin: this player's secret to come back after a
//                    dropped connection (?rejoin=… on the same room URL)
//                {t: 'question', i, ms}
//                {t: 'locked', i, seat}      someone locked (no values)
//                {t: 'reveal', i, results: [r0, r1], totals, ms}
//                    ms: the next question comes after this long at most
//                    (absent after the last question)
//                    r = {low, high, points, hit}
//                {t: 'end', totals, winner, reason, rematch}
//                    winner 0 | 1 | null (draw); reason 'done' | 'left'
//                    ('left': the loser gave up or did not come back);
//                    rematch: true when a rematch may be asked for
//                {t: 'rematch', seat}        [seat] wants a rematch
//                {t: 'rematch_no', seat, reason}  no rematch: reason 'no'
//                    (declined or taken back), 'left' (gone), 'expired'
//                    (the room closes) or 'no_questions'
//                    Both want one: the room starts again with a new
//                    'start' (new questions, new rejoin secrets, round + 1)
//                    and the first 'question'.
//                {t: 'error', code}
//                {t: 'away', seat, ms}   the other player's connection
//                    dropped; ms: what is left of their time away. An open
//                    question runs on; a revealed one waits for them.
//                {t: 'back', seat, ms}   they are back; ms left on the
//                    open question (or the reveal, whose clock runs again)
//                {t: 'resume', you, names, questions, questionMs, rejoin,
//                    index, phase, ms, results, totals, locked, away}
//                    to a player who came back: the whole duel so far.
//                    phase 'question' | 'reveal', ms left on it, results
//                    [[r0, r1], …] per revealed question, locked [bool,
//                    bool] on the open one, away: the other seat if it is
//                    gone too (with ms in awayMs), else null; budget: ms
//                    of time away this player has left
//
// A dropped connection does not end the duel at once: the player may come
// back with their rejoin secret. Each player has AWAY_BUDGET_MS of time
// away for the whole duel, counted down across every drop; when it runs out
// the other player wins. An open question does not stop for anyone: the one
// who dropped loses its seconds (time out: the floor) and the other answers
// as usual, so dropping out to look an answer up gains nothing and waiting
// gives nobody extra time. Only between questions does the duel wait: a
// revealed question's clock stops and the next one does not open until
// they are back. A connection that goes silent (no network) is
// closed by the room after a few seconds and counts as dropped
// (liveness.js). A player who left the app may also come back with only
// their secret and give up from there (?rejoin=…&resign=1): the other
// player wins at once instead of waiting.
//
// Random opponents go through the lobby first (duel_lobby.js):
//   lobby → app  {t: 'searching'}
//                {t: 'matched', code}      then connect to that room

import { scaleOn, upcomingIds } from './content.js';
import { turkeyDayIndex } from './days.js';
import { isHit, MIN_POINTS, scoreFor, validBound } from './scoring.js';
import { cleanNickname, isBlocked, nicknameKey } from './nickname.js';
import { MATH_MIN_POINTS, mathAnswer, mathScale } from './math.js';

export const DUEL_VERSION = 1;
export const QUESTION_MS = 15_000;
/** A math duel (mode 'math', 2026-11-08): computed questions, 30 s each
 * (math's free play has 60 s; a duel keeps the pace up). */
export const MATH_QUESTION_MS = 30_000;
/** Network slack after a question's deadline before it is revealed. */
export const LOCK_GRACE_MS = 1_500;
/** Longest stay on a revealed question when a player does not go on. */
export const REVEAL_MS = 12_000;
/** A room nobody joins closes after this. */
export const JOIN_TIMEOUT_MS = 10 * 60_000;
/** A finished room is wiped after this. */
export const CLEANUP_MS = 60_000;
/** A player's time away (dropped connections) for the whole duel. */
export const AWAY_BUDGET_MS = 45_000;
/** After a rematch request the room stays at least this long for the
 * answer (it is otherwise wiped CLEANUP_MS after the end). */
export const REMATCH_ANSWER_MS = 30_000;

/** No I, L, O, 0 or 1: nothing to mix up when read aloud. */
export const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const CODE_LENGTH = 5;

/** A player's secret to come back to a room with (128 random bits). */
export function secret() {
  const raw = crypto.getRandomValues(new Uint8Array(16));
  return [...raw].map((b) => b.toString(16).padStart(2, '0')).join('');
}

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
  // Apps that know rematches say so (?rm=1); older ones never get one.
  // Apps that can play math duels say ?math=1; others are turned away
  // from a math room.
  return {
    name,
    bank,
    rematch: params.get('rm') === '1',
    math: params.get('math') === '1',
  };
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

/** A duel's difficulty mix: two easy, two medium, one hard. */
export const DUEL_LEVELS = [1, 1, 2, 2, 3];

/**
 * Question ids for a match, easy to hard, one per entry of [levels]
 * (difficulty 1–3) where the pool allows; the duel's five by default.
 *
 * Only the first [bankLimit] questions of the bank are used. The bank is
 * append-only, so both apps hold these with the same ids (bankLimit is the
 * smaller of their bank sizes). Questions of the next days' daily sets are
 * kept out, as in free play, and so are retired questions.
 */
export function pickDuelQuestions(
  content,
  bankLimit,
  today,
  randomInt,
  levels = DUEL_LEVELS,
  exclude = new Set(),
) {
  const upcoming = upcomingIds(content.days, today);
  const pool = content.order
    .slice(0, Math.max(0, bankLimit))
    .filter(
      (id) =>
        !upcoming.has(id) &&
        !exclude.has(id) &&
        !content.questions.get(id).retired,
    );
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
  for (const level of levels) take(byLevel[level]);
  // A thin pool: fill up from whatever is left.
  const rest = [...byLevel[1], ...byLevel[2], ...byLevel[3]];
  while (picked.length < levels.length && take(rest));
  if (picked.length < levels.length) return null;
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
export function createRoom(code, now, mode = 'bank') {
  return step(
    {
      v: DUEL_VERSION,
      code,
      // 'bank': the question bank; 'math': generated math questions.
      mode: mode === 'math' ? 'math' : 'bank',
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
      // Per seat, while their connection is gone: {since, until}; until
      // is when their time away runs out.
      away: [null, null],
      // Per seat: time away left for the rest of the duel.
      budget: [AWAY_BUDGET_MS, AWAY_BUDGET_MS],
      // A revealed question while someone is away: {ms} left on it.
      paused: null,
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
export function join(
  state,
  { name, bank, token = null, rematch = false, math = false },
  now,
  pick,
) {
  if (!state) return error('no_room');
  if (state.mode === 'math' && !math) return error('version');
  if (state.phase !== 'waiting') return error('room_closed');
  if (state.players.length >= 2) return error('room_full');
  const seat = state.players.length;
  const players = [...state.players, { name, bank, token, rematch }];
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
  const first = askQuestion(started, 0, now);
  return {
    seat,
    ...step(first.state, [...startMessages(started), ...first.out], first.alarm),
  };
}

function startMessages(state) {
  return [0, 1].map((you) => {
    const msg = {
      t: 'start',
      you,
      names: state.players.map((p) => p.name),
      questions: state.questions,
      questionMs: questionMs(state),
      rejoin: state.players[you].token,
    };
    if (state.round > 1) msg.round = state.round;
    return { to: you, msg };
  });
}

/** Time per question in [state]'s room. */
function questionMs(state) {
  return state.mode === 'math' ? MATH_QUESTION_MS : QUESTION_MS;
}

/**
 * The question [id] as scoring needs it: from the bank, or computed for a
 * math id ({answer, unit, kind, math: true}).
 */
export function questionOf(content, id) {
  const computed = mathAnswer(id);
  if (computed) return { ...computed, kind: 'magnitude', math: true };
  return content.questions.get(id);
}

function askQuestion(state, index, now) {
  const ms = questionMs(state);
  const deadline = now + ms;
  return step(
    {
      ...state,
      phase: 'question',
      index,
      deadline,
      locks: [null, null],
      ready: [false, false],
    },
    [{ to: 'all', msg: { t: 'question', i: index, ms } }],
    deadline + LOCK_GRACE_MS,
  );
}

/** A player locks question [i]; null bounds mean nothing was typed. */
export function lock(state, seat, { i, low, high }, now, content) {
  if (state.phase !== 'question' || i !== state.index) return step(state);
  if (state.locks[seat]) return step(state);
  // Too late: the question's time (and the network slack) is over.
  if (now > state.deadline + LOCK_GRACE_MS) return step(state);
  const q = questionOf(content, state.questions[i]);
  const empty = low === null && high === null;
  if (
    !empty &&
    !(validBound(q.kind, low) && validBound(q.kind, high) && low <= high)
  ) {
    return step(
      state,
      [{ to: seat, msg: { t: 'error', code: 'bad_lock' } }],
      questionAlarm(state),
    );
  }
  const locks = [...state.locks];
  locks[seat] = empty ? { low: null, high: null } : { low, high };
  const locked = { ...state, locks };
  if (locks[0] && locks[1]) return reveal(locked, now, content);
  return step(
    locked,
    [{ to: 'all', msg: { t: 'locked', i, seat } }],
    questionAlarm(locked),
  );
}

function reveal(state, now, content) {
  const q = questionOf(content, state.questions[state.index]);
  // Math: a ÷2 … ×2 slider and no minus points (answer_scale.dart).
  const floor = q.math ? MATH_MIN_POINTS : MIN_POINTS;
  const scale = q.math
    ? mathScale(q.unit)
    : scaleOn(content, q, turkeyDayIndex(now));
  const results = state.locks.map((l) => {
    const low = l?.low ?? null;
    const high = l?.high ?? null;
    return {
      low,
      high,
      points:
        low === null
          ? floor
          : scoreFor(q.kind, low, high, q.answer, scale, floor),
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
  if (anyAway(state)) {
    return step(
      { ...revealed, deadline: null, paused: { ms: REVEAL_MS } },
      out,
      awayAlarm(state),
    );
  }
  return step(revealed, out, revealed.deadline);
}

function winnerOf(totals) {
  if (totals[0] === totals[1]) return null;
  return totals[0] > totals[1] ? 0 : 1;
}

/** Ends the duel; the alarm then wipes the room. */
function finish(state, reason, now, winner = winnerOf(state.totals)) {
  // A rematch is offered after a duel played to the end, between two apps
  // that know rematches.
  const open =
    reason === 'done' &&
    state.players.length === 2 &&
    state.players.every((p) => p.rematch);
  const over = {
    ...state,
    phase: 'over',
    winner,
    reason,
    deadline: null,
    paused: null,
    away: [null, null],
    rematch: open ? [false, false] : null,
    wipeAt: now + CLEANUP_MS,
  };
  return step(over, [{ to: 'all', msg: endMessage(over) }], over.wipeAt);
}

function endMessage(state) {
  const msg = {
    t: 'end',
    totals: state.totals,
    winner: state.winner,
    reason: state.reason,
  };
  if (state.rematch) msg.rematch = true;
  return msg;
}

/** Closes the rematch offer: [seat] said no or left (null: the room). */
function noRematch(state, seat, reason) {
  const msg = { t: 'rematch_no', seat, reason };
  return step({ ...state, rematch: null }, [
    { to: seat === null ? 'all' : 1 - seat, msg },
  ]);
}

/**
 * After the end, [seat] wants a rematch (or accepts one). Once both want
 * it the room starts again: questions none of this room's rounds asked
 * ([pick](bankLimit, exclude), see pickDuelQuestions), new rejoin secrets
 * from [newToken](), a fresh time away, round + 1.
 */
export function rematch(state, seat, now, pick, newToken) {
  if (!state || state.phase !== 'over' || !state.rematch) return step(state);
  if (state.rematch[seat]) return step(state);
  const want = [...state.rematch];
  want[seat] = true;
  if (!(want[0] && want[1])) {
    const wipeAt = Math.max(state.wipeAt ?? now, now + REMATCH_ANSWER_MS);
    return step(
      { ...state, rematch: want, wipeAt },
      [{ to: 1 - seat, msg: { t: 'rematch', seat } }],
      wipeAt,
    );
  }
  const played = [...(state.played ?? []), ...state.questions];
  const questions = pick(
    Math.min(state.players[0].bank, state.players[1].bank),
    new Set(played),
  );
  if (!questions) {
    const none = noRematch(state, null, 'no_questions');
    return step(none.state, none.out, state.wipeAt ?? now);
  }
  const again = {
    ...state,
    players: state.players.map((p) => ({ ...p, token: newToken() })),
    questions,
    played,
    round: (state.round ?? 1) + 1,
    results: [],
    totals: [0, 0],
    winner: null,
    reason: null,
    away: [null, null],
    budget: [AWAY_BUDGET_MS, AWAY_BUDGET_MS],
    paused: null,
    rematch: null,
    wipeAt: null,
  };
  const first = askQuestion(again, 0, now);
  return step(
    first.state,
    [...startMessages(again), ...first.out],
    first.alarm,
  );
}

/** After the end, [seat] does not want a rematch (or takes theirs back). */
export function declineRematch(state, seat) {
  if (!state || state.phase !== 'over' || !state.rematch) return step(state);
  return noRematch(state, seat, 'no');
}

/** A player is ready for the question after [i]. */
export function next(state, seat, { i }, now) {
  if (state.phase !== 'reveal' || i !== state.index) return step(state);
  const ready = [...state.ready];
  ready[seat] = true;
  if (ready[0] && ready[1] && !anyAway(state)) {
    return askQuestion(state, state.index + 1, now);
  }
  return step(
    { ...state, ready },
    [],
    state.paused ? awayAlarm(state) : state.deadline,
  );
}

/** The seats' {since, until} while away (older rooms kept a number). */
function awayOf(state) {
  return (state.away ?? [null, null]).map((a) =>
    typeof a === 'number' ? { since: a - AWAY_BUDGET_MS, until: a } : a,
  );
}

function budgetOf(state) {
  return state.budget ?? [AWAY_BUDGET_MS, AWAY_BUDGET_MS];
}

function anyAway(state) {
  return awayOf(state).some((a) => a !== null);
}

/** The alarm while someone is away: the first time away to run out. */
function awayAlarm(state) {
  const times = awayOf(state)
    .filter((a) => a !== null)
    .map((a) => a.until);
  return times.length === 0 ? null : Math.min(...times);
}

/** An open question's alarm: its deadline, or someone's time away
 * running out first. */
function questionAlarm(state) {
  const end = state.deadline + LOCK_GRACE_MS;
  const away = awayAlarm(state);
  return away === null ? end : Math.min(end, away);
}

/**
 * A player's connection closed. [since]: when it really went (a silent
 * connection is noticed only seconds later); their time away counts from
 * then. An open question runs on for both; a revealed one waits.
 */
export function leave(state, seat, now, since = now) {
  if (!state) return step(state);
  if (state.phase === 'over') {
    // Gone after the end: no rematch with them.
    return state.rematch ? noRematch(state, seat, 'left') : step(state);
  }
  if (state.phase === 'waiting') {
    // The creator may be sharing the code from another app: the room stays
    // open until it times out, and they can connect again.
    return step(
      { ...state, players: state.players.filter((_, s) => s !== seat) },
      [],
      state.createdAt + JOIN_TIMEOUT_MS,
    );
  }
  const away = awayOf(state);
  if (away[seat] !== null) return step(state);
  const from = Math.min(since, now);
  const until = from + budgetOf(state)[seat];
  if (until <= now) return finish(state, 'left', now, 1 - seat);
  away[seat] = { since: from, until };
  const out = [{ to: 1 - seat, msg: { t: 'away', seat, ms: until - now } }];
  if (state.phase === 'question') {
    const gone = { ...state, away };
    return step(gone, out, questionAlarm(gone));
  }
  // A revealed question: its clock stops until they are back.
  const paused = state.paused ?? {
    ms: Math.max(0, state.deadline - from),
  };
  const waiting = { ...state, away, paused, deadline: null };
  return step(waiting, out, awayAlarm(waiting));
}

/** Everything a returning player needs to pick the duel up again. */
function resumeMessage(state, seat, now) {
  const other = 1 - seat;
  const away = awayOf(state)[other];
  return {
    t: 'resume',
    you: seat,
    names: state.players.map((p) => p.name),
    questions: state.questions,
    questionMs: questionMs(state),
    rejoin: state.players[seat].token,
    index: state.index,
    phase: state.phase,
    ms: state.paused ? state.paused.ms : Math.max(0, state.deadline - now),
    results: state.results,
    totals: state.totals,
    locked: state.locks.map((l) => l !== null),
    away: away === null ? null : other,
    awayMs: away === null ? null : Math.max(0, away.until - now),
    budget: budgetOf(state)[seat],
  };
}

/**
 * A player comes back with their rejoin secret. Returns {seat, ...step}
 * or {error}. Their time away is taken off what they have left; a revealed
 * question's clock runs again once nobody is away.
 */
export function rejoin(state, token, now) {
  if (!state || typeof token !== 'string' || token.length === 0) {
    return error('no_room');
  }
  const seat = state.players.findIndex((p) => p.token === token);
  if (seat < 0) return error('no_room');
  if (state.phase === 'over') {
    // It ended while they were away: tell them how (and whether the other
    // one already asked for a rematch).
    const out = [{ to: seat, msg: endMessage(state) }];
    if (state.rematch?.[1 - seat]) {
      out.push({ to: seat, msg: { t: 'rematch', seat: 1 - seat } });
    }
    return { seat, ...step(state, out) };
  }
  if (state.phase !== 'question' && state.phase !== 'reveal') {
    return error('room_closed');
  }
  const away = awayOf(state);
  const gone = away[seat];
  const budget = [...budgetOf(state)];
  if (gone !== null) {
    budget[seat] = Math.max(0, budget[seat] - (now - gone.since));
  }
  away[seat] = null;
  const back = { ...state, away, budget };
  const otherAway = away[1 - seat] !== null;
  const tellOther = (ms) =>
    gone === null || otherAway ? [] : [{ to: 1 - seat, msg: { t: 'back', seat, ms } }];

  if (state.phase === 'question') {
    // The question never stopped.
    const ms = Math.max(0, back.deadline - now);
    return {
      seat,
      ...step(
        back,
        [{ to: seat, msg: resumeMessage(back, seat, now) }, ...tellOther(ms)],
        questionAlarm(back),
      ),
    };
  }
  if (otherAway) {
    // The other one is gone too: the reveal stays stopped.
    return {
      seat,
      ...step(
        back,
        [{ to: seat, msg: resumeMessage(back, seat, now) }],
        awayAlarm(back),
      ),
    };
  }
  const ms = back.paused?.ms ?? Math.max(0, back.deadline - now);
  const running = { ...back, paused: null, deadline: now + ms };
  const out = [
    { to: seat, msg: resumeMessage(running, seat, now) },
    ...tellOther(ms),
  ];
  // Both said "devam" already: the next question now.
  if (running.ready[0] && running.ready[1]) {
    const ask = askQuestion(running, running.index + 1, now);
    return { seat, ...step(ask.state, [...out, ...ask.out], ask.alarm) };
  }
  return { seat, ...step(running, out, running.deadline) };
}

/**
 * The alarm went off. Returns {wipe: true} when the room's storage should
 * be deleted.
 */
export function alarm(state, now, content) {
  if (!state) return { wipe: true, ...step(state) };
  if (state.phase === 'question' || state.phase === 'reveal') {
    const away = awayOf(state);
    const gone = [0, 1].filter(
      (seat) => away[seat] !== null && now >= away[seat].until,
    );
    // Both out of time away: nobody to tell.
    if (gone.length === 2) return { wipe: true, ...step(state) };
    if (gone.length === 1) return finish(state, 'left', now, 1 - gone[0]);
  }
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
        return step(state, [], questionAlarm(state));
      }
      return reveal(state, now, content);
    case 'reveal':
      if (state.paused) return step(state, [], awayAlarm(state));
      if (now < state.deadline) return step(state, [], state.deadline);
      return askQuestion(state, state.index + 1, now);
    case 'over': {
      if (state.wipeAt && now < state.wipeAt) {
        return step(state, [], state.wipeAt);
      }
      const expired = { t: 'rematch_no', seat: null, reason: 'expired' };
      return {
        wipe: true,
        ...step(state, state.rematch ? [{ to: 'all', msg: expired }] : []),
      };
    }
    default:
      return { wipe: true, ...step(state) };
  }
}

/** [seat] gives up: the other player wins at once. */
export function resign(state, seat, now) {
  if (!state || state.phase === 'over') return step(state);
  if (state.phase === 'waiting') return leave(state, seat, now);
  return finish(state, 'left', now, 1 - seat);
}

/**
 * Gives up with a rejoin secret, from a new connection (the app was closed
 * meanwhile). Returns {seat, ...step} or {error}; a duel that is already
 * over is only told to the player.
 */
export function resignWith(state, token, now) {
  if (!state || typeof token !== 'string' || token.length === 0) {
    return error('no_room');
  }
  const seat = state.players.findIndex((p) => p.token === token);
  if (seat < 0) return error('no_room');
  if (state.phase === 'over') return rejoin(state, token, now);
  if (state.phase !== 'question' && state.phase !== 'reveal') {
    return error('room_closed');
  }
  return { seat, ...resign(state, seat, now) };
}

/** Whether the room is in a phase whose connections are worth checking,
 * and how often (liveness.js): often in play, rarely while waiting. */
export function watchEvery(state, { play, idle }) {
  if (!state) return null;
  if (state.phase === 'question' || state.phase === 'reveal') return play;
  if (state.phase === 'waiting') return idle;
  return null;
}

/** Whether a new room may take the place of [state] (code is free). */
export function isFree(state, now) {
  return (
    !state ||
    state.phase === 'over' ||
    (state.phase === 'waiting' && now >= state.createdAt + JOIN_TIMEOUT_MS)
  );
}
