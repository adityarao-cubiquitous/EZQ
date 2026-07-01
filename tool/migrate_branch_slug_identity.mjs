import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const hostingOrigin =
  process.argv[3] ?? 'https://ezq-dev-cubiquitous.web.app';
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

const migrations = [
  {
    restaurantId: 'taco-tawa',
    fromBranchDocId: 'taco-tawa-indiranagar',
    branchSlug: 'indiranagar',
  },
  {
    restaurantId: 'dosa-lab',
    fromBranchDocId: 'dosa-lab-indiranagar',
    branchSlug: 'indiranagar',
  },
  {
    restaurantId: 'cubbon-curry',
    fromBranchDocId: 'cubbon-curry-indiranagar',
    branchSlug: 'indiranagar',
  },
];

function documentPath(path) {
  return `/v1/projects/${projectId}/databases/(default)/documents/${path}`;
}

function firestoreRequest(method, path, body) {
  const payload = body == null ? null : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname: 'firestore.googleapis.com',
        path,
        method,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
        },
      },
      (res) => {
        let responseBody = '';
        res.on('data', (chunk) => {
          responseBody += chunk;
        });
        res.on('end', () => {
          const parsed = responseBody ? JSON.parse(responseBody) : {};
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
            return;
          }
          reject(
            new Error(
              `${method} ${path} failed with ${res.statusCode}: ${responseBody}`,
            ),
          );
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function fieldValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  return { stringValue: String(value) };
}

function parseValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return value.timestampValue;
  return undefined;
}

function parseFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields)
      .map(([key, value]) => [key, parseValue(value)])
      .filter(([, value]) => value !== undefined),
  );
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => [key, fieldValue(value)]),
  );
}

async function getDocument(path) {
  try {
    return await firestoreRequest('GET', documentPath(path));
  } catch (error) {
    if (String(error.message).includes('failed with 404')) return null;
    throw error;
  }
}

async function patchDocument(path, data) {
  const mask = Object.keys(data)
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  await firestoreRequest('PATCH', `${documentPath(path)}?${mask}`, {
    fields: encodeFields(data),
  });
}

async function deleteDocument(path) {
  await firestoreRequest('DELETE', documentPath(path));
}

for (const migration of migrations) {
  const { restaurantId, fromBranchDocId, branchSlug } = migration;
  const sourcePath = `restaurants/${restaurantId}/branches/${fromBranchDocId}`;
  const targetPath = `restaurants/${restaurantId}/branches/${branchSlug}`;
  const sourceDoc = await getDocument(sourcePath);
  const targetDoc = await getDocument(targetPath);
  const sourceData = sourceDoc ? parseFields(sourceDoc.fields) : {};
  const targetData = targetDoc ? parseFields(targetDoc.fields) : {};
  const merged = {
    ...sourceData,
    ...targetData,
    restaurantId,
    branchSlug,
    name: targetData.name ?? sourceData.name ?? 'Indiranagar',
    queueUrl: `${hostingOrigin}/customer/${restaurantId}/${branchSlug}`,
    qrSlug: sourceData.qrSlug ?? targetData.qrSlug ?? fromBranchDocId,
    qrImageUrl:
      sourceData.qrImageUrl ??
      targetData.qrImageUrl ??
      `https://storage.googleapis.com/${projectId}.firebasestorage.app/qr-codes/${sourceData.qrSlug ?? fromBranchDocId}.png`,
    isActive:
      targetData.isActive ??
      sourceData.isActive ??
      true,
    updatedAt: new Date().toISOString(),
  };
  delete merged.branchId;

  await patchDocument(targetPath, merged);

  if (sourceDoc && sourcePath !== targetPath) {
    await deleteDocument(sourcePath);
  }

  console.log(`Migrated ${sourcePath} -> ${targetPath}`);
}
