import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const hostingOrigin =
  process.env.EZQ_HOSTING_ORIGIN ?? 'https://ezq-dev-cubiquitous.web.app';
const qrImageBaseUrl =
  process.env.EZQ_QR_IMAGE_BASE_URL ??
  `https://storage.googleapis.com/${projectId}.firebasestorage.app/qr-codes`;
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value).map(([key, nested]) => [key, firestoreValue(nested)]),
      ),
    },
  };
}

function parseFirestoreValue(value) {
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('stringValue' in value) return value.stringValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(parseFirestoreValue);
  }
  if ('mapValue' in value) {
    return parseFirestoreFields(value.mapValue.fields ?? {});
  }
  return undefined;
}

function parseFirestoreFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, parseFirestoreValue(value)]),
  );
}

function toFirestoreDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function firestoreRequest(method, path, body) {
  const payload = body === undefined ? undefined : JSON.stringify(body);

  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname: 'firestore.googleapis.com',
        method,
        path,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          ...(payload === undefined
            ? {}
            : {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }),
        },
      },
      (res) => {
        let response = '';
        res.on('data', (chunk) => {
          response += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(response === '' ? {} : JSON.parse(response));
            return;
          }
          reject(new Error(`${method} ${path}: ${res.statusCode} ${response}`));
        });
      },
    );

    req.on('error', reject);
    if (payload !== undefined) req.write(payload);
    req.end();
  });
}

async function listCollection(collectionPath) {
  const documents = [];
  let pageToken;

  do {
    const query = new URLSearchParams({ pageSize: '300' });
    if (pageToken) query.set('pageToken', pageToken);
    const path =
      `/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}` +
      `?${query.toString()}`;
    const response = await firestoreRequest('GET', path);
    documents.push(...(response.documents ?? []));
    pageToken = response.nextPageToken;
  } while (pageToken);

  return documents;
}

function documentId(documentName) {
  return documentName.split('/').pop();
}

function requireUnique(items, key) {
  const seen = new Map();
  const duplicates = [];

  for (const item of items) {
    const value = item[key];
    if (!value) {
      throw new Error(`${item.path} is missing ${key}`);
    }
    if (seen.has(value)) {
      duplicates.push(`${value}: ${seen.get(value)} and ${item.path}`);
    } else {
      seen.set(value, item.path);
    }
  }

  if (duplicates.length > 0) {
    throw new Error(`Duplicate ${key} values found:\n${duplicates.join('\n')}`);
  }
}

function qrSlugFor(restaurantId, branchId, data) {
  const existing = data.qrSlug;
  if (typeof existing === 'string' && existing.trim().length > 0) {
    return existing.trim();
  }
  return `${restaurantId}-${branchId}`;
}

function qrImageUrlFor(qrSlug, data) {
  const existing = data.qrImageUrl;
  if (typeof existing === 'string' && existing.trim().length > 0) {
    return existing.trim();
  }
  return `${qrImageBaseUrl}/${qrSlug}.png`;
}

async function main() {
  const restaurants = await listCollection('restaurants');
  const branchUpdates = [];

  for (const restaurantDoc of restaurants) {
    const restaurantId = documentId(restaurantDoc.name);
    const restaurantData = parseFirestoreFields(restaurantDoc.fields);
    const branches = await listCollection(`restaurants/${restaurantId}/branches`);

    for (const branchDoc of branches) {
      const branchId = documentId(branchDoc.name);
      const branchData = parseFirestoreFields(branchDoc.fields);
      const restaurantName =
        branchData.restaurantName ??
        restaurantData.brandName ??
        restaurantData.name ??
        restaurantId;
      const qrSlug = qrSlugFor(restaurantId, branchId, branchData);
      const queueUrl = `${hostingOrigin}/customer/${restaurantId}/${branchId}`;
      const qrImageUrl = qrImageUrlFor(qrSlug, branchData);
      const isActive =
        typeof branchData.isActive === 'boolean'
          ? branchData.isActive
          : restaurantData.isActive === true;
      const update = {
        restaurantId,
        restaurantName,
        branchId,
        name: branchData.name ?? branchId,
        qrSlug,
        queueUrl,
        qrImageUrl,
        isActive,
        updatedAt: new Date().toISOString(),
      };

      branchUpdates.push({
        path: `restaurants/${restaurantId}/branches/${branchId}`,
        branchId,
        qrSlug,
        update,
      });
    }
  }

  requireUnique(branchUpdates, 'branchId');
  requireUnique(branchUpdates, 'qrSlug');

  for (const { path, update } of branchUpdates) {
    const mask = Object.keys(update)
      .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
      .join('&');
    await firestoreRequest(
      'PATCH',
      `/v1/projects/${projectId}/databases/(default)/documents/${path}?${mask}`,
      toFirestoreDocument(update),
    );
    console.log(`Standardized ${path}`);
  }

  console.log(
    `Standardized ${branchUpdates.length} branch documents in ${projectId}.`,
  );
}

await main();
