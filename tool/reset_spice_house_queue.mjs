import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const restaurantId = 'the-spice-house';
const branchId = 'indiranagar';
const basePath = `restaurants/${restaurantId}/branches/${branchId}`;
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  return { stringValue: String(value) };
}

function firestoreDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function firestoreRequest(method, path, data) {
  const body = data === undefined ? null : JSON.stringify(firestoreDocument(data));

  return new Promise((resolve, reject) => {
    const req = request(
      {
        method,
        hostname: 'firestore.googleapis.com',
        path,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          ...(body
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body),
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
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(responseBody ? JSON.parse(responseBody) : null);
            return;
          }
          reject(
            new Error(
              `${method} ${path} failed: ${res.statusCode} ${responseBody}`,
            ),
          );
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function listCollection(collectionPath) {
  const docs = [];
  let pageToken = '';
  do {
    const query = pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : '';
    const response = await firestoreRequest(
      'GET',
      `/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}${query}`,
    );
    docs.push(...(response.documents ?? []));
    pageToken = response.nextPageToken ?? '';
  } while (pageToken);
  return docs;
}

async function deleteDocument(documentName) {
  const documentPath = documentName.split('/documents/')[1];
  await firestoreRequest(
    'DELETE',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`,
  );
}

async function patchDocument(documentPath, data) {
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`,
    data,
  );
}

const queueDocs = await listCollection(`${basePath}/queueEntries`);
for (const doc of queueDocs) {
  await deleteDocument(doc.name);
  console.log(`Deleted ${doc.name.split('/documents/')[1]}`);
}

const tableDocs = await listCollection(`${basePath}/tables`);
for (const doc of tableDocs) {
  const tablePath = doc.name.split('/documents/')[1];
  const fields = doc.fields ?? {};
  await patchDocument(tablePath, {
    tableNumber: fields.tableNumber?.stringValue ?? '',
    capacity: Number(fields.capacity?.integerValue ?? 2),
    tableType: fields.tableType?.stringValue ?? '2-top',
    section: fields.section?.stringValue ?? 'main',
    status: 'available',
    currentQueueEntryId: null,
    currentTokenCode: null,
    currentPartySize: null,
    currentCycleStartAt: null,
    currentCycleSource: null,
    reservedAt: null,
    occupiedAt: null,
    cleaningStartedAt: null,
    sortOrder: Number(fields.sortOrder?.integerValue ?? 0),
  });
  console.log(`Reset ${tablePath}`);
}

console.log(
  `Cleared ${queueDocs.length} queue entries and reset ${tableDocs.length} tables to available.`,
);
