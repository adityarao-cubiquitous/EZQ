import { readFile, writeFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const restaurantBranchId = 'the-spice-house-indiranagar';
const basePath = `restaurantBranches/${restaurantBranchId}`;
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
let accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

async function refreshFirebaseCliTokenIfNeeded() {
  const expiresAt = firebaseToolsConfig.tokens?.expires_at ?? 0;
  if (expiresAt > Date.now() + 60_000) return;

  const refreshToken = firebaseToolsConfig.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('No Firebase CLI refresh token found. Run firebase login again.');
  }

  const body = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const refreshed = await new Promise((resolve, reject) => {
    const req = request(
      {
        method: 'POST',
        hostname: 'oauth2.googleapis.com',
        path: '/token',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body),
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
          reject(new Error(`Token refresh failed: ${res.statusCode} ${responseBody}`));
        });
      },
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });

  accessToken = refreshed.access_token;
  firebaseToolsConfig.tokens = {
    ...firebaseToolsConfig.tokens,
    access_token: refreshed.access_token,
    expires_in: refreshed.expires_in,
    expires_at: Date.now() + refreshed.expires_in * 1000,
    token_type: refreshed.token_type ?? firebaseToolsConfig.tokens.token_type,
    id_token: refreshed.id_token ?? firebaseToolsConfig.tokens.id_token,
  };
  await writeFile(configPath, `${JSON.stringify(firebaseToolsConfig, null, 2)}\n`);
}

await refreshFirebaseCliTokenIfNeeded();

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
  'Pooja Bhandari',
  'Yash Agarwal',
  'Sonia Mathew',
  'Farhan Ali',
  'Ira Banerjee',
  'Gaurav Mishra',
  'Lavanya Murthy',
  'Sameer Joshi',
  'Rhea Fernandes',
  'Harsh Vardhan',
  'Maya Subramaniam',
  'Kunal Desai',
  'Anaya Kapoor',
  'Vikram Sethi',
  'Mitali Chawla',
];

const partySizes = [
  2, 4, 3, 6, 1, 5, 2, 8, 4, 3,
  6, 2, 7, 4, 1, 5, 10, 3, 2, 6,
  4, 8, 12, 2, 5, 3, 6, 4, 1, 7,
  2, 5, 3, 4, 6, 2, 8, 1, 4, 5,
  3, 7, 2, 6, 4,
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

const spiceHouseTables = [
  { id: 't1', tableNumber: 'T1', capacity: 2, section: 'main' },
  { id: 't2', tableNumber: 'T2', capacity: 4, section: 'main' },
  { id: 't3', tableNumber: 'T3', capacity: 4, section: 'patio' },
  { id: 't4', tableNumber: 'T4', capacity: 6, section: 'family' },
  { id: 't5', tableNumber: 'T5', capacity: 2, section: 'bar' },
  { id: 't6', tableNumber: 'T6', capacity: 2, section: 'window' },
  { id: 't7', tableNumber: 'T7', capacity: 2, section: 'patio' },
  { id: 't8', tableNumber: 'T8', capacity: 4, section: 'main' },
  { id: 't9', tableNumber: 'T9', capacity: 4, section: 'patio' },
  { id: 't10', tableNumber: 'T10', capacity: 4, section: 'main' },
  { id: 't11', tableNumber: 'T11', capacity: 6, section: 'family' },
  { id: 't12', tableNumber: 'T12', capacity: 6, section: 'family' },
  { id: 't13', tableNumber: 'T13', capacity: 8, section: 'private' },
  { id: 't14', tableNumber: 'T14', capacity: 10, section: 'private' },
  { id: 't15', tableNumber: 'T15', capacity: 2, section: 'main' },
  { id: 't16', tableNumber: 'T16', capacity: 2, section: 'main' },
  { id: 't17', tableNumber: 'T17', capacity: 2, section: 'main' },
  { id: 't18', tableNumber: 'T18', capacity: 4, section: 'main' },
  { id: 't19', tableNumber: 'T19', capacity: 4, section: 'main' },
  { id: 't20', tableNumber: 'T20', capacity: 4, section: 'main' },
  { id: 't21', tableNumber: 'T21', capacity: 4, section: 'main' },
  { id: 't22', tableNumber: 'T22', capacity: 6, section: 'family' },
  { id: 't23', tableNumber: 'T23', capacity: 6, section: 'family' },
  { id: 't24', tableNumber: 'T24', capacity: 6, section: 'family' },
  { id: 't25', tableNumber: 'T25', capacity: 8, section: 'private' },
  { id: 't26', tableNumber: 'T26', capacity: 8, section: 'private' },
  { id: 't27', tableNumber: 'T27', capacity: 10, section: 'private' },
  { id: 't28', tableNumber: 'T28', capacity: 10, section: 'private' },
  { id: 't29', tableNumber: 'T29', capacity: 12, section: 'banquet' },
  { id: 't30', tableNumber: 'T30', capacity: 12, section: 'banquet' },
];

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

function seatingPreferenceFor(index, partySize) {
  if (partySize > 6) return 'ANY_AVAILABLE';
  return index % 5 === 0 || index % 7 === 0
    ? 'EMPTY_TABLE_ONLY'
    : 'ANY_AVAILABLE';
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

const existingFloorDocs = await listCollection(`${basePath}/floors`);
for (const doc of existingFloorDocs) {
  await deleteDocument(doc.name);
}

const floorId = 'F1';
const tableSeededAt = new Date(now).toISOString();
const totalSeats = spiceHouseTables.reduce((total, table) => total + table.capacity, 0);
const capacityTypes = [
  ...new Set(spiceHouseTables.map((table) => table.capacity)),
].sort((left, right) => left - right);
await patchDocument(basePath, {
  id: restaurantBranchId,
  slug: restaurantBranchId,
  qrSlug: restaurantBranchId,
  restaurantName: 'The Spice House',
  branchName: 'Indiranagar',
  displayName: 'The Spice House - Indiranagar',
  area: 'Vijaya Bank Layout',
  address: 'Vijaya Bank Layout near IIM Bangalore, Bengaluru',
  city: 'Bengaluru',
  country: 'India',
  geoPoint: { latitude: 12.89868, longitude: 77.61205 },
  subscription: { plan: 'starter', status: 'trial' },
  hiddenObjectPuzzleImageUrl:
    'https://ezq-dev-cubiquitous.web.app/wait-puzzles/puzzle-01.jpg',
  menuPdfUrl: '/demo-menu.pdf',
  menuPreviewImageUrl: '/demo-menu-page-1.png',
  averageTurnoverMinutes: 35,
  floorCount: 1,
  totalTables: spiceHouseTables.length,
  totalSeats,
  capacityTypes,
  onboardingCompleted: true,
  isActive: true,
  provisioningStatus: 'completed',
  qrEnabled: true,
  createdAt: '2026-06-25T10:57:13.435Z',
  updatedAt: tableSeededAt,
});

await patchDocument(`${basePath}/floors/${floorId}`, {
  floorId,
  floorName: 'Main Floor',
  displayOrder: 1,
  tableCount: spiceHouseTables.length,
  seatCount: totalSeats,
  updatedAt: tableSeededAt,
});

for (const [index, table] of spiceHouseTables.entries()) {
  await patchDocument(`${basePath}/tables/${table.id}`, {
    tableNumber: table.tableNumber,
    displayTableName: `${floorId}-${table.tableNumber}`,
    floorId,
    capacity: table.capacity,
    tableType: `${table.capacity}-top`,
    section: table.section,
    status: 'available',
    currentQueueEntryId: null,
    currentTokenCode: null,
    currentPartySize: null,
    currentCycleStartAt: null,
    currentCycleSource: null,
    reservedAt: null,
    occupiedAt: null,
    cleaningStartedAt: null,
    sortOrder: index + 1,
    updatedAt: tableSeededAt,
  });
}

const queueCount = 45;

for (let index = 0; index < queueCount; index += 1) {
  const tokenNumber = index + 1;
  const partySize = partySizes[index];
  const preferences = preferencesFor(index);
  const waitedMinutes = 74 - Math.round(index * 1.5);
  const estimatedWaitMinutes = 5 + index * 2;
  const tokenCode = `Q${String(tokenNumber).padStart(2, '0')}`;
  const seatingPreference = seatingPreferenceFor(index, partySize);
  const etaShared = Math.min(90, 8 + index * 2);
  const etaEmptyTable = Math.min(110, etaShared + 12);
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
    customerPreferences: {
      seatingPreference,
      floorPreference: null,
      accessibilityRequired: preferences.includes('wheelchair_access'),
      acceptedLongerWait: seatingPreference === 'EMPTY_TABLE_ONLY',
      etaShared,
      etaEmptyTable,
      selectedAt: minutesAgo(waitedMinutes),
    },
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

const partialOccupancyScenarios = [
  { capacity: 4, partySize: 2, tokenNumber: 901, name: 'Seated Demo Two' },
  { capacity: 6, partySize: 2, tokenNumber: 902, name: 'Seated Demo Two Plus' },
  { capacity: 8, partySize: 3, tokenNumber: 903, name: 'Seated Demo Three' },
];

const usedTablePaths = new Set();
for (const scenario of partialOccupancyScenarios) {
  const table = spiceHouseTables.find((item) => {
    return item.capacity === scenario.capacity && !usedTablePaths.has(item.id);
  });
  if (!table) continue;

  const tablePath = `${basePath}/tables/${table.id}`;
  const tableId = table.id;
  const tableNumber = table.tableNumber;
  const queueEntryId = `seated-demo-${scenario.tokenNumber}`;
  const tokenCode = `Q${scenario.tokenNumber}`;
  const seatedAt = minutesAgo(18 + (scenario.tokenNumber - 900) * 4);
  usedTablePaths.add(table.id);

  await patchDocument(`${basePath}/queueEntries/${queueEntryId}`, {
    tokenNumber: scenario.tokenNumber,
    tokenCode,
    businessDate,
    customerName: scenario.name,
    phone: `+91984556${scenario.tokenNumber}`,
    partySize: scenario.partySize,
    partySizeBand: partySizeBand(scenario.partySize),
    notes: 'Demo seated party for partial table sharing',
    preferences: ['shared_table_demo'],
    customerPreferences: {
      seatingPreference: 'ANY_AVAILABLE',
      floorPreference: null,
      accessibilityRequired: false,
      acceptedLongerWait: false,
      etaShared: 0,
      etaEmptyTable: 0,
      selectedAt: seatedAt,
    },
    customerId: null,
    sessionType: 'admin_seed',
    appSource: 'admin_seed',
    status: 'seated',
    assignedTableId: tableId,
    assignedTableNumber: tableNumber,
    estimatedWaitMinutes: 0,
    queuePosition: 0,
    extensionUsed: false,
    joinedAt: minutesAgo(40 + scenario.tokenNumber - 900),
    reservedAt: seatedAt,
    seatedAt,
    tableCycleStartAt: seatedAt,
    tableCycleSource: 'seed_partial_occupancy',
    updatedAt: seatedAt,
  });

  await patchDocument(tablePath, {
    tableNumber,
    displayTableName: `${floorId}-${tableNumber}`,
    floorId,
    capacity: scenario.capacity,
    tableType: `${scenario.capacity}-top`,
    section: table.section,
    status: 'occupied',
    currentQueueEntryId: queueEntryId,
    currentTokenCode: tokenCode,
    currentPartySize: scenario.partySize,
    currentCycleStartAt: seatedAt,
    currentCycleSource: 'seed_partial_occupancy',
    reservedAt: seatedAt,
    occupiedAt: seatedAt,
    cleaningStartedAt: null,
    sortOrder: Number(tableFields.sortOrder?.integerValue ?? 0),
    updatedAt: seatedAt,
  });
  console.log(
    `Seeded partial ${tableNumber}: ${scenario.partySize}/${scenario.capacity} occupied (${tokenCode})`,
  );
}

await patchDocument(`${basePath}/dailyCounters/${businessDate}`, {
  businessDate,
  lastTokenNumber: queueCount,
  totalJoined: queueCount,
  totalSeated: partialOccupancyScenarios.length,
  totalSkipped: 0,
  totalCancelled: 0,
  totalNoShow: 0,
  peakQueueDepth: queueCount,
  updatedAt: new Date(now).toISOString(),
});

console.log(
  `Seeded ${queueCount} waiting parties in Q-number/FIFO order and reset ${spiceHouseTables.length} tables on ${restaurantBranchId} in ${projectId}.`,
);
