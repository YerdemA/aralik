import assert from 'node:assert/strict';
import test from 'node:test';

import {
  allowReaction,
  REACT_GAP_MS,
  REACT_MAX,
  REACT_WINDOW_MS,
  REACTIONS,
} from '../src/reactions.js';

test('only the eight fixed reactions pass', () => {
  assert.equal(REACTIONS.size, 8);
  assert.equal(allowReaction([], 'laugh', 1000).ok, true);
  assert.equal(allowReaction([], 'congrats', 1000).ok, true);
  assert.equal(allowReaction([], 'hello', 1000).ok, false);
  assert.equal(allowReaction([], undefined, 1000).ok, false);
  assert.equal(allowReaction([], '__proto__', 1000).ok, false);
});

test('a short gap between two reactions is refused', () => {
  const first = allowReaction([], 'laugh', 10_000);
  assert.deepEqual(first.times, [10_000]);
  assert.equal(allowReaction(first.times, 'sad', 10_000 + REACT_GAP_MS - 1).ok, false);
  assert.equal(allowReaction(first.times, 'sad', 10_000 + REACT_GAP_MS).ok, true);
});

test('at most REACT_MAX in a window, old ones forgotten', () => {
  let times = [];
  let now = 0;
  for (let i = 0; i < REACT_MAX; i++) {
    const r = allowReaction(times, 'wow', now);
    assert.equal(r.ok, true);
    times = r.times;
    now += REACT_GAP_MS;
  }
  assert.equal(allowReaction(times, 'wow', now).ok, false);
  const later = allowReaction(times, 'wow', times[0] + REACT_WINDOW_MS);
  assert.equal(later.ok, true);
  assert.equal(later.times.length, REACT_MAX);
});

test('garbage in the stored times is dropped', () => {
  const r = allowReaction(['x', null, 5], 'easy', 10_000);
  assert.equal(r.ok, true);
  assert.deepEqual(r.times, [5, 10_000]);
  assert.equal(allowReaction('nope', 'easy', 1).ok, true);
});
