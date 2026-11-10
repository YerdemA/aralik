import assert from 'node:assert/strict';
import test from 'node:test';

import { cleanLook } from '../src/look.js';

test('accepts only valid mascot codes', () => {
  assert.equal(cleanLook('011100000'), '011100000'); // the philosopher
  assert.equal(cleanLook('124433354'), '124433354'); // every last option
  assert.equal(cleanLook('200000000'), null); // no third gender
  assert.equal(cleanLook('000000060'), null); // six glasses: 0…5
  assert.equal(cleanLook('000000005'), null); // five hair colours: 0…4
  assert.equal(cleanLook('01110000'), null); // eight digits: too short
  assert.equal(cleanLook('0111000000'), null);
  assert.equal(cleanLook('01110000a'), null);
  assert.equal(cleanLook(null), null);
  assert.equal(cleanLook(undefined), null);
});
