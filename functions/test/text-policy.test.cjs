const { test } = require('node:test');
const assert = require('node:assert/strict');
const { publicTextAllowed } = require('../src/text-policy.cjs');

test('public text policy blocks explicit high-confidence tokens without substring false positives', () => {
  for (const value of ['siktir', 'SİKTİR', 'FUCK', 'x!fuck!y', 'a\nbitch']) {
    assert.equal(publicTextAllowed(value, 100), false, value);
  }
  for (const value of ['Mamak', 'Gökçe', 'Sivas', 'Takım', 'Beyoğlu']) {
    assert.equal(publicTextAllowed(value, 100), true, value);
  }
  assert.equal(publicTextAllowed('fine\u0001text', 100), false);
  assert.equal(publicTextAllowed('x'.repeat(11), 10), false);
});
