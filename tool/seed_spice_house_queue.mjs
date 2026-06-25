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

const businessDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Kolkata',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(new Date());

const now = Date.now();
const minutesAgo = (minutes) => new Date(now - minutes * 60 * 1000).toISOString();

const names = [
  'Aarav Mehta',
  'Diya Rao',
  'Kabir Shah',
  'Meera Iyer',
  'Rohan Kapoor',
  'Sara D Souza',
  'Devika Pillai',
  'Manav Bhat',
  'Ishaan Verma',
  'Tara Menon',
  'Vivaan Nair',
  'Anika Sen',
  'Nisha Rao',
  'Arjun Nair',
  'Priya Menon',
  'Rahul Bose',
  'Kavya Reddy',
  'Aditya Krishnan',
  'Saanvi Jain',
  'Neel Kumar',
  'Aisha Thomas',
  'Reyansh Gupta',
  'Mira Das',
  'Ritika Sinha',
  'Karan Malhotra',
  'Tanvi Kulkarni',
  'Zara Khan',
  'Om Prakash',
  'Leela George',
  'Nikhil Bhat',
];

const partySizes = [
  2, 4, 3, 6, 1, 5, 2, 8, 4, 3,
  6, 2, 7, 4, 1, 5, 10, 3, 2, 6,
  4, 8, 12, 2, 5, 3, 6, 4, 1, 7,
];

const preferencePool = [
  'window_seat',
  'patio',
  'quiet_corner',
  'high_chair',
  'wheelchair_access',
  'near_outlet',
  'birthday_setup',
  'vegan_options',
  'no_onion_garlic',
  'split_bill',
  'quick_service',
  'family_section',
];

const preferenceLabels = {
  window_seat: 'Window seat',
  patio: 'Patio',
  quiet_corner: 'Quiet corner',
  high_chair: 'High chair',
  wheelchair_access: 'Wheelchair access',
  near_outlet: 'Near charging outlet',
  birthday_setup: 'Birthday setup',
  vegan_options: 'Vegan options',
  no_onion_garlic: 'No onion/garlic',
  split_bill: 'Split bill',
  quick_service: 'Quick service',
  family_section: 'Family section',
};

function partySizeBand(partySize) {
  if (partySize <= 2) return '1-2';
  if (partySize <= 4) return '3-4';
  if (partySize <= 6) return '5-6';
  return '7+';
}

function preferencesFor(index) {
  const first = preferencePool[index % preferencePool.length];
  const second = preferencePool[(index * 2 + 3) % preferencePool.length];
  const third = preferencePool[(index * 3 + 7) % preferencePool.length];
  return [...new Set([first, second, third])].slice(0, index % 4 === 0 ? 3 : 2);
}

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
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
    currentCycleStartAt: null,
    currentCycleSource: null,
    reservedAt: null,
    occupiedAt: null,
    cleaningStartedAt: null,
    sortOrder: Number(fields.sortOrder?.integerValue ?? 0),
  });
}

for (let index = 0; index < 30; index += 1) {
  const tokenNumber = index + 1;
  const partySize = partySizes[index];
  const preferences = preferencesFor(index);
  const waitedMinutes = 90 - index * 3;
  const estimatedWaitMinutes = 5 + index * 5;
  const tokenCode = `Q${String(tokenNumber).padStart(2, '0')}`;
  await patchDocument(`${basePath}/queueEntries/q${String(tokenNumber).padStart(2, '0')}`, {
    tokenNumber,
    tokenCode,
    businessDate,
    customerName: names[index],
    phone: `+91984555${String(2000 + index).padStart(4, '0')}`,
    partySize,
    partySizeBand: partySizeBand(partySize),
    notes: `Preferences: ${preferences.map((item) => preferenceLabels[item]).join(', ')}`,
    preferences,
    customerId: null,
    sessionType: index % 2 === 0 ? 'ios_app' : 'android_app',
    appSource: index % 2 === 0 ? 'ios' : 'android',
    status: 'waiting',
    assignedTableId: null,
    assignedTableNumber: null,
    estimatedWaitMinutes,
    queuePosition: tokenNumber,
    extensionUsed: false,
    joinedAt: minutesAgo(waitedMinutes),
    updatedAt: minutesAgo(Math.max(1, waitedMinutes - 1)),
  });
  console.log(
    `Seeded ${tokenCode}: position ${tokenNumber}, waited ${waitedMinutes} min, ETA ${estimatedWaitMinutes} min`,
  );
}

await patchDocument(`${basePath}/dailyCounters/${businessDate}`, {
  businessDate,
  lastTokenNumber: 30,
  totalJoined: 30,
  totalSeated: 0,
  totalSkipped: 0,
  totalCancelled: 0,
  totalNoShow: 0,
  peakQueueDepth: 30,
  updatedAt: new Date(now).toISOString(),
});

console.log(
  `Seeded 30 waiting parties in Q-number order and reset ${tableDocs.length} tables to available in ${projectId}.`,
);
