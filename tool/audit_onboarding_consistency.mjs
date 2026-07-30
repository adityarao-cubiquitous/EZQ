import { readFile, writeFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const config = JSON.parse(await readFile(configPath, 'utf8'));
let accessToken = config.tokens?.access_token;
if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login.');
}

function httpsRequest({ hostname, path, method = 'GET', headers = {}, body }) {
  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname,
        path,
        method,
        headers,
      },
      (response) => {
        let body = '';
        response.on('data', (chunk) => {
          body += chunk;
        });
        response.on('end', () => {
          const parsed = body ? JSON.parse(body) : {};
          if (response.statusCode >= 200 && response.statusCode < 300) {
            resolve(parsed);
            return;
          }
          reject(new Error(`${response.statusCode} ${JSON.stringify(parsed)}`));
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

if ((config.tokens?.expires_at ?? 0) <= Date.now() + 60_000) {
  const body = new URLSearchParams({
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: config.tokens.refresh_token,
    grant_type: 'refresh_token',
  }).toString();
  const refreshed = await httpsRequest({
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded',
      'content-length': Buffer.byteLength(body),
    },
    body,
  });
  accessToken = refreshed.access_token;
  config.tokens = {
    ...config.tokens,
    ...refreshed,
    expires_at: Date.now() + refreshed.expires_in * 1000,
  };
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`);
}

function httpsJson(path) {
  return httpsRequest({
    hostname: 'firestore.googleapis.com',
    path,
    headers: { authorization: `Bearer ${accessToken}` },
  });
}

function fromValue(value) {
  if (!value) return null;
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(fromValue);
  }
  if ('mapValue' in value) return fromFields(value.mapValue.fields ?? {});
  return null;
}

function fromFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, fromValue(value)]),
  );
}

async function listCollection(collection) {
  const documents = [];
  let pageToken = '';
  do {
    const query = new URLSearchParams({ pageSize: '100' });
    if (pageToken) query.set('pageToken', pageToken);
    const response = await httpsJson(
      `/v1/projects/${projectId}/databases/(default)/documents/` +
        `${encodeURIComponent(collection)}?${query}`,
    );
    documents.push(...(response.documents ?? []));
    pageToken = response.nextPageToken ?? '';
  } while (pageToken);
  return documents.map((document) => ({
    id: document.name.split('/').pop(),
    data: fromFields(document.fields),
  }));
}

const [branches, admins] = await Promise.all([
  listCollection('restaurantBranches'),
  listCollection('admins'),
]);
const branchById = new Map(branches.map((branch) => [branch.id, branch.data]));
const inconsistencies = [];

for (const branch of branches) {
  const completed = branch.data.onboardingCompleted === true;
  const expectedStatus = completed ? 'completed' : 'pending';
  if (branch.data.provisioningStatus !== expectedStatus) {
    inconsistencies.push({
      path: `restaurantBranches/${branch.id}`,
      issue:
        `onboardingCompleted=${completed} but provisioningStatus=` +
        `${branch.data.provisioningStatus ?? '(missing)'}`,
    });
  }
  if (
    completed &&
    (!branch.data.onboardingCompletedAt ||
      !branch.data.queueUrl ||
      !Array.isArray(branch.data.capacityTypes) ||
      branch.data.capacityTypes.length === 0)
  ) {
    inconsistencies.push({
      path: `restaurantBranches/${branch.id}`,
      issue: 'completed branch is missing persisted summary fields',
    });
  }
}

for (const admin of admins) {
  const branchId = String(admin.data.restaurantBranchId ?? '').trim();
  const branch = branchById.get(branchId);
  if (!branch) {
    inconsistencies.push({
      path: `admins/${admin.id}`,
      issue: `mapped branch ${branchId || '(missing)'} does not exist`,
    });
    continue;
  }
  if (
    (admin.data.onboardingCompleted === true) !==
    (branch.onboardingCompleted === true)
  ) {
    inconsistencies.push({
      path: `admins/${admin.id}`,
      issue: `admin and restaurantBranches/${branchId} completion diverge`,
    });
  }
}

console.log(
  JSON.stringify(
    {
      projectId,
      branchesChecked: branches.length,
      adminsChecked: admins.length,
      consistent: inconsistencies.length === 0,
      inconsistencies,
    },
    null,
    2,
  ),
);
if (inconsistencies.length > 0) process.exitCode = 2;
