import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';
import { randomUUID } from 'node:crypto';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const pdfPath = process.argv[3] ?? 'web/demo-menu.pdf';
const bucket =
  process.env.EZQ_STORAGE_BUCKET ?? `${projectId}.firebasestorage.app`;
const objectName = process.env.EZQ_MENU_OBJECT_NAME ?? 'menus/ezq-dummy-menu.pdf';
const providedMenuPdfUrl = process.env.EZQ_MENU_PDF_URL;
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;

const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const refreshToken = firebaseToolsConfig.tokens?.refresh_token;
let accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken && !refreshToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
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

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  return { stringValue: String(value) };
}

async function uploadPdf(body) {
  const token = randomUUID();
  const metadata = {
    name: objectName,
    contentType: 'application/pdf',
    cacheControl: 'public, max-age=3600',
    metadata: {
      firebaseStorageDownloadTokens: token,
    },
  };
  const boundary = `ezq-menu-${randomUUID()}`;
  const multipartBody = Buffer.concat([
    Buffer.from(
      `--${boundary}\r\n` +
        'Content-Type: application/json; charset=UTF-8\r\n\r\n' +
        `${JSON.stringify(metadata)}\r\n` +
        `--${boundary}\r\n` +
        'Content-Type: application/pdf\r\n\r\n',
    ),
    body,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);

  await rawRequest({
    hostname: 'storage.googleapis.com',
    method: 'POST',
    path:
      `/upload/storage/v1/b/${encodeURIComponent(bucket)}/o` +
      `?uploadType=multipart&name=${encodeURIComponent(objectName)}`,
    headers: {
      'Content-Type': `multipart/related; boundary=${boundary}`,
    },
    body: multipartBody,
  });

  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/` +
    `${encodeURIComponent(objectName)}?alt=media&token=${token}`
  );
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

async function updateRestaurantBranch(documentName, menuPdfUrl) {
  const updateMask = new URLSearchParams({
    'updateMask.fieldPaths': 'menuPdfUrl',
  });
  updateMask.append('updateMask.fieldPaths', 'menuPreviewImageUrl');
  updateMask.append('updateMask.fieldPaths', 'updatedAt');

  await jsonRequest({
    hostname: 'firestore.googleapis.com',
    method: 'PATCH',
    path: `/v1/${documentName}?${updateMask.toString()}`,
    body: {
      fields: {
        menuPdfUrl: firestoreValue(menuPdfUrl),
        menuPreviewImageUrl: firestoreValue(''),
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    },
  });
}

accessToken = await refreshAccessToken();

let pdf = null;
let menuPdfUrl = providedMenuPdfUrl;
if (!menuPdfUrl) {
  pdf = await readFile(pdfPath);
  menuPdfUrl = await uploadPdf(pdf);
}
const branches = await listRestaurantBranches();

for (const branch of branches) {
  await updateRestaurantBranch(branch.name, menuPdfUrl);
}

if (pdf) {
  console.log(`Uploaded ${pdfPath} (${pdf.length} bytes) to ${objectName}`);
} else {
  console.log(`Using existing menu PDF URL from EZQ_MENU_PDF_URL.`);
}
console.log(`menuPdfUrl=${menuPdfUrl}`);
console.log(`Updated ${branches.length} restaurantBranches documents.`);
