const crypto = require('node:crypto');
const path = require('node:path');
const { FieldPath } = require('firebase-admin/firestore');

const TARGET_PROJECT = 'halisaha-app-d9ea1';
const FIREBASE_TOOLS_VERSION = '15.33.0';
const MAX_AVATAR_BYTES = 1024 * 1024;
const SAFE_SEARCH_SCOPE = 'https://www.googleapis.com/auth/cloud-platform';
const SAFE_SERVICE_REASONS = new Set([
  'ACCESS_NOT_CONFIGURED', 'API_DISABLED', 'API_KEY_INVALID', 'API_KEY_SERVICE_BLOCKED',
  'BILLING_DISABLED', 'CONSUMER_INVALID', 'DAILY_LIMIT_EXCEEDED', 'PERMISSION_DENIED',
  'PROJECT_DELETED', 'PROJECT_INVALID', 'RATE_LIMIT_EXCEEDED', 'RESOURCE_EXHAUSTED',
  'SERVICE_DISABLED', 'SERVICE_USAGE_NOT_ACTIVATED', 'USER_PROJECT_DENIED',
]);

function parseArgs(argv) {
  const result = { project: null, bucket: null, confirmProject: null, apply: false,
    scanVision: false, firebaseToolsRoot: process.env.FIREBASE_TOOLS_ROOT || null };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--apply') result.apply = true;
    else if (arg === '--scan-vision') result.scanVision = true;
    else if (['--project', '--bucket', '--confirm-project', '--firebase-tools-root'].includes(arg)) {
      const value = argv[++i];
      if (!value || value.startsWith('--')) throw new Error(`${arg} requires a value`);
      const key = ({ '--project':'project', '--bucket':'bucket', '--confirm-project':'confirmProject',
        '--firebase-tools-root':'firebaseToolsRoot' })[arg];
      result[key] = value;
    } else throw new Error(`Unrecognized option: ${arg}`);
  }
  if (result.project !== TARGET_PROJECT) throw new Error(`--project must be ${TARGET_PROJECT}`);
  if (!result.bucket || !/^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$/.test(result.bucket)) {
    throw new Error('--bucket must name the intended Firebase Storage bucket');
  }
  if (result.apply && result.confirmProject !== result.project) {
    throw new Error('--apply requires --confirm-project with the exact project ID');
  }
  if (result.firebaseToolsRoot && !path.isAbsolute(result.firebaseToolsRoot)) {
    throw new Error('--firebase-tools-root must be an absolute path');
  }
  return result;
}

function createFirebaseCliCredential({ authModule, scope = SAFE_SEARCH_SCOPE }) {
  const account = authModule.getGlobalDefaultAccount?.();
  const refreshToken = account?.tokens?.refresh_token;
  if (!refreshToken) throw new Error('No default Firebase CLI login is available');
  return {
    async getAccessToken() {
      const token = await authModule.getAccessToken(refreshToken, [scope]);
      const expiresIn = Number(token?.expires_in ?? ((token?.expires_at - Date.now()) / 1000));
      if (typeof token?.access_token !== 'string' || token.access_token.length < 20 ||
          !Number.isFinite(expiresIn) || expiresIn <= 0) {
        throw new Error('Firebase CLI did not return a usable access token');
      }
      return { access_token: token.access_token, expires_in: Math.floor(expiresIn) };
    },
  };
}

function createOAuth2Client(credential, OAuth2Client) {
  const client = new OAuth2Client();
  client.refreshHandler = async () => {
    const access = await credential.getAccessToken();
    return { access_token:access.access_token, expiry_date:Date.now() + access.expires_in * 1000 };
  };
  return client;
}

function loadStorageOAuth2Client() {
  const storageRoot = path.resolve(path.dirname(require.resolve('@google-cloud/storage')), '../../..');
  const storageAuthPath = path.join(storageRoot, 'node_modules', 'google-auth-library');
  try { return require(storageAuthPath).OAuth2Client; }
  catch (error) {
    if (error?.code !== 'MODULE_NOT_FOUND') throw error;
    return require('google-auth-library').OAuth2Client;
  }
}

function firestoreValue(value) {
  if (value.stringValue !== undefined) return value.stringValue;
  if (value.integerValue !== undefined) return Number(value.integerValue);
  if (value.booleanValue !== undefined) return value.booleanValue;
  if (value.timestampValue !== undefined) return value.timestampValue;
  return null;
}

function timestampParts(value) {
  const date = new Date(value);
  const millis = date.getTime();
  return { seconds:Math.floor(millis / 1000), nanoseconds:(millis % 1000) * 1e6 };
}

function createFirestoreRest({ projectId, oauthClient }) {
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  async function request(url, options) {
    try {
      const response = await oauthClient.request({ url, ...options, responseType:'json' });
      return response.data;
    } catch (error) {
      const status = error?.response?.status;
      if (status === 409 || status === 412) throw { code:9 };
      throw error;
    }
  }
  function snapshot(document, restPageToken = null) {
    const data = Object.fromEntries(Object.entries(document.fields || {}).map(([key, value]) => [key, firestoreValue(value)]));
    const updateTime = timestampParts(document.updateTime);
    return {
      id:document.name.split('/').at(-1), exists:true, updateTime, restPageToken,
      data:() => data, get:key => data[key],
      ref:{
        get:async () => {
          try {
            const latest = await request(`${base}/users/${encodeURIComponent(document.name.split('/').at(-1))}`, { method:'GET' });
            return snapshot(latest);
          } catch (error) {
            if (error?.response?.status === 404) return { exists:false };
            throw error;
          }
        },
        update:async (patch, precondition) => {
          await request(`${base}:commit`, { method:'POST', data:{ writes:[{
            update:{ name:document.name, fields:{
              avatarUrl:{ stringValue:patch.avatarUrl }, avatarType:{ stringValue:patch.avatarType },
              avatarData:{ stringValue:patch.avatarData },
            } }, updateMask:{ fieldPaths:['avatarUrl','avatarType','avatarData'] },
            currentDocument:{ updateTime:document.updateTime },
          }] } });
        },
      },
    };
  }
  return { collection(name) {
    if (name !== 'users') throw new Error('Avatar migration only supports the users collection');
    let pageSize = 50, pageToken = null, done = false;
    const chain = {
      orderBy() { return this; }, limit(value) { pageSize = value; return this; },
      startAfter(cursor) { pageToken = cursor?.restPageToken || null; done = !pageToken; return this; },
      get:async () => {
        if (done) return { empty:true, docs:[] };
        const query = new URLSearchParams({ pageSize:String(pageSize), orderBy:'__name__' });
        if (pageToken) query.set('pageToken', pageToken);
        const page = await request(`${base}/users?${query}`, { method:'GET' });
        const docs = (page.documents || []).map(document => snapshot(document));
        if (docs.length && page.nextPageToken) docs[docs.length - 1].restPageToken = page.nextPageToken;
        if (!page.nextPageToken) done = true;
        return { empty:docs.length === 0, docs };
      },
    };
    return chain;
  } };
}

function createIdentityPlatformAuth({ projectId, oauthClient }) {
  return { async getUser(uid) {
    const url = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`;
    try {
      const result = await oauthClient.request({ url, method:'POST', data:{ localId:[uid] }, responseType:'json' });
      const user = result.data?.users?.[0];
      if (!user) throw { code:'auth/user-not-found' };
      return { uid:user.localId };
    } catch (error) {
      if (error?.response?.status === 404 || error?.response?.data?.error?.message === 'USER_NOT_FOUND' ||
          error?.code === 'auth/user-not-found') {
        throw { code:'auth/user-not-found' };
      }
      throw error;
    }
  } };
}

function loadFirebaseCliCredential(firebaseToolsRoot) {
  if (!firebaseToolsRoot) throw new Error('Set FIREBASE_TOOLS_ROOT to the installed Firebase CLI package directory');
  const pkg = require(path.join(firebaseToolsRoot, 'package.json'));
  if (pkg.version !== FIREBASE_TOOLS_VERSION) {
    throw new Error(`This credential bridge requires firebase-tools ${FIREBASE_TOOLS_VERSION}`);
  }
  const authModule = require(path.join(firebaseToolsRoot, 'lib', 'auth.js'));
  return createFirebaseCliCredential({ authModule });
}

function decodeLegacyJpeg(encoded) {
  if (typeof encoded !== 'string' || encoded.length === 0 || encoded.length > 4 * Math.ceil(MAX_AVATAR_BYTES / 3) ||
      !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)) return null;
  const bytes = Buffer.from(encoded, 'base64');
  if (bytes.length < 4 || bytes.length > MAX_AVATAR_BYTES ||
      bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff ||
      bytes.toString('base64') !== encoded) return null;
  return bytes;
}

function safeSearchPassed(annotation) {
  const likelihoods = new Set(['VERY_UNLIKELY', 'UNLIKELY', 'POSSIBLE', 'LIKELY', 'VERY_LIKELY']);
  if (!annotation || annotation.error ||
      !['adult', 'violence', 'racy'].every(key => likelihoods.has(annotation[key]))) return false;
  return !['LIKELY', 'VERY_LIKELY'].includes(annotation.adult) &&
    !['LIKELY', 'VERY_LIKELY'].includes(annotation.violence) &&
    annotation.racy !== 'VERY_LIKELY';
}

function recognizedServiceReason(errorPayload) {
  const apiError = errorPayload?.error || errorPayload || {};
  const candidates = [
    ...(Array.isArray(apiError.errors) ? apiError.errors.map(item => item?.reason) : []),
    ...(Array.isArray(apiError.details) ? apiError.details.map(item => item?.reason) : []),
  ];
  return candidates.find(reason => typeof reason === 'string' && SAFE_SERVICE_REASONS.has(reason)) || null;
}

function safeErrorDiagnostics(error) {
  const diagnostics = {};
  const name = error?.name;
  const status = error?.status ?? error?.response?.status;
  const code = error?.code;
  const serviceReason = error?.serviceReason;
  if (typeof name === 'string' && /^[A-Za-z]{1,32}Error$/.test(name)) diagnostics.name = name;
  if (Number.isInteger(status) && status >= 100 && status <= 599) diagnostics.status = status;
  if (Number.isInteger(code)) diagnostics.code = code;
  if (typeof serviceReason === 'string' && SAFE_SERVICE_REASONS.has(serviceReason)) {
    diagnostics.serviceReason = serviceReason;
  }
  return diagnostics;
}

function formatCliError(error) {
  const safe = error instanceof Error && /^(--|Unrecognized option|This credential bridge|Set FIREBASE_TOOLS_ROOT|No default Firebase CLI login|Firebase CLI did not|Vision SafeSearch|Apply requires)/.test(error.message)
    ? error.message : 'Avatar migration stopped safely; details were omitted.';
  const diagnostics = safeErrorDiagnostics(error);
  return `${safe}${Object.keys(diagnostics).length ? ` ${JSON.stringify(diagnostics)}` : ''}`;
}

function createVisionClient({ credential, projectId = TARGET_PROJECT, fetchImpl = globalThis.fetch }) {
  if (typeof fetchImpl !== 'function') throw new Error('Fetch API is unavailable');
  if (projectId !== TARGET_PROJECT) throw new Error(`Vision quota project must be ${TARGET_PROJECT}`);
  return {
    async safeSearchDetection(bytes) {
      const access = await credential.getAccessToken();
      const response = await fetchImpl('https://vision.googleapis.com/v1/images:annotate', {
        method: 'POST',
        headers: { Authorization: `Bearer ${access.access_token}`, 'Content-Type': 'application/json',
          'x-goog-user-project':projectId },
        body: JSON.stringify({ requests: [{ image: { content: bytes.toString('base64') },
          features: [{ type: 'SAFE_SEARCH_DETECTION' }] }] }),
      });
      if (!response.ok) {
        let payload;
        try { payload = await response.json(); } catch (_) { /* omit untrusted response data */ }
        const error = new Error('Vision SafeSearch request failed');
        if (Number.isInteger(response.status) && response.status >= 100 && response.status <= 599) {
          error.status = response.status;
        }
        error.serviceReason = recognizedServiceReason(payload);
        throw error;
      }
      const result = (await response.json())?.responses?.[0];
      if (result?.error) {
        const error = new Error('Vision SafeSearch response was incomplete');
        if (Number.isInteger(result.error.code) && result.error.code >= 100 && result.error.code <= 599) {
          error.status = result.error.code;
        }
        error.serviceReason = recognizedServiceReason(result.error);
        throw error;
      }
      if (!result?.safeSearchAnnotation) throw new Error('Vision SafeSearch response was incomplete');
      return result.safeSearchAnnotation;
    },
  };
}

function downloadUrl(bucketName, objectName, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(objectName)}?alt=media&token=${token}`;
}

function timestampEqual(left, right) {
  if (left?.isEqual) return left.isEqual(right);
  if (right?.isEqual) return right.isEqual(left);
  return left?.seconds === right?.seconds && left?.nanoseconds === right?.nanoseconds;
}

function isMissingAuth(error) {
  return error?.code === 'auth/user-not-found';
}

function isPreconditionFailure(error) {
  return [5, 9, 412, '5', '9', '412', 'failed-precondition', 'conditionNotMet'].includes(error?.code);
}

async function migrateLegacyAvatars({ db, auth, bucket, visionClient, apply = false, pageSize = 50,
  uuid = crypto.randomUUID }) {
  if (apply && !visionClient) throw new Error('Apply requires Vision SafeSearch');
  const counts = { scanned:0, legacyCandidates:0, ready:0, uploaded:0, updated:0,
    missingAuth:0, invalidImage:0, alreadyHasUrl:0, objectExists:0, changedDuringRun:0,
    moderationRejected:0, visionRequired:0, uploadRace:0 };
  let cursor;
  while (true) {
    let query = db.collection('users').orderBy(FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      counts.scanned++;
      const data = doc.data();
      if (data.avatarType !== 'base64' || typeof data.avatarData !== 'string') continue;
      counts.legacyCandidates++;
      if (typeof data.avatarUrl === 'string' && data.avatarUrl.length > 0) { counts.alreadyHasUrl++; continue; }
      const bytes = decodeLegacyJpeg(data.avatarData);
      if (!bytes) { counts.invalidImage++; continue; }
      try { await auth.getUser(doc.id); }
      catch (error) {
        if (isMissingAuth(error)) { counts.missingAuth++; continue; }
        throw error;
      }
      const objectName = `profile_images/${doc.id}.jpg`;
      const file = bucket.file(objectName);
      if ((await file.exists())[0]) { counts.objectExists++; continue; }
      if (!visionClient) { counts.visionRequired++; continue; }
      const annotation = await visionClient.safeSearchDetection(bytes);
      if (!safeSearchPassed(annotation)) { counts.moderationRejected++; continue; }
      counts.ready++;
      if (!apply) continue;

      const current = await doc.ref.get();
      if (!current.exists || !timestampEqual(current.updateTime, doc.updateTime) ||
          current.get('avatarType') !== 'base64' || current.get('avatarData') !== data.avatarData ||
          (typeof current.get('avatarUrl') === 'string' && current.get('avatarUrl').length > 0)) {
        counts.changedDuringRun++;
        continue;
      }
      if ((await file.exists())[0]) { counts.objectExists++; continue; }

      const token = uuid();
      try {
        await file.save(bytes, {
          resumable:false,
          metadata:{ contentType:'image/jpeg', metadata:{ firebaseStorageDownloadTokens:token,
            deparLegacyAvatarMigration:'v1' } },
          preconditionOpts:{ ifGenerationMatch:0 },
        });
      } catch (error) {
        if (isPreconditionFailure(error)) { counts.uploadRace++; continue; }
        throw error;
      }
      const [uploadedMetadata] = await file.getMetadata();
      const metadata = uploadedMetadata.metadata || {};
      const tokenList = String(metadata.firebaseStorageDownloadTokens || '').split(',');
      const expectedHash = crypto.createHash('md5').update(bytes).digest('base64');
      if (!tokenList.includes(token) || metadata.deparLegacyAvatarMigration !== 'v1' ||
          uploadedMetadata.md5Hash !== expectedHash || !uploadedMetadata.generation) {
        counts.uploadRace++;
        continue;
      }
      const generation = String(uploadedMetadata.generation);
      try {
        await doc.ref.update({ avatarUrl:downloadUrl(bucket.name, objectName, token),
          avatarType:'icon', avatarData:'0' }, { lastUpdateTime:doc.updateTime });
        counts.uploaded++;
        counts.updated++;
      } catch (error) {
        if (!isPreconditionFailure(error)) throw error;
        try { await file.delete({ ifGenerationMatch:generation }); } catch (cleanupError) {
          if (!isPreconditionFailure(cleanupError) && Number(cleanupError?.code) !== 404) throw cleanupError;
        }
        counts.changedDuringRun++;
      }
    }
    cursor = page.docs.at(-1);
  }
  return counts;
}

async function runCli(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.apply && !options.scanVision) {
    // Vision is mandatory before upload; applying implies scanning every candidate.
    options.scanVision = true;
  }
  const credential = loadFirebaseCliCredential(options.firebaseToolsRoot);
  const { Storage } = require('@google-cloud/storage');
  const OAuth2Client = loadStorageOAuth2Client();
  const oauthClient = createOAuth2Client(credential, OAuth2Client);
  const db = createFirestoreRest({ projectId:options.project, oauthClient });
  const auth = createIdentityPlatformAuth({ projectId:options.project, oauthClient });
  const bucket = new Storage({ projectId:options.project, authClient:oauthClient }).bucket(options.bucket);
  const visionClient = options.scanVision ? createVisionClient({ credential, projectId:options.project }) : null;
  const counts = await migrateLegacyAvatars({ db, auth, bucket, visionClient, apply:options.apply });
  process.stdout.write(`${JSON.stringify({ project:options.project, mode:options.apply ? 'apply' : 'dry-run', counts })}\n`);
}

if (require.main === module) {
  runCli().catch(error => {
    process.stderr.write(`${formatCliError(error)}\n`);
    process.exitCode = 1;
  });
}

module.exports = { TARGET_PROJECT, FIREBASE_TOOLS_VERSION, parseArgs, createFirebaseCliCredential,
  createOAuth2Client, loadStorageOAuth2Client, createFirestoreRest, createIdentityPlatformAuth, decodeLegacyJpeg,
  safeSearchPassed, recognizedServiceReason, safeErrorDiagnostics, formatCliError,
  createVisionClient, downloadUrl, migrateLegacyAvatars };
