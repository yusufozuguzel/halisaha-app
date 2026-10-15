const { HttpsError } = require('firebase-functions/v2/https');
const { Timestamp } = require('firebase-admin/firestore');
const { identity, exactFields, requireEnabled } = require('./policy.cjs');

const MAX_JSON_BYTES = 512 * 1024;
const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const MAX_QUERY_LENGTH = 160;
const WINDOW_MS = 60_000;
const PHOTO_HOST_SUFFIX = '.googleusercontent.com';

function coordinate(value, name) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < (name === 'latitude' ? -90 : -180) ||
      value > (name === 'latitude' ? 90 : 180)) {
    throw new HttpsError('invalid-argument', 'Request could not be completed.');
  }
  return value;
}

function text(value, max, min = 1) {
  return typeof value === 'string' && value.trim().length >= min && value.length <= max &&
    !/[\u0000-\u001f\u007f]/.test(value);
}

async function boundedBytes(response, limit) {
  const length = Number(response.headers.get('content-length'));
  if (Number.isFinite(length) && length > limit) throw new Error('upstream_body_too_large');
  const reader = response.body?.getReader();
  if (!reader) throw new Error('upstream_body_missing');
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limit) {
        await reader.cancel();
        throw new Error('upstream_body_too_large');
      }
      chunks.push(Buffer.from(value));
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks, total);
}

function attributionList(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 8 || value.some(item =>
    typeof item !== 'string' || item.length > 1000 || /[\u0000-\u001f\u007f]/.test(item))) return null;
  return value;
}

function photoList(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 5).flatMap(photo => {
    if (!photo || !text(photo.photo_reference, 2048)) return [];
    const attributions = attributionList(photo.html_attributions);
    // Never surface a photo when required credits cannot be represented safely.
    if (attributions === null) return [];
    return [{
      photo_reference: photo.photo_reference,
      height: Number.isInteger(photo.height) && photo.height > 0 ? Math.min(photo.height, 100_000) : undefined,
      width: Number.isInteger(photo.width) && photo.width > 0 ? Math.min(photo.width, 100_000) : undefined,
      html_attributions: attributions,
    }];
  });
}

function placeResult(place) {
  const attributions = attributionList(place?.html_attributions);
  if (attributions === null) return null;
  const location = place?.geometry?.location;
  const lat = Number(location?.lat);
  const lng = Number(location?.lng);
  if (!text(place?.place_id, 256) || !Number.isFinite(lat) || !Number.isFinite(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return {
    place_id: place.place_id,
    name: text(place.name, 200) ? place.name : (text(place.formatted_address, 300) ? place.formatted_address : ''),
    formatted_address: text(place.formatted_address, 300) ? place.formatted_address : '',
    geometry: { location: { lat, lng } },
    types: Array.isArray(place.types) ? place.types.filter(type => text(type, 80)).slice(0, 30) : [],
    photos: photoList(place.photos),
    html_attributions: attributions,
  };
}

function createPlacesProxy({ db, getApiKey, fetchImpl = fetch, enabled = false, now = Date.now }) {
  async function rateLimit(uid, operation) {
    const window = Math.floor(now() / WINDOW_MS);
    const ref = db.doc(`_placesLimits/${uid}/windows/${operation}_${window}`);
    const caps = { search: 20, details: 30, photo: 40, staticMap: 30 };
    await db.runTransaction(async tx => {
      const snapshot = await tx.get(ref);
      const count = snapshot.exists ? snapshot.get('count') : 0;
      if (count >= caps[operation]) throw new HttpsError('resource-exhausted', 'Request could not be completed.');
      tx.set(ref, { count: count + 1, expiresAt: Timestamp.fromMillis((window + 2) * WINDOW_MS) });
    });
  }

  async function requestJson(url, apiKey) {
    const target = new URL(url);
    if (target.protocol !== 'https:' || target.hostname !== 'maps.googleapis.com') {
      throw new HttpsError('internal', 'Request could not be completed.');
    }
    target.searchParams.set('key', apiKey);
    let response;
    try { response = await fetchImpl(target, { redirect: 'manual', signal: AbortSignal.timeout(5000) }); }
    catch (_) { throw new HttpsError('unavailable', 'Request could not be completed.'); }
    if (!response.ok || response.status >= 300) throw new HttpsError('unavailable', 'Request could not be completed.');
    let body;
    try { body = JSON.parse((await boundedBytes(response, MAX_JSON_BYTES)).toString('utf8')); }
    catch (_) { throw new HttpsError('unavailable', 'Request could not be completed.'); }
    return body;
  }

  async function imageResponse(url, apiKey, { redirects = false } = {}) {
    const target = new URL(url);
    if (target.protocol !== 'https:' || target.hostname !== 'maps.googleapis.com') {
      throw new HttpsError('internal', 'Request could not be completed.');
    }
    target.searchParams.set('key', apiKey);
    let response;
    try { response = await fetchImpl(target, { redirect: 'manual', signal: AbortSignal.timeout(5000) }); }
    catch (_) { throw new HttpsError('unavailable', 'Request could not be completed.'); }
    if (redirects) {
      for (let hops = 0; response.status >= 300 && response.status < 400 && hops < 2; hops++) {
        const rawLocation = response.headers.get('location');
        if (!rawLocation) break;
        let next;
        try { next = new URL(rawLocation, target); } catch (_) { break; }
        if (next.protocol !== 'https:' || !next.hostname.endsWith(PHOTO_HOST_SUFFIX) || next.port || next.username || next.password) break;
        try { await response.body?.cancel(); } catch (_) { /* discard redirect body */ }
        try { response = await fetchImpl(next, { redirect: 'manual', signal: AbortSignal.timeout(5000) }); }
        catch (_) { throw new HttpsError('unavailable', 'Request could not be completed.'); }
      }
    }
    if (!response.ok || response.status >= 300) throw new HttpsError('unavailable', 'Request could not be completed.');
    const mimeType = (response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)) {
      throw new HttpsError('unavailable', 'Request could not be completed.');
    }
    try {
      const bytes = await boundedBytes(response, MAX_IMAGE_BYTES);
      return { imageBase64: bytes.toString('base64'), mimeType };
    } catch (_) { throw new HttpsError('unavailable', 'Request could not be completed.'); }
  }

  return async function placesProxy(request) {
    requireEnabled(enabled);
    const uid = identity(request);
    const operation = request.data?.operation;
    if (!['search', 'details', 'photo', 'staticMap'].includes(operation)) {
      throw new HttpsError('invalid-argument', 'Request could not be completed.');
    }
    let params;
    if (operation === 'search') {
      exactFields(request.data, ['operation', 'query', ...(request.data.latitude === undefined ? [] : ['latitude']),
        ...(request.data.longitude === undefined ? [] : ['longitude'])]);
      if (!text(request.data.query, MAX_QUERY_LENGTH, 3) ||
          (request.data.latitude === undefined) !== (request.data.longitude === undefined)) {
        throw new HttpsError('invalid-argument', 'Request could not be completed.');
      }
      params = { query: request.data.query.trim() };
      if (request.data.latitude !== undefined) {
        params.latitude = coordinate(request.data.latitude, 'latitude');
        params.longitude = coordinate(request.data.longitude, 'longitude');
      }
    } else if (operation === 'details') {
      exactFields(request.data, ['operation', 'placeId']);
      if (!text(request.data.placeId, 256)) throw new HttpsError('invalid-argument', 'Request could not be completed.');
      params = { placeId: request.data.placeId };
    } else if (operation === 'photo') {
      exactFields(request.data, ['operation', 'photoReference']);
      if (!text(request.data.photoReference, 2048)) throw new HttpsError('invalid-argument', 'Request could not be completed.');
      params = { photoReference: request.data.photoReference };
    } else {
      exactFields(request.data, ['operation', 'latitude', 'longitude']);
      params = { latitude: coordinate(request.data.latitude, 'latitude'), longitude: coordinate(request.data.longitude, 'longitude') };
    }

    const [deletionJob, restriction] = await Promise.all([
      db.doc(`accountDeletionJobs/${uid}`).get(),
      db.doc(`_moderationAccounts/${uid}`).get(),
    ]);
    if (deletionJob.exists || restriction.exists) {
      throw new HttpsError('failed-precondition', 'Request could not be completed.');
    }
    await rateLimit(uid, operation);
    let key;
    try { key = getApiKey(); } catch (_) { key = ''; }
    if (typeof key !== 'string' || key.length < 20 || key.length > 256) {
      throw new HttpsError('unavailable', 'Request could not be completed.');
    }
    if (operation === 'search') {
      const url = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
      url.searchParams.set('query', params.query);
      if (params.latitude !== undefined) {
        url.searchParams.set('location', `${params.latitude},${params.longitude}`);
        url.searchParams.set('radius', '30000');
      }
      const body = await requestJson(url, key);
      if (!['OK', 'ZERO_RESULTS'].includes(body.status)) throw new HttpsError('unavailable', 'Request could not be completed.');
      const attributions = attributionList(body.html_attributions);
      if (attributions === null) throw new HttpsError('unavailable', 'Request could not be completed.');
      const results = Array.isArray(body.results) ? body.results.map(placeResult).filter(Boolean).slice(0, 20) : [];
      return { status: body.status, results, html_attributions: attributions };
    }
    if (operation === 'details') {
      const url = new URL('https://maps.googleapis.com/maps/api/place/details/json');
      url.searchParams.set('place_id', params.placeId);
      url.searchParams.set('fields', 'name,formatted_address,photos,geometry');
      const body = await requestJson(url, key);
      if (body.status !== 'OK' || !body.result) throw new HttpsError('not-found', 'Request could not be completed.');
      const attributions = attributionList(body.html_attributions);
      if (attributions === null) throw new HttpsError('unavailable', 'Request could not be completed.');
      const result = placeResult({ ...body.result, place_id: params.placeId });
      return { status: 'OK', result: result || { photos: photoList(body.result.photos) }, html_attributions: attributions };
    }
    if (operation === 'photo') {
      const url = new URL('https://maps.googleapis.com/maps/api/place/photo');
      url.searchParams.set('maxwidth', '800');
      url.searchParams.set('maxheight', '800');
      url.searchParams.set('photo_reference', params.photoReference);
      return imageResponse(url, key, { redirects: true });
    }
    const url = new URL('https://maps.googleapis.com/maps/api/staticmap');
    url.searchParams.set('center', `${params.latitude},${params.longitude}`);
    url.searchParams.set('zoom', '18');
    url.searchParams.set('size', '600x400');
    url.searchParams.set('maptype', 'satellite');
    return imageResponse(url, key);
  };
}

module.exports = { createPlacesProxy, MAX_JSON_BYTES, MAX_IMAGE_BYTES };
