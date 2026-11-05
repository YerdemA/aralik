import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { isHit, scaleOf, scoreFor, MIN_POINTS } from '../src/scoring.js';

const vectors = JSON.parse(
  readFileSync(new URL('./scoring_vectors.json', import.meta.url), 'utf8'),
);

test('matches the app (vectors from lib/core/scoring.dart)', () => {
  assert.ok(vectors.length > 10);
  for (const v of vectors) {
    const scale = v.scaled ? scaleOf(v.kind, v.category, v.answer) : null;
    if (scale) {
      assert.equal(scale.maxFactor, v.maxFactor, JSON.stringify(v));
      assert.equal(scale.maxYearHalf, v.maxYearHalf, JSON.stringify(v));
    }
    assert.equal(
      scoreFor(v.kind, v.low, v.high, v.answer, scale),
      v.points,
      JSON.stringify(v),
    );
  }
});

test('an empty timeout scores the floor and misses', () => {
  assert.equal(scoreFor('magnitude', null, null, 5), MIN_POINTS);
  assert.equal(isHit(null, null, 5), false);
});

test('hits include both bounds', () => {
  assert.ok(isHit(1, 2, 1));
  assert.ok(isHit(1, 2, 2));
  assert.ok(!isHit(1, 2, 3));
});
