import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { request } from 'node:https';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const hostingOrigin =
  process.env.EZQ_HOSTING_ORIGIN ?? 'https://ezq-dev-cubiquitous.web.app';
const puzzleCount = Number(process.env.EZQ_WAIT_PUZZLE_COUNT ?? 24);
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;

const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const refreshToken = firebaseToolsConfig.tokens?.refresh_token;
let accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken && !refreshToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

async function rawRequest({
  hostname,
  method = 'GET',
  path,
  headers = {},
  body,
  skipAuth = false,
}) {
  return new Promise((resolve, reject) => {
    const payload = Buffer.isBuffer(body) ? body : Buffer.from(body ?? '');
    const req = request(
      {
        hostname,
        method,
        path,
        headers: {
          ...headers,
          ...(skipAuth ? {} : { Authorization: `Bearer ${accessToken}` }),
          ...(body == null ? {} : { 'Content-Length': payload.length }),
        },
      },
      (res) => {
        let response = '';
        res.on('data', (chunk) => {
          response += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(response);
            return;
          }
          reject(
            new Error(
              `${method} ${hostname}${path} failed (${res.statusCode}): ${response}`,
            ),
          );
        });
      },
    );
    req.on('error', reject);
    if (body != null) req.write(payload);
    req.end();
  });
}

async function refreshAccessToken() {
  if (!refreshToken) return accessToken;
  const body = new URLSearchParams({
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const response = await rawRequest({
    hostname: 'oauth2.googleapis.com',
    method: 'POST',
    path: '/token',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
    body,
    skipAuth: true,
  });
  return JSON.parse(response).access_token;
}

async function jsonRequest(options) {
  const response = await rawRequest({
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
    body:
      options.body == null || typeof options.body === 'string'
        ? options.body
        : JSON.stringify(options.body),
  });
  return response ? JSON.parse(response) : null;
}

function stringValue(value) {
  return { stringValue: value };
}

function arrayValue(values) {
  return { arrayValue: { values: values.map(stringValue) } };
}

async function listRestaurantBranches() {
  const documents = [];
  let pageToken = '';
  do {
    const query = new URLSearchParams({ pageSize: '100' });
    if (pageToken) query.set('pageToken', pageToken);
    const response = await jsonRequest({
      hostname: 'firestore.googleapis.com',
      path:
        `/v1/projects/${projectId}/databases/(default)/documents/` +
        `restaurantBranches?${query.toString()}`,
    });
    documents.push(...(response.documents ?? []));
    pageToken = response.nextPageToken ?? '';
  } while (pageToken);
  return documents;
}

async function updateRestaurantBranch(documentName, urls) {
  const updateMask = new URLSearchParams({
    'updateMask.fieldPaths': 'hiddenObjectPuzzleImageUrls',
  });
  updateMask.append('updateMask.fieldPaths', 'hiddenObjectPuzzleImageUrl');
  updateMask.append('updateMask.fieldPaths', 'waitPuzzleImageUrl');
  updateMask.append('updateMask.fieldPaths', 'updatedAt');

  await jsonRequest({
    hostname: 'firestore.googleapis.com',
    method: 'PATCH',
    path: `/v1/${documentName}?${updateMask.toString()}`,
    body: {
      fields: {
        hiddenObjectPuzzleImageUrls: arrayValue(urls),
        hiddenObjectPuzzleImageUrl: stringValue(urls[0]),
        waitPuzzleImageUrl: stringValue(urls[0]),
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    },
  });
}

accessToken = await refreshAccessToken();

const urls = Array.from({ length: puzzleCount }, (_, index) => {
  const number = String(index + 1).padStart(2, '0');
  return `${hostingOrigin}/wait-puzzles/puzzle-${number}.jpg`;
});

const branches = await listRestaurantBranches();
for (const branch of branches) {
  await updateRestaurantBranch(branch.name, urls);
}

console.log(`Updated ${branches.length} restaurantBranches documents.`);
console.log(`Puzzle URLs per branch: ${urls.length}`);
console.log(`First URL: ${urls[0]}`);
