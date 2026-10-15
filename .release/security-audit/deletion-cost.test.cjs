const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createSafetyService } = require('../../functions/src/safety.cjs');

function clone(value) {
  if (Array.isArray(value)) return value.map(clone);
  if (!value || Object.getPrototypeOf(value) !== Object.prototype) return value;
  return Object.fromEntries(Object.entries(value).map(([key, nested]) => [key, clone(nested)]));
}

function syntheticDb(seed) {
  const documents = new Map(Object.entries(seed).map(([path, data]) => [path, clone(data)]));
  const metrics = { queryPages: 0, queryResultReads: 0, pointReads: 0, transactionReads: 0 };
  const ref = path => ({
    path,
    id: path.split('/').at(-1),
    collection(name) { return collection(`${path}/${name}`); },
    async get() { return snapshot(path); },
    async update(patch) {
      if (!documents.has(path)) throw new Error(`missing ${path}`);
      documents.set(path, { ...documents.get(path), ...clone(patch) });
    },
    async create(data) {
      if (documents.has(path)) throw new Error(`exists ${path}`);
      documents.set(path, clone(data));
    },
    async delete() { documents.delete(path); },
  });
  const snapshot = path => {
    metrics.pointReads++;
    const data = documents.get(path);
    return {
      exists: data !== undefined,
      id: path.split('/').at(-1),
      ref: ref(path),
      updateTime: { seconds: 1, nanoseconds: 0 },
      data: () => data === undefined ? undefined : clone(data),
      get: key => data?.[key],
    };
  };
  function collection(path) {
    return {
      doc(id) { return ref(`${path}/${id}`); },
      orderBy() { return query(path, false); },
      where(field, operator, value) { return query(path, true, { field, operator, value }); },
    };
  }
  function query(path, group, filter) {
    let take = Infinity;
    let cursor = '';
    return {
      orderBy() { return this; },
      limit(value) { take = value; return this; },
      startAfter(value) { cursor = typeof value === 'string' ? value : value.path; return this; },
      async get() {
        metrics.queryPages++;
        const paths = [...documents.keys()].filter(candidate => {
          const parts = candidate.split('/');
          if (group) {
            if (parts.length < 4 || parts.at(-2) !== path) return false;
          } else if (parts.length !== path.split('/').length + 1 || !candidate.startsWith(`${path}/`)) return false;
          if (filter) {
            const item = documents.get(candidate);
            if (filter.operator === '==' && item?.[filter.field] !== filter.value) return false;
            if (filter.operator === 'in' && !filter.value.includes(item?.[filter.field])) return false;
          }
          return candidate > cursor;
        }).sort().slice(0, take);
        metrics.queryResultReads += paths.length;
        const docs = paths.map(pathName => {
          const data = documents.get(pathName);
          return { id:pathName.split('/').at(-1), ref:ref(pathName), data:()=>clone(data), get:key=>data?.[key] };
        });
        return { docs, empty:docs.length === 0, size:docs.length, at: index => docs.at(index) };
      },
    };
  }
  const db = {
    collection,
    collectionGroup: name => query(name, true),
    doc: ref,
    async recursiveDelete(target) {
      for (const path of [...documents.keys()]) if (path === target.path || path.startsWith(`${target.path}/`)) documents.delete(path);
    },
    async runTransaction(fn) {
      return fn({
        get: async target => { metrics.transactionReads++; return snapshot(target.path); },
        set(target, data) { documents.set(target.path, clone(data)); },
        create(target, data) {
          if (documents.has(target.path)) throw new Error(`exists ${target.path}`);
          documents.set(target.path, clone(data));
        },
        update(target, patch) {
          if (!documents.has(target.path)) throw new Error(`missing ${target.path}`);
          documents.set(target.path, { ...documents.get(target.path), ...clone(patch) });
        },
        delete(target) { documents.delete(target.path); },
      });
    },
  };
  return { db, metrics, documents };
}

test('fresh authenticated deletion jobs rescan and reread unrelated root records', async () => {
  const recordsPerCollection = 250;
  const fakeIdentities = 5;
  const seed = {};
  for (const collectionName of ['matches', 'users', 'contentReports']) {
    for (let i = 0; i < recordsPerCollection; i++) {
      const id = `${collectionName}_${String(i).padStart(3, '0')}`;
      seed[`${collectionName}/${id}`] = collectionName === 'matches'
        ? { title:'unrelated', createdBy:'unrelated-owner', currentPlayers:[] }
        : collectionName === 'users'
          ? { fullName:'unrelated', blockedUsers:[] }
          : { type:'user', targetId:'unrelated-owner', reporterId:'unrelated-reporter' };
    }
  }
  const { db, metrics } = syntheticDb(seed);
  const auth = { async deleteUser() {} };
  const bucket = { async getFiles() { return [[]]; } };
  const safety = createSafetyService({ db, auth, bucket, deletionEnabled:true, pageSize:100 });

  for (let index = 0; index < fakeIdentities; index++) {
    const uid = `new-auth-only-${index}`; // No corresponding user profile or account record.
    const request = { auth:{ uid, token:{ auth_time:Math.floor(Date.now()/1000) } }, data:{} };
    assert.deepEqual(await safety.requestDeletion(request), { accepted:true });
    await safety.processDeletion(uid);
  }

  const expectedDocsPerJob = recordsPerCollection * 3;
  assert.equal(metrics.queryResultReads, expectedDocsPerJob * fakeIdentities);
  console.log(JSON.stringify({
    syntheticUnrelatedDocs:expectedDocsPerJob,
    recentAuthOnlyIdentities:fakeIdentities,
    profileLookupsRequiredBeforeJob:0,
    queryResultDocumentReads:metrics.queryResultReads,
    transactionDocumentReads:metrics.transactionReads,
    queryPages:metrics.queryPages,
  }));
});
