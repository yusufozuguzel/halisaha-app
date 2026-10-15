const { test } = require('node:test');
const assert = require('node:assert/strict');
const { parseArgs } = require('../run_migration.js');

test('migration defaults to dry-run and requires an explicit target project', () => {
  assert.deepEqual(parseArgs(['--project', 'halisaha-app-d9ea1']), {
    apply: false, project: 'halisaha-app-d9ea1', confirmProject: null,
  });
  assert.throws(() => parseArgs([]), /--project/);
});

test('migration apply requires a second exact project confirmation', () => {
  assert.throws(() => parseArgs(['--project', 'halisaha-app-d9ea1', '--apply']), /--confirm-project/);
  assert.throws(() => parseArgs([
    '--project', 'halisaha-app-d9ea1', '--apply', '--confirm-project', 'another-project',
  ]), /exact same project ID/);
  assert.deepEqual(parseArgs([
    '--project', 'halisaha-app-d9ea1', '--apply', '--confirm-project', 'halisaha-app-d9ea1',
  ]), { apply: true, project: 'halisaha-app-d9ea1', confirmProject: 'halisaha-app-d9ea1' });
});

test('migration rejects malformed project IDs and unrecognized switches', () => {
  assert.throws(() => parseArgs(['--project', 'wrong/project']), /exact Firebase project ID/);
  assert.throws(() => parseArgs(['--project', 'halisaha-app-d9ea1', '--force']), /Unknown argument/);
});
