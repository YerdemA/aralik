import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  isMathId,
  mathAnswer,
  pickMathQuestions,
  PRIME_COUNTS,
  SeededRandom,
} from '../src/math.js';

const vectors = JSON.parse(
  readFileSync(new URL('./math_vectors.json', import.meta.url), 'utf8'),
);

test('mulberry32 gives the same numbers as the app', () => {
  const r = new SeededRandom(12345);
  assert.deepEqual(
    [r.nextUint32(), r.nextUint32(), r.nextUint32()],
    [4207900869, 1317490944, 2079646450],
  );
});

test('every answer the app makes, the server makes too', () => {
  const wrong = [];
  for (const { id, answer, unit } of vectors) {
    const got = mathAnswer(id);
    if (got.answer !== answer || got.unit !== unit) {
      wrong.push(`${id}: app ${answer} ${unit}, server ${got.answer} ${got.unit}`);
    }
  }
  assert.deepEqual(wrong, [], wrong.slice(0, 10).join('\n'));
  assert.ok(vectors.length > 3000);
});

test('the prime count table matches a sieve', () => {
  const n = 2_000_000;
  const composite = new Uint8Array(n + 1);
  let count = 0;
  for (let i = 2; i <= n; i++) {
    if (!composite[i]) {
      count++;
      for (let j = i * i; j <= n; j += i) composite[j] = 1;
    }
    if (i >= 100000 && i % 50000 === 0) {
      assert.equal(PRIME_COUNTS[(i - 100000) / 50000], count, `π(${i})`);
    }
  }
});

test('a math duel: five different topics, easy to hard, valid ids', () => {
  let k = 0;
  const ids = pickMathQuestions((n) => (k++ * 7) % n);
  assert.equal(ids.length, 5);
  assert.deepEqual(
    ids.map((id) => id.split(':')[2]),
    ['1', '1', '2', '2', '3'],
  );
  assert.equal(new Set(ids.map((id) => id.split(':')[1])).size, 5);
  for (const id of ids) assert.ok(isMathId(id));
  assert.equal(isMathId('q0001'), false);
  assert.equal(isMathId('math:yok:1:5'), false);
  assert.equal(mathAnswer('math:carpma:4:5'), null);
});
