const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createLazyPrivateLoginService } = require('../src/lazy-private-login.cjs');

test('Secret Manager values are read only when a private-login invocation needs the service', () => {
  let reads = 0;
  let creates = 0;
  const getService = createLazyPrivateLoginService({
    getRateKey: () => { reads++; return 'secret rate key'; },
    getApiKey: () => { reads++; return 'secret api key'; },
    create: config => { creates++; return config; },
  });

  assert.equal(reads, 0);
  assert.equal(creates, 0);
  const first = getService();
  assert.equal(reads, 2);
  assert.equal(creates, 1);
  assert.deepEqual(getService(), first);
  assert.equal(reads, 2);
  assert.equal(creates, 1);
});
