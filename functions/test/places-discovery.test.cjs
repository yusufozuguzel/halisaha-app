const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');

const functionsDir = resolve(__dirname, '..');
const discover = `
  const { dirname, resolve } = require('node:path');
  const sdkLib = resolve(dirname(require.resolve('firebase-functions')), '..');
  const { SecretParam } = require(resolve(sdkLib, 'params/types.js'));
  SecretParam.prototype.value = () => { throw new Error('Secret resolved during discovery'); };
  const { loadStack } = require(resolve(sdkLib, 'runtime/loader.js'));
  loadStack(process.cwd()).then(stack => {
    const endpoint = stack.endpoints.placesProxy;
    process.stdout.write(JSON.stringify({
      params: (stack.params || []).map(param => param.name),
      secrets: endpoint.secretEnvironmentVariables || [],
      concurrency: endpoint.concurrency,
      maxInstances: endpoint.maxInstances,
    }));
  }).catch(error => { process.stderr.write(error.message); process.exitCode = 1; });
`;

function manifest(enabled) {
  // Isolate SDK global manifests and require caches, and never inherit real
  // credentials. Discovery only constructs local endpoint metadata.
  const env = {
    PATH: process.env.PATH,
    SystemRoot: process.env.SystemRoot,
    TEMP: process.env.TEMP,
    TMP: process.env.TMP,
    GCLOUD_PROJECT: 'demo-depar-discovery',
    FIREBASE_CONFIG: JSON.stringify({
      projectId: 'demo-depar-discovery',
      storageBucket: 'demo-depar-discovery.appspot.com',
    }),
    PLACES_PROXY_READY: String(enabled),
  };
  return JSON.parse(execFileSync(process.execPath, ['-e', discover], {
    cwd: functionsDir, env, encoding: 'utf8', timeout: 30_000,
  }));
}

test('disabled Places discovery neither declares nor binds the new Maps secret', () => {
  const result = manifest(false);
  assert.equal(result.params.includes('GOOGLE_MAPS_API_KEY'), false);
  assert.equal(result.secrets.some(secret => secret.key === 'GOOGLE_MAPS_API_KEY'), false);
});

test('enabled Places discovery binds its secret lazily and caps binary request concurrency', () => {
  const result = manifest(true);
  assert.equal(result.params.filter(name => name === 'GOOGLE_MAPS_API_KEY').length, 1);
  assert.equal(result.secrets.filter(secret => secret.key === 'GOOGLE_MAPS_API_KEY').length, 1);
  assert.equal(result.concurrency, 4);
  assert.equal(result.maxInstances, 5);
});
