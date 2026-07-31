import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { request } from 'node:https';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const dryRun = process.argv.includes('--dry-run');
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;

const defaultLogo = 'assets/restaurant_logos/default.png';
const logoAssetsByBranch = new Map([
  ['bhagini-horamavu-signal', defaultLogo],
  ['biryani-bay-domlur-edge', defaultLogo],
  ['codex-rule-sync-cafe-00wh77-main', defaultLogo],
  ['cubbon-curry-indiranagar', defaultLogo],
  ['dosa-lab-indiranagar', defaultLogo],
  ['grill-garden-old-airport-road', defaultLogo],
  ['mahanagaram-kalyan-nagar', defaultLogo],
  ['momo-mill-indiranagar-metro', defaultLogo],
  [
    'noodle-yard-indiranagar',
    'assets/restaurant_logos/noodle_yard_logo.png',
  ],
  ['pasta-pepper-hal-2nd-stage', defaultLogo],
  [
    'salad-studio-12th-main',
    'assets/restaurant_logos/salad_studio_logo.png',
  ],
  ['taco-tawa-indiranagar', defaultLogo],
  ['tamarind-banaswadi', defaultLogo],
  ['the-filter-coffee-kalyan-nagar', defaultLogo],
  ['the-indian-eatery-kalyan-nagar', defaultLogo],
  ['the-spice-house-indiranagar', defaultLogo],
]);

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
    const payload = Buffer.from(body ?? '');
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
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
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

function documentPath(branchId) {
  return (
    `/v1/projects/${projectId}/databases/(default)/documents/` +
    `restaurantBranches/${encodeURIComponent(branchId)}`
  );
}

async function readBranch(branchId) {
  return jsonRequest({
    hostname: 'firestore.googleapis.com',
    path: documentPath(branchId),
  });
}

async function updateBranch(branchId, logoAsset) {
  const query = new URLSearchParams({
    'updateMask.fieldPaths': 'logoAsset',
  });
  query.append('updateMask.fieldPaths', 'logoUpdatedAt');
  return jsonRequest({
    hostname: 'firestore.googleapis.com',
    method: 'PATCH',
    path: `${documentPath(branchId)}?${query.toString()}`,
    body: {
      fields: {
        logoAsset: {stringValue: logoAsset},
        logoUpdatedAt: {timestampValue: new Date().toISOString()},
      },
    },
  });
}

accessToken = await refreshAccessToken();

const branches = [];
for (const [branchId, logoAsset] of logoAssetsByBranch) {
  const document = await readBranch(branchId);
  const currentLogoAsset = document.fields?.logoAsset?.stringValue ?? null;
  branches.push({branchId, currentLogoAsset, logoAsset});
}

console.table(branches);

if (dryRun) {
  console.log(`Dry run complete. ${branches.length} branches would be updated.`);
  process.exit(0);
}

for (const branch of branches) {
  await updateBranch(branch.branchId, branch.logoAsset);
}

console.log(`Updated ${branches.length} restaurantBranches documents.`);
