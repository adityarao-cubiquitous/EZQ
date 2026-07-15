import { readFile, writeFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const restaurantBranchId = process.argv[3] ?? 'grill-garden-old-airport-road';
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
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
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
          reject(
            new Error(`Token refresh failed: ${res.statusCode} ${responseBody}`),
          );
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

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value).map(([key, nested]) => [
          key,
          firestoreValue(nested),
        ]),
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

function partySizeBand(partySize) {
  if (partySize <= 2) return '1-2';
  if (partySize <= 4) return '3-4';
  if (partySize <= 6) return '5-6';
  return '7+';
}

const floors = [
  { floorId: 'F1', floorName: 'Ground Floor', displayOrder: 1 },
  { floorId: 'F2', floorName: 'Terrace Floor', displayOrder: 2 },
];

const tablePlan = [
  { floorId: 'F1', capacity: 2, count: 6 },
  { floorId: 'F1', capacity: 4, count: 6 },
  { floorId: 'F1', capacity: 6, count: 2 },
  { floorId: 'F2', capacity: 2, count: 4 },
  { floorId: 'F2', capacity: 4, count: 4 },
  { floorId: 'F2', capacity: 6, count: 2 },
  { floorId: 'F2', capacity: 8, count: 1 },
];

const tables = [];
let tableNumber = 1;
for (const item of tablePlan) {
  for (let index = 0; index < item.count; index += 1) {
    const tableId = `t${String(tableNumber).padStart(2, '0')}`;
    tables.push({
      id: tableId,
      tableNumber: `T${tableNumber}`,
      displayTableName: `${item.floorId}-T${tableNumber}`,
      capacity: item.capacity,
      tableType: `${item.capacity}-top`,
      section: item.floorId === 'F1' ? 'main dining' : 'terrace',
      floorId: item.floorId,
      status: 'available',
      currentQueueEntryId: null,
      currentTokenCode: null,
      currentPartySize: null,
      reservedAt: null,
      occupiedAt: null,
      cleaningStartedAt: null,
      currentCycleStartAt: null,
      currentCycleSource: null,
      sortOrder: tableNumber,
      updatedAt: new Date(now).toISOString(),
    });
    tableNumber += 1;
  }
}

const seatedScenarios = [
  { tableId: 't07', tokenNumber: 1, name: 'Rohan Kapoor', partySize: 4, minutes: 42 },
  { tableId: 't13', tokenNumber: 2, name: 'Meera Iyer', partySize: 6, minutes: 25 },
  { tableId: 't21', tokenNumber: 3, name: 'Arjun Nair', partySize: 4, minutes: 12 },
];

for (const scenario of seatedScenarios) {
  const table = tables.find((candidate) => candidate.id === scenario.tableId);
  if (!table) continue;
  const tokenCode = `Q${String(scenario.tokenNumber).padStart(2, '0')}`;
  const queueEntryId = `q${String(scenario.tokenNumber).padStart(2, '0')}`;
  table.status = 'occupied';
  table.currentQueueEntryId = queueEntryId;
  table.currentTokenCode = tokenCode;
  table.currentPartySize = scenario.partySize;
  table.reservedAt = minutesAgo(scenario.minutes);
  table.occupiedAt = minutesAgo(scenario.minutes);
  table.currentCycleStartAt = minutesAgo(scenario.minutes);
  table.currentCycleSource = 'manual_test_seed';
}

const waitingParties = [
  { name: 'Nitya Shah', phone: '+919900110001', partySize: 2, wait: 18, preference: 'ANY_AVAILABLE', notes: 'Prefers quiet corner' },
  { name: 'Derek Joseph', phone: '+919900110002', partySize: 4, wait: 14, preference: 'EMPTY_TABLE_ONLY', notes: 'Birthday cake coming later' },
  { name: 'Ananya Rao', phone: '+919900110003', partySize: 6, wait: 10, preference: 'ANY_AVAILABLE', notes: 'Needs one high chair' },
  { name: 'Kabir Menon', phone: '+919900110004', partySize: 3, wait: 7, preference: 'ANY_AVAILABLE', notes: 'Fast seating if possible' },
  { name: 'Priya Thomas', phone: '+919900110005', partySize: 8, wait: 4, preference: 'EMPTY_TABLE_ONLY', notes: 'Family group, keep together' },
];

const existingQueueDocs = await listCollection(`${basePath}/queueEntries`);
for (const doc of existingQueueDocs) {
  await deleteDocument(doc.name);
}

const existingTableDocs = await listCollection(`${basePath}/tables`);
for (const doc of existingTableDocs) {
  await deleteDocument(doc.name);
}

const existingFloorDocs = await listCollection(`${basePath}/floors`);
for (const doc of existingFloorDocs) {
  await deleteDocument(doc.name);
}

for (const floor of floors) {
  const floorTables = tables.filter((table) => table.floorId === floor.floorId);
  await patchDocument(`${basePath}/floors/${floor.floorId}`, {
    ...floor,
    tableCount: floorTables.length,
    seatCount: floorTables.reduce((total, table) => total + table.capacity, 0),
    updatedAt: new Date(now).toISOString(),
  });
}

for (const table of tables) {
  await patchDocument(`${basePath}/tables/${table.id}`, table);
}

for (const scenario of seatedScenarios) {
  const table = tables.find((candidate) => candidate.id === scenario.tableId);
  const tokenCode = `Q${String(scenario.tokenNumber).padStart(2, '0')}`;
  const queueEntryId = `q${String(scenario.tokenNumber).padStart(2, '0')}`;
  await patchDocument(`${basePath}/queueEntries/${queueEntryId}`, {
    tokenNumber: scenario.tokenNumber,
    tokenCode,
    businessDate,
    customerName: scenario.name,
    phone: `+919900119${String(scenario.tokenNumber).padStart(3, '0')}`,
    partySize: scenario.partySize,
    partySizeBand: partySizeBand(scenario.partySize),
    notes: 'Seeded seated party for finish-meal testing',
    customerId: null,
    sessionType: 'admin_seed',
    appSource: 'admin_seed',
    status: 'seated',
    assignedTableId: table.id,
    assignedTableNumber: table.displayTableName,
    estimatedWaitMinutes: 0,
    queuePosition: 0,
    extensionUsed: false,
    joinedAt: minutesAgo(scenario.minutes + 18),
    reservedAt: minutesAgo(scenario.minutes),
    seatedAt: minutesAgo(scenario.minutes),
    tableCycleStartAt: minutesAgo(scenario.minutes),
    tableCycleSource: 'manual_test_seed',
    updatedAt: minutesAgo(scenario.minutes),
  });
}

let nextToken = seatedScenarios.length + 1;
for (const party of waitingParties) {
  const tokenNumber = nextToken;
  const tokenCode = `Q${String(tokenNumber).padStart(2, '0')}`;
  const queueEntryId = `q${String(tokenNumber).padStart(2, '0')}`;
  const etaShared = Math.max(5, party.wait - 3);
  const etaEmptyTable = etaShared + 10;
  await patchDocument(`${basePath}/queueEntries/${queueEntryId}`, {
    tokenNumber,
    tokenCode,
    businessDate,
    customerName: party.name,
    phone: party.phone,
    partySize: party.partySize,
    partySizeBand: partySizeBand(party.partySize),
    notes: party.notes,
    customerId: null,
    sessionType: 'manual_test_seed',
    appSource: 'admin_seed',
    status: 'waiting',
    assignedTableId: null,
    assignedTableNumber: null,
    estimatedWaitMinutes: etaShared,
    queuePosition: tokenNumber - seatedScenarios.length,
    extensionUsed: false,
    joinedAt: minutesAgo(party.wait),
    updatedAt: minutesAgo(Math.max(1, party.wait - 1)),
    customerPreferences: {
      seatingPreference: party.preference,
      floorPreference: null,
      accessibilityRequired: party.notes.toLowerCase().includes('high chair'),
      acceptedLongerWait: party.preference === 'EMPTY_TABLE_ONLY',
      etaShared,
      etaEmptyTable,
      selectedAt: minutesAgo(party.wait),
    },
  });
  nextToken += 1;
}

await patchDocument(`${basePath}/dailyCounters/${businessDate}`, {
  businessDate,
  lastTokenNumber: nextToken - 1,
  totalJoined: nextToken - 1,
  totalSeated: seatedScenarios.length,
  totalSkipped: 0,
  totalCancelled: 0,
  totalNoShow: 0,
  peakQueueDepth: waitingParties.length,
  updatedAt: new Date(now).toISOString(),
});

await patchDocument(basePath, {
  restaurantBranchId,
  isActive: true,
  onboardingCompleted: true,
  floorCount: floors.length,
  totalTables: tables.length,
  totalSeats: tables.reduce((total, table) => total + table.capacity, 0),
  updatedAt: new Date(now).toISOString(),
});

console.log(
  `Seeded ${restaurantBranchId}: ${floors.length} floors, ${tables.length} tables, ${seatedScenarios.length} seated, ${waitingParties.length} waiting.`,
);
