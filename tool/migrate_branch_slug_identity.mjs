import { readFile, writeFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const hostingOrigin =
  process.env.EZQ_HOSTING_ORIGIN ?? 'https://ezq-dev-cubiquitous.web.app';
const storageBucket =
  process.env.EZQ_STORAGE_BUCKET ??
  `${projectId}.firebasestorage.app`;
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;

const migrations = [
  {
    restaurantId: 'taco-tawa',
    sourceBranchId: 'taco-tawa-indiranagar',
    targetBranchSlug: 'indiranagar',
  },
  {
    restaurantId: 'dosa-lab',
    sourceBranchId: 'dosa-lab-indiranagar',
    targetBranchSlug: 'indiranagar',
  },
  {
    restaurantId: 'noodle-yard',
    sourceBranchId: 'noodle-yard-indiranagar',
    targetBranchSlug: 'indiranagar',
  },
  {
    restaurantId: 'cubbon-curry',
    sourceBranchId: 'cubbon-curry-indiranagar',
    targetBranchSlug: 'indiranagar',
  },
];

let firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
let accessToken = firebaseToolsConfig.tokens?.access_token;

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

function documentId(documentName) {
  return documentName.split('/').pop();
}

function branchDocumentPath(restaurantId, branchSlug) {
  return `restaurants/${restaurantId}/branches/${branchSlug}`;
}

function qrSlugFor(restaurantId, branchSlug, sourceData, targetData) {
  const existing = sourceData.qrSlug ?? targetData.qrSlug;
  if (typeof existing === 'string' && existing.trim().length > 0) {
    return existing.trim();
  }
  return `${restaurantId}-${branchSlug}`;
}

function qrImageUrlFor(qrSlug, sourceData, targetData) {
  const existing = sourceData.qrImageUrl ?? targetData.qrImageUrl;
  if (typeof existing === 'string' && existing.trim().length > 0) {
    return existing.trim();
  }
  return `https://storage.googleapis.com/${storageBucket}/qr-codes/${qrSlug}.png`;
}

async function refreshAccessToken() {
  const refreshToken = firebaseToolsConfig.tokens?.refresh_token;
  if (!refreshToken) {
    if (accessToken) return accessToken;
    throw new Error('No Firebase CLI token found. Run firebase login first.');
  }

  const payload = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  try {
    const response = await rawRequest({
      hostname: 'oauth2.googleapis.com',
      method: 'POST',
      path: '/token',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(payload),
      },
      body: payload,
    });
    const tokenResponse = JSON.parse(response);
    accessToken = tokenResponse.access_token;
    firebaseToolsConfig = {
      ...firebaseToolsConfig,
      tokens: {
        ...firebaseToolsConfig.tokens,
        access_token: accessToken,
        expires_at: Date.now() + tokenResponse.expires_in * 1000,
      },
    };
    await writeFile(configPath, `${JSON.stringify(firebaseToolsConfig, null, 2)}\n`);
    return accessToken;
  } catch (error) {
    if (accessToken) {
      console.warn(`Could not refresh Firebase token; trying cached access token. ${error.message}`);
      return accessToken;
    }
    throw error;
  }
}

function rawRequest({ hostname, method, path, headers = {}, body }) {
  const payload =
    body === undefined || Buffer.isBuffer(body) ? body : Buffer.from(String(body));

  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname,
        method,
        path,
        headers: {
          ...headers,
          ...(payload === undefined
            ? {}
            : { 'Content-Length': Buffer.byteLength(payload) }),
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
          reject(new Error(`${method} https://${hostname}${path}: ${res.statusCode} ${response}`));
        });
      },
    );

    req.on('error', reject);
    if (payload !== undefined) req.write(payload);
    req.end();
  });
}

async function firestoreRequest(method, path, body) {
  if (!accessToken) await refreshAccessToken();
  const payload = body === undefined ? undefined : JSON.stringify(body);
  const response = await rawRequest({
    hostname: 'firestore.googleapis.com',
    method,
    path,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(payload === undefined
        ? {}
        : { 'Content-Type': 'application/json' }),
    },
    body: payload,
  });
  return response === '' ? {} : JSON.parse(response);
}

async function getDocument(documentPath) {
  try {
    return await firestoreRequest(
      'GET',
      `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`,
    );
  } catch (error) {
    if (String(error.message).includes(' 404 ')) return null;
    throw error;
  }
}

async function listCollection(collectionPath) {
  const documents = [];
  let pageToken;

  do {
    const query = new URLSearchParams({ pageSize: '300' });
    if (pageToken) query.set('pageToken', pageToken);
    const response = await firestoreRequest(
      'GET',
      `/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}?${query}`,
    );
    documents.push(...(response.documents ?? []));
    pageToken = response.nextPageToken;
  } while (pageToken);

  return documents;
}

async function listSubcollectionIds(documentPath) {
  const response = await firestoreRequest(
    'POST',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}:listCollectionIds`,
    { pageSize: 100 },
  );
  return response.collectionIds ?? [];
}

async function patchRawDocument(documentPath, fields, deleteFields = []) {
  const mask = [...new Set([...Object.keys(fields), ...deleteFields])]
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}?${mask}`,
    toRawFirestoreDocument(fields),
  );
}

async function patchDocument(documentPath, data, deleteFields = []) {
  const mask = [...new Set([...Object.keys(data), ...deleteFields])]
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}?${mask}`,
    toFirestoreDocument(data),
  );
}

async function deleteDocument(documentPath) {
  await firestoreRequest(
    'DELETE',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`,
  );
}

async function copySubcollections(sourceDocumentPath, targetDocumentPath) {
  const subcollectionIds = await listSubcollectionIds(sourceDocumentPath);
  let copied = 0;

  for (const subcollectionId of subcollectionIds) {
    const sourceCollectionPath = `${sourceDocumentPath}/${subcollectionId}`;
    const targetCollectionPath = `${targetDocumentPath}/${subcollectionId}`;
    const documents = await listCollection(sourceCollectionPath);

    for (const document of documents) {
      const childId = documentId(document.name);
      const sourceChildPath = `${sourceCollectionPath}/${childId}`;
      const targetChildPath = `${targetCollectionPath}/${childId}`;
      await patchRawDocument(targetChildPath, document.fields ?? {});
      copied += 1;
      copied += await copySubcollections(sourceChildPath, targetChildPath);
    }
  }

  return copied;
}

async function deleteSubcollections(documentPath) {
  const subcollectionIds = await listSubcollectionIds(documentPath);
  let deleted = 0;

  for (const subcollectionId of subcollectionIds) {
    const collectionPath = `${documentPath}/${subcollectionId}`;
    const documents = await listCollection(collectionPath);

    for (const document of documents) {
      const childId = documentId(document.name);
      const childPath = `${collectionPath}/${childId}`;
      deleted += await deleteSubcollections(childPath);
      await deleteDocument(childPath);
      deleted += 1;
    }
  }

  return deleted;
}

function normalizedBranchFields({
  restaurantId,
  targetBranchSlug,
  sourceDocument,
  targetDocument,
}) {
  const sourceFields = sourceDocument?.fields ?? {};
  const targetFields = targetDocument?.fields ?? {};
  const sourceData = parseFirestoreFields(sourceFields);
  const targetData = parseFirestoreFields(targetFields);
  const qrSlug = qrSlugFor(restaurantId, targetBranchSlug, sourceData, targetData);
  const queueUrl = `${hostingOrigin}/customer/${restaurantId}/${targetBranchSlug}`;
  const restaurantName =
    sourceData.restaurantName ??
    targetData.restaurantName ??
    restaurantId;
  const branchName =
    sourceData.name ??
    targetData.name ??
    targetBranchSlug;

  return {
    ...targetFields,
    ...sourceFields,
    restaurantId: firestoreValue(restaurantId),
    restaurantName: firestoreValue(restaurantName),
    name: firestoreValue(branchName),
    queueUrl: firestoreValue(queueUrl),
    qrSlug: firestoreValue(qrSlug),
    qrImageUrl: firestoreValue(qrImageUrlFor(qrSlug, sourceData, targetData)),
    isActive: firestoreValue(
      typeof sourceData.isActive === 'boolean'
        ? sourceData.isActive
        : targetData.isActive ?? true,
    ),
    updatedAt: firestoreValue(new Date().toISOString()),
  };
}

async function migrateBranch({
  restaurantId,
  sourceBranchId,
  targetBranchSlug,
}) {
  const sourcePath = branchDocumentPath(restaurantId, sourceBranchId);
  const targetPath = branchDocumentPath(restaurantId, targetBranchSlug);
  const [sourceDocument, targetDocument] = await Promise.all([
    getDocument(sourcePath),
    getDocument(targetPath),
  ]);

  if (!sourceDocument && targetDocument) {
    const targetFields = { ...(targetDocument.fields ?? {}) };
    delete targetFields.branchId;
    delete targetFields.branchSlug;
    const targetData = parseFirestoreFields(targetFields);
    await patchDocument(
      targetPath,
      {
        restaurantId,
        restaurantName: targetData.restaurantName ?? restaurantId,
        name: targetData.name ?? targetBranchSlug,
        queueUrl: `${hostingOrigin}/customer/${restaurantId}/${targetBranchSlug}`,
        qrSlug: targetData.qrSlug ?? `${restaurantId}-${targetBranchSlug}`,
        qrImageUrl:
          targetData.qrImageUrl ??
          `https://storage.googleapis.com/${storageBucket}/qr-codes/${targetData.qrSlug ?? `${restaurantId}-${targetBranchSlug}`}.png`,
        isActive: typeof targetData.isActive === 'boolean' ? targetData.isActive : true,
        updatedAt: new Date().toISOString(),
      },
      ['branchId', 'branchSlug'],
    );
    console.log(`Already migrated ${targetPath}; normalized fields.`);
    return;
  }

  if (!sourceDocument) {
    throw new Error(`Missing source document ${sourcePath}`);
  }

  const normalizedFields = normalizedBranchFields({
    restaurantId,
    targetBranchSlug,
    sourceDocument,
    targetDocument,
  });
  delete normalizedFields.branchId;
  delete normalizedFields.branchSlug;

  await patchRawDocument(targetPath, normalizedFields, ['branchId', 'branchSlug']);
  const copiedDocuments = await copySubcollections(sourcePath, targetPath);
  const verifiedTarget = await getDocument(targetPath);
  if (!verifiedTarget) {
    throw new Error(`Target document ${targetPath} was not readable after copy.`);
  }

  const deletedDocuments = await deleteSubcollections(sourcePath);
  await deleteDocument(sourcePath);
  console.log(
    `Migrated ${sourcePath} -> ${targetPath}; copied ${copiedDocuments} nested documents, deleted ${deletedDocuments} nested source documents.`,
  );
}

await refreshAccessToken();
for (const migration of migrations) {
  await migrateBranch(migration);
}

console.log(`Normalized ${migrations.length} branch identities in ${projectId}.`);
