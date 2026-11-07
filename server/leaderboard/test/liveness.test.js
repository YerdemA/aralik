import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  isStale,
  nextAlarm,
  pings,
  PING,
  PONG,
  STALE_MS,
} from '../src/liveness.js';

test('a connection is dead after STALE_MS without a pong', () => {
  assert.equal(isStale(1000, null, 1000 + STALE_MS), false);
  assert.equal(isStale(1000, null, 1001 + STALE_MS), true);
  // A recent pong keeps it alive.
  assert.equal(isStale(1000, 50_000, 50_000 + STALE_MS - 1), false);
  assert.equal(isStale(1000, 50_000, 50_001 + STALE_MS), true);
});

test('the alarm is the rules time or an earlier check', () => {
  assert.equal(nextAlarm(null, null, 0), null);
  assert.equal(nextAlarm(undefined, 4000, 100), 4100);
  assert.equal(nextAlarm(9000, null, 100), 9000);
  assert.equal(nextAlarm(9000, 4000, 100), 4100);
  assert.equal(nextAlarm(2000, 4000, 100), 2000);
});

test('only connections that say so are checked; the ping is exact', () => {
  assert.equal(pings(new URLSearchParams('hb=1')), true);
  assert.equal(pings(new URLSearchParams('v=1')), false);
  assert.equal(PING, JSON.stringify({ t: 'ping' }));
  assert.equal(PONG, JSON.stringify({ t: 'pong' }));
});
