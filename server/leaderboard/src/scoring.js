// Port of lib/core/scoring.dart. Must give exactly the same points:
// test/scoring_vectors.json is checked by both this server's tests and
// test/core/scoring_vectors_test.dart in the app.

export const MAX_POINTS = 100;
export const MIN_POINTS = -50;
const MISS_PENALTY = 20; // 2 / α with α = 0,1
const POINTS_PER_LOG2 = 10;
const POINTS_PER_YEAR = 1;

/** Dart's `double.round()`: halves round away from zero. */
function dartRound(x) {
  return Math.sign(x) * Math.round(Math.abs(x));
}

export function intervalScore(kind, low, high, answer) {
  const axis =
    kind === 'magnitude' ? (v) => Math.log2(Math.max(v, 1e-9)) : (v) => v;
  const l = axis(low);
  const h = axis(high);
  const x = axis(answer);
  const outside = x < l ? l - x : x > h ? x - h : 0;
  return h - l + MISS_PENALTY * outside;
}

/** Points of one locked interval; null bounds mean time ran out empty. */
export function scoreFor(kind, low, high, answer) {
  if (low === null || high === null) return MIN_POINTS;
  const s = intervalScore(kind, low, high, answer);
  const k = kind === 'magnitude' ? POINTS_PER_LOG2 : POINTS_PER_YEAR;
  const points = dartRound(MAX_POINTS - k * s);
  return Math.min(MAX_POINTS, Math.max(MIN_POINTS, points));
}

export function isHit(low, high, answer) {
  return low !== null && high !== null && low <= answer && answer <= high;
}

const MAX_BOUND = 1e15;

/** Whether [value] can be a bound of an interval for a [kind] question. */
export function validBound(kind, value) {
  if (!Number.isSafeInteger(value) || Math.abs(value) > MAX_BOUND) {
    return false;
  }
  return kind !== 'magnitude' || value >= 1;
}
