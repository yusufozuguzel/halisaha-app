const { test } = require('node:test');
const assert = require('node:assert/strict');
const config = require('../rules/firestore.indexes.candidate.json');

test('candidate indexes cover current app composites and expiring rate-limit state', () => {
  const indexes = new Set(config.indexes.map(index => `${index.collectionGroup}:${index.fields
    .map(field => `${field.fieldPath}:${field.arrayConfig || field.order}`).join(',')}`));
  for (const expected of [
    'users:profileVersion:ASCENDING,fullName:ASCENDING',
    'matches:currentPlayers:CONTAINS,date:ASCENDING',
    'matches:currentPlayers:CONTAINS,createdAt:ASCENDING',
    'matches:status:ASCENDING,date:ASCENDING',
    'matches:createdBy:ASCENDING,date:ASCENDING',
    'notifications:receiverId:ASCENDING,status:ASCENDING',
  ]) assert.ok(indexes.has(expected), `missing ${expected}`);

  assert.deepEqual(config.fieldOverrides.find(field =>
    field.collectionGroup === '_loginLimits' && field.fieldPath === 'expiresAt'), {
    collectionGroup: '_loginLimits', fieldPath: 'expiresAt', ttl: true, indexes: [],
  });
  assert.deepEqual(config.fieldOverrides.find(field =>
    field.collectionGroup === '_profilePhotoLimits' && field.fieldPath === 'expiresAt'), {
    collectionGroup: '_profilePhotoLimits', fieldPath: 'expiresAt', ttl: true, indexes: [],
  });
  assert.deepEqual(config.fieldOverrides.find(field =>
    field.collectionGroup === 'windows' && field.fieldPath === 'expiresAt'), {
    collectionGroup: 'windows', fieldPath: 'expiresAt', ttl: true, indexes: [],
  });
});
