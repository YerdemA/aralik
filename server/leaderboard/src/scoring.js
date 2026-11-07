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

export function intervalScore(kind, low, high, answer, linear = false) {
  const axis =
    kind === 'magnitude' && !linear
      ? (v) => Math.log2(Math.max(v, 1e-9))
      : (v) => v;
  const l = axis(low);
  const h = axis(high);
  const x = axis(answer);
  const outside = x < l ? l - x : x > h ? x - h : 0;
  return h - l + MISS_PENALTY * outside;
}

// The scaled rule (lib/core/answer_scale.dart): each question's widest
// slider interval comes from its kind, category and answer, and a hit at
// that width scores POINTS_AT_WIDEST everywhere.
const POINTS_AT_WIDEST = 30;
const SCALE_BASE_YEAR = 2026;
const MAGNITUDE_FACTORS = {
  coğrafya: 10,
  şirketler: 10,
  hayvanlar: 8,
  bilim: 6,
  mimari: 6,
  türkiye: 6,
  gündelik: 5,
  spor: 4,
};
const DEFAULT_MAGNITUDE_FACTOR = 8;

// Percentages (unit '%') are scored linearly in points: the slider gives
// guess ± up to 20, never above 100.
const PERCENT_UNIT = '%';
const MAX_PERCENT_HALF = 20;

/** {maxFactor, maxYearHalf, maxPercentHalf} of a question; see answer_scale.dart. */
export function scaleOf(kind, category, answer, unit = '') {
  if (kind === 'magnitude') {
    if (unit === PERCENT_UNIT) {
      return { maxFactor: 0, maxYearHalf: 0, maxPercentHalf: MAX_PERCENT_HALF };
    }
    return {
      maxFactor: MAGNITUDE_FACTORS[category] ?? DEFAULT_MAGNITUDE_FACTOR,
      maxYearHalf: 0,
      maxPercentHalf: 0,
    };
  }
  const age = Math.max(0, SCALE_BASE_YEAR - dartRound(answer));
  const half = dartRound((20 + age / 4) / 10) * 10;
  return {
    maxFactor: 0,
    maxYearHalf: Math.min(400, Math.max(30, half)),
    maxPercentHalf: 0,
  };
}

export function pointsPerUnit(kind, scale) {
  if (scale.maxPercentHalf > 0) {
    return (MAX_POINTS - POINTS_AT_WIDEST) / (2 * scale.maxPercentHalf);
  }
  const widest =
    kind === 'magnitude'
      ? (2 * Math.log(scale.maxFactor)) / Math.LN2
      : 2 * scale.maxYearHalf;
  return (MAX_POINTS - POINTS_AT_WIDEST) / widest;
}

/**
 * Points of one locked interval; null bounds mean time ran out empty.
 * With a [scale] the current rule, without one the first rule (days
 * before the switch).
 */
export function scoreFor(kind, low, high, answer, scale = null) {
  if (low === null || high === null) return MIN_POINTS;
  const s = intervalScore(
    kind,
    low,
    high,
    answer,
    (scale?.maxPercentHalf ?? 0) > 0,
  );
  const k = scale
    ? pointsPerUnit(kind, scale)
    : kind === 'magnitude'
      ? POINTS_PER_LOG2
      : POINTS_PER_YEAR;
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
