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

function toRawFirestoreDocument(fields) {
  return { fields };
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

function duplicateValues(items, key) {
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

  return duplicates;
}

function requireUnique(items, key) {
  const duplicates = duplicateValues(items, key);
  if (duplicates.length > 0) {
    throw new Error(`Duplicate ${key} values found:\n${duplicates.join('\n')}`);
  }
}

function slugify(value) {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function branchSlugFor(restaurantId, pathBranchId) {
  const legacyPrefix = `${restaurantId}-`;
  if (pathBranchId.startsWith(legacyPrefix)) {
    return slugify(pathBranchId.slice(legacyPrefix.length));
  }
  return slugify(pathBranchId);
}

function qrSlugFor(restaurantId, branchSlug, data) {
  const existing = data.qrSlug;
  if (typeof existing === 'string' && existing.trim().length > 0) {
    return existing.trim();
  }
  return `${restaurantId}-${branchSlug}`;
}

function qrImageUrlFor(qrSlug, data) {
  const existing = data.qrImageUrl;
  if (typeof existing === 'string' && existing.trim().length > 0) {
    return existing.trim();
  }
  return `${qrImageBaseUrl}/${qrSlug}.png`;
}

async function listSubcollectionIds(documentPath) {
  const response = await firestoreRequest(
    'POST',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}:listCollectionIds`,
    { pageSize: 100 },
  );
  return response.collectionIds ?? [];
}

async function patchRawDocument(documentPath, fields) {
  const mask = Object.keys(fields)
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}?${mask}`,
    toRawFirestoreDocument(fields),
  );
}

async function copySubcollections(sourceDocumentPath, targetDocumentPath) {
  const subcollectionIds = await listSubcollectionIds(sourceDocumentPath);

  for (const subcollectionId of subcollectionIds) {
    const sourceCollectionPath = `${sourceDocumentPath}/${subcollectionId}`;
    const targetCollectionPath = `${targetDocumentPath}/${subcollectionId}`;
    const documents = await listCollection(sourceCollectionPath);

    for (const document of documents) {
      const childId = documentId(document.name);
      const sourceChildPath = `${sourceCollectionPath}/${childId}`;
      const targetChildPath = `${targetCollectionPath}/${childId}`;
      await patchRawDocument(targetChildPath, document.fields ?? {});
      await copySubcollections(sourceChildPath, targetChildPath);
      await firestoreRequest(
        'DELETE',
        `/v1/projects/${projectId}/databases/(default)/documents/${sourceChildPath}`,
      );
    }
  }
}

async function main() {
  const restaurants = await listCollection('restaurants');
  const branchRecords = [];

  for (const restaurantDoc of restaurants) {
    const restaurantId = documentId(restaurantDoc.name);
    const restaurantData = parseFirestoreFields(restaurantDoc.fields);
    const branches = await listCollection(`restaurants/${restaurantId}/branches`);

    for (const branchDoc of branches) {
      const pathBranchId = documentId(branchDoc.name);
      const branchData = parseFirestoreFields(branchDoc.fields);
      branchRecords.push({
        path: `restaurants/${restaurantId}/branches/${pathBranchId}`,
        restaurantId,
        restaurantData,
        pathBranchId,
        branchData,
      });
    }
  }

  const branchUpdates = [];

  for (const record of branchRecords) {
    const {
      path,
      restaurantId,
      restaurantData,
      pathBranchId,
      branchData,
    } = record;
      const branchSlug = branchSlugFor(restaurantId, pathBranchId);
      const restaurantName =
        branchData.restaurantName ??
        restaurantData.brandName ??
        restaurantData.name ??
        restaurantId;
      const qrSlug = qrSlugFor(restaurantId, branchSlug, branchData);
      const queueUrl = `${hostingOrigin}/customer/${restaurantId}/${branchSlug}`;
      const qrImageUrl = qrImageUrlFor(qrSlug, branchData);
      const isActive =
        typeof branchData.isActive === 'boolean'
          ? branchData.isActive
          : restaurantData.isActive === true;
      const update = {
        restaurantId,
        restaurantName,
        name: branchData.name ?? branchSlug,
        qrSlug,
        queueUrl,
        qrImageUrl,
        isActive,
        updatedAt: new Date().toISOString(),
      };
      const targetPath = `restaurants/${restaurantId}/branches/${branchSlug}`;
      const mergedUpdate = { ...branchData, ...update };
      delete mergedUpdate.branchId;
      delete mergedUpdate.branchSlug;

      branchUpdates.push({
        path,
        targetPath,
        branchSlug,
        qrSlug,
        update: mergedUpdate,
        shouldMoveDocument: path !== targetPath,
      });
  }

  requireUnique(branchUpdates, 'targetPath');
  requireUnique(branchUpdates, 'qrSlug');

  for (const { path, targetPath, update, shouldMoveDocument } of branchUpdates) {
    const mask = [...new Set([...Object.keys(update), 'branchId', 'branchSlug'])]
      .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
      .join('&');
    await firestoreRequest(
      'PATCH',
      `/v1/projects/${projectId}/databases/(default)/documents/${targetPath}?${mask}`,
      toFirestoreDocument(update),
    );
    if (shouldMoveDocument) {
      await copySubcollections(path, targetPath);
      await firestoreRequest(
        'DELETE',
        `/v1/projects/${projectId}/databases/(default)/documents/${path}`,
      );
      console.log(`Moved ${path} -> ${targetPath}`);
    } else {
      console.log(`Standardized ${path}`);
    }
  }

  console.log(
    `Standardized ${branchUpdates.length} branch documents in ${projectId}.`,
  );
}

await main();
