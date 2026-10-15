const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createPlacesProxy } = require('../src/places-proxy.cjs');

function memoryDb() {
  const docs = new Map();
  return {
    docs,
    doc(path) { return { path, async get() {
      const value = docs.get(path);
      return { exists: value !== undefined, get: key => value?.[key] };
    } }; },
    async runTransaction(callback) {
      const writes = [];
      const tx = {
        async get(ref) {
          const value = docs.get(ref.path);
          return { exists: value !== undefined, get: key => value?.[key] };
        },
        set(ref, value) { writes.push([ref.path, value]); },
      };
      const result = await callback(tx);
      for (const [path, value] of writes) docs.set(path, value);
      return result;
    },
  };
}
function callable(data, uid = 'alice') { return { data, auth: uid ? { uid } : null }; }
const place = {
  place_id: 'place-1', name: 'Pitch', formatted_address: 'Park Rd',
  geometry: { location: { lat: 41, lng: 29 } }, types: ['stadium'],
  photos: [{ photo_reference: 'photo-ref', html_attributions: ['Photographer'] }],
};
function jsonResponse(value) { return new Response(JSON.stringify(value), { status: 200, headers: { 'content-type': 'application/json' } }); }
function imageResponse(bytes = Buffer.from('image')) { return new Response(bytes, { status: 200, headers: { 'content-type': 'image/jpeg' } }); }
function setup(fetchImpl, overrides = {}) {
  const db = memoryDb();
  const proxy = createPlacesProxy({ db, getApiKey: () => 'test-key-not-for-output-123456', fetchImpl,
    enabled: true, now: () => 120_000, ...overrides });
  return { db, proxy };
}

test('Places search uses a fixed Google endpoint and returns only bounded legacy-shaped data and attributions', async () => {
  let requested;
  const { proxy } = setup(async url => { requested = new URL(url); return jsonResponse({
    status: 'OK', results: [place], html_attributions: ['Source'],
  }); });
  const result = await proxy(callable({ operation: 'search', query: 'football pitch', latitude: 41, longitude: 29 }));
  assert.equal(requested.origin + requested.pathname, 'https://maps.googleapis.com/maps/api/place/textsearch/json');
  assert.equal(requested.searchParams.get('key'), 'test-key-not-for-output-123456');
  assert.equal(requested.searchParams.get('radius'), '30000');
  assert.deepEqual(result, { status: 'OK', results: [{
    place_id: 'place-1', name: 'Pitch', formatted_address: 'Park Rd',
    geometry: { location: { lat: 41, lng: 29 } }, types: ['stadium'],
    photos: [{ photo_reference: 'photo-ref', height: undefined, width: undefined, html_attributions: ['Photographer'] }],
    html_attributions: [],
  }], html_attributions: ['Source'] });
  assert.equal(JSON.stringify(result).includes('test-key'), false);
});

test('details keeps source attributions and photo references without exposing upstream URLs', async () => {
  let requested;
  const { proxy } = setup(async url => { requested = new URL(url); return jsonResponse({ status: 'OK', result: place, html_attributions: ['By artist'] }); });
  const result = await proxy(callable({ operation: 'details', placeId: 'place-1' }));
  assert.equal(requested.pathname, '/maps/api/place/details/json');
  assert.equal(requested.searchParams.get('fields'), 'name,formatted_address,photos,geometry');
  assert.equal(result.result.place_id, 'place-1');
  assert.deepEqual(result.html_attributions, ['By artist']);
  assert.equal(JSON.stringify(result).includes('https://'), false);
});

test('photos with unusable or excessive credits are omitted instead of showing uncredited images', async () => {
  const uncreditable = { ...place, photos:[{photo_reference:'must-not-display',html_attributions:Array(9).fill('credit')}] };
  const { proxy } = setup(async () => jsonResponse({status:'OK',results:[uncreditable],html_attributions:['Source']}));
  const result = await proxy(callable({operation:'search',query:'football pitch'}));
  assert.equal(result.results[0].photos.length, 0);
  assert.deepEqual(result.results[0].html_attributions, []);
});

test('photo follows at most two HTTPS Google image redirects and returns bounded bytes only', async () => {
  const urls = [];
  const { proxy } = setup(async (url, options) => {
    urls.push({ url: new URL(url), options });
    if (urls.length === 1) return new Response(null, { status: 302, headers: { location: 'https://lh3.googleusercontent.com/photo' } });
    return imageResponse(Buffer.from([1, 2, 3]));
  });
  const result = await proxy(callable({ operation: 'photo', photoReference: 'ref' }));
  assert.equal(urls[0].url.pathname, '/maps/api/place/photo');
  assert.equal(urls[0].url.searchParams.has('key'), true);
  assert.equal(urls[1].url.href, 'https://lh3.googleusercontent.com/photo');
  assert.equal(urls[1].options.redirect, 'manual');
  assert.deepEqual(result, { imageBase64: 'AQID', mimeType: 'image/jpeg' });
  assert.equal(JSON.stringify(result).includes('googleusercontent'), false);
});

test('photo rejects non-Google redirect destinations and too many redirect hops', async () => {
  const external = setup(async () => new Response(null, { status: 302, headers: { location: 'https://example.com/steal' } })).proxy;
  await assert.rejects(external(callable({ operation: 'photo', photoReference: 'ref' })), { code: 'unavailable' });
  let calls = 0;
  const looping = setup(async () => { calls++; return new Response(null, { status: 302, headers: { location: `https://lh3.googleusercontent.com/${calls}` } }); }).proxy;
  await assert.rejects(looping(callable({ operation: 'photo', photoReference: 'ref' })), { code: 'unavailable' });
  assert.equal(calls, 3);
});

test('static map request fixes size, zoom and map type and never returns its URL or API key', async () => {
  let requested;
  const { proxy } = setup(async url => { requested = new URL(url); return imageResponse(); });
  const result = await proxy(callable({ operation: 'staticMap', latitude: 41, longitude: 29 }));
  assert.equal(requested.pathname, '/maps/api/staticmap');
  assert.equal(requested.searchParams.get('size'), '600x400');
  assert.equal(requested.searchParams.get('zoom'), '18');
  assert.equal(requested.searchParams.get('maptype'), 'satellite');
  assert.equal(JSON.stringify(result), JSON.stringify({ imageBase64: Buffer.from('image').toString('base64'), mimeType: 'image/jpeg' }));
});

test('proxy requires authentication, exact fields, enabled readiness, valid coordinates, and supported image MIME', async () => {
  const proxy = setup(async () => imageResponse()).proxy;
  await assert.rejects(proxy(callable({ operation: 'search', query: 'abc' }, null)), { code: 'unauthenticated' });
  await assert.rejects(proxy(callable({ operation: 'search', query: 'abc', callerUid: 'victim' })), { code: 'invalid-argument' });
  await assert.rejects(proxy(callable({ operation: 'staticMap', latitude: 91, longitude: 29 })), { code: 'invalid-argument' });
  const disabled = setup(async () => { throw new Error('must not fetch'); }, { enabled: false }).proxy;
  await assert.rejects(disabled(callable({ operation: 'search', query: 'abc' })), { code: 'unavailable' });
  const badMime = setup(async () => new Response('text', { status: 200, headers: { 'content-type': 'text/plain' } })).proxy;
  await assert.rejects(badMime(callable({ operation: 'staticMap', latitude: 41, longitude: 29 })), { code: 'unavailable' });
});

test('deleting or restricted accounts are rejected before rate state or billable upstream calls', async () => {
  for (const path of ['accountDeletionJobs/alice', '_moderationAccounts/alice']) {
    const db = memoryDb(); db.docs.set(path, { status: 'pending' });
    let requests = 0;
    const proxy = createPlacesProxy({ db, enabled: true, getApiKey: () => 'test-key-not-for-output-123456',
      fetchImpl: async () => { requests++; return jsonResponse({ status: 'ZERO_RESULTS' }); } });
    await assert.rejects(proxy(callable({ operation: 'search', query: 'pitch' })), { code: 'failed-precondition' });
    assert.equal(requests, 0);
    assert.equal([...db.docs.keys()].some(key => key.startsWith('_placesLimits/')), false);
  }
});

test('search body and binary response are bounded, and rate buckets isolate users', async () => {
  const db = memoryDb();
  const oversizedJson = setup(async () => new Response('x'.repeat(520_000), { status: 200 }), { db }).proxy;
  await assert.rejects(oversizedJson(callable({ operation: 'search', query: 'abc' })), { code: 'unavailable' });
  const tooLargeImage = setup(async () => imageResponse(Buffer.alloc(2 * 1024 * 1024 + 1)), { db }).proxy;
  await assert.rejects(tooLargeImage(callable({ operation: 'staticMap', latitude: 41, longitude: 29 })), { code: 'unavailable' });

  let count = 0;
  const rateDb = memoryDb();
  const rateProxy = createPlacesProxy({ db: rateDb, enabled: true, getApiKey: () => 'test-key-not-for-output-123456', now: () => 120_000,
    fetchImpl: async () => { count++; return jsonResponse({ status: 'ZERO_RESULTS', results: [] }); } });
  for (let i = 0; i < 20; i++) await rateProxy(callable({ operation: 'search', query: 'abc' }));
  await assert.rejects(rateProxy(callable({ operation: 'search', query: 'abc' })), { code: 'resource-exhausted' });
  await rateProxy(callable({ operation: 'search', query: 'abc' }, 'bob'));
  assert.equal(count, 21);
});

