import { request } from 'node:https';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const apiKey = 'AIzaSyDGZwnvuJktEqZU2vLXiDaP5-Uuz3nsDP0';
const restaurantId = 'the-spice-house';
const branchId = 'indiranagar';
const basePath = `restaurants/${restaurantId}/branches/${branchId}`;
const businessDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Kolkata',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(new Date());
const runId = Date.now().toString().slice(-6);
const queueEntryId = `e2e-${runId}`;
const nextQueueEntryId = `e2e-next-${runId}`;
const tokenNumber = 900 + Number(runId.slice(-2));
const tokenCode = `Q${tokenNumber}`;
const nextTokenCode = `Q${tokenNumber + 1}`;
const tableId = 't3';
const completedPartySize = 3;

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  return { stringValue: String(value) };
}

function fromFirestoreValue(value) {
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('stringValue' in value) return value.stringValue;
  return undefined;
}

function toDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function fromDocument(document) {
  return Object.fromEntries(
    Object.entries(document.fields ?? {}).map(([key, value]) => [
      key,
      fromFirestoreValue(value),
    ]),
  );
}

function callFirestore(method, path, data) {
  const body = data === undefined ? undefined : JSON.stringify(toDocument(data));
  const requestPath = `/v1/projects/${projectId}/databases/(default)/documents/${path}?key=${apiKey}`;

  return new Promise((resolve, reject) => {
    const req = request(
      {
        method,
        hostname: 'firestore.googleapis.com',
        path: requestPath,
        headers: {
          'Content-Type': 'application/json',
          ...(body ? {'Content-Length': Buffer.byteLength(body)} : {}),
        },
      },
      (res) => {
        let responseBody = '';
        res.on('data', (chunk) => {
          responseBody += chunk;
        });
        res.on('end', () => {
          const parsed = responseBody ? JSON.parse(responseBody) : null;
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
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
    req.end(body);
  });
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
  console.log(`PASS ${label}: ${actual}`);
}

const now = new Date().toISOString();
const cycleStartAt = new Date(Date.now() - 32 * 60 * 1000).toISOString();

console.log(`Starting E2E smoke with ${queueEntryId} / ${tokenCode}`);

await callFirestore('PATCH', `${basePath}/queueEntries/${queueEntryId}`, {
  tokenNumber,
  tokenCode,
  businessDate,
  customerName: 'E2E Test Guest',
  phone: '+919999000111',
  partySize: 3,
  partySizeBand: '3-4',
  notes: 'Automated end-to-end smoke test',
  customerId: null,
  sessionType: 'web_guest',
  appSource: 'web_e2e',
  status: 'waiting',
  assignedTableId: null,
  assignedTableNumber: null,
  estimatedWaitMinutes: 10,
  queuePosition: 1,
  extensionUsed: false,
  joinedAt: now,
  createdAt: now,
  updatedAt: now,
});

let queueEntry = fromDocument(
  await callFirestore('GET', `${basePath}/queueEntries/${queueEntryId}`),
);
assertEqual(queueEntry.status, 'waiting', 'customer joined queue');
assertEqual(queueEntry.partySize, 3, 'customer party size stored');

await callFirestore('PATCH', `${basePath}/tables/${tableId}`, {
  tableNumber: 'T3',
  capacity: 4,
  tableType: '4-top',
  section: 'patio',
  status: 'occupied',
  currentQueueEntryId: queueEntryId,
  currentTokenCode: tokenCode,
  currentCycleStartAt: cycleStartAt,
  currentCycleSource: 'first_reservation',
  occupiedAt: now,
  sortOrder: 3,
  updatedAt: now,
});

await callFirestore('PATCH', `${basePath}/queueEntries/${queueEntryId}`, {
  ...queueEntry,
  status: 'seated',
  assignedTableId: tableId,
  assignedTableNumber: 'T3',
  tableCycleStartAt: cycleStartAt,
  tableCycleSource: 'first_reservation',
  seatedAt: now,
  updatedAt: now,
});

let table = fromDocument(await callFirestore('GET', `${basePath}/tables/${tableId}`));
queueEntry = fromDocument(
  await callFirestore('GET', `${basePath}/queueEntries/${queueEntryId}`),
);
assertEqual(table.status, 'occupied', 'manager seated table');
assertEqual(table.currentQueueEntryId, queueEntryId, 'table linked to token');
assertEqual(queueEntry.status, 'seated', 'queue entry marked seated');

await callFirestore('PATCH', `${basePath}/tables/${tableId}`, {
  tableNumber: 'T3',
  capacity: 4,
  tableType: '4-top',
  section: 'patio',
  status: 'available',
  currentQueueEntryId: null,
  currentTokenCode: null,
  reservedAt: null,
  occupiedAt: null,
  cleaningStartedAt: null,
  lastCompletedQueueEntryId: queueEntryId,
  lastCompletedPartySize: completedPartySize,
  lastCompletedAt: now,
  lastCycleStartAt: cycleStartAt,
  lastCycleEndAt: now,
  currentCycleStartAt: null,
  currentCycleSource: null,
  sortOrder: 3,
  updatedAt: now,
});

await callFirestore('PATCH', `${basePath}/queueEntries/${queueEntryId}`, {
  ...queueEntry,
  status: 'completed',
  completedAt: now,
  completedPartySize,
  tableCycleStartAt: cycleStartAt,
  tableCycleEndAt: now,
  updatedAt: now,
});

table = fromDocument(await callFirestore('GET', `${basePath}/tables/${tableId}`));
queueEntry = fromDocument(
  await callFirestore('GET', `${basePath}/queueEntries/${queueEntryId}`),
);
assertEqual(table.status, 'available', 'meal finished frees table');
assertEqual(table.currentQueueEntryId, null, 'table token cleared');
assertEqual(table.lastCompletedPartySize, completedPartySize, 'finished guest count stored on table');
assertEqual(table.lastCycleStartAt, cycleStartAt, 'table cycle start preserved');
assertEqual(table.lastCycleEndAt, now, 'table cycle end stored');
assertEqual(queueEntry.status, 'completed', 'queue entry marked completed');
assertEqual(queueEntry.completedPartySize, completedPartySize, 'finished guest count stored on queue entry');
assertEqual(queueEntry.tableCycleEndAt, now, 'queue entry cycle end stored');

const nextQueueEntryData = {
  tokenNumber: tokenNumber + 1,
  tokenCode: nextTokenCode,
  businessDate,
  customerName: 'E2E Next Guest',
  phone: '+919999000222',
  partySize: 2,
  partySizeBand: '1-2',
  notes: 'Follow-up table cycle test',
  customerId: null,
  sessionType: 'web_guest',
  appSource: 'web_e2e',
  status: 'waiting',
  assignedTableId: null,
  assignedTableNumber: null,
  estimatedWaitMinutes: 5,
  queuePosition: 1,
  extensionUsed: false,
  joinedAt: now,
  createdAt: now,
  updatedAt: now,
};

await callFirestore(
  'PATCH',
  `${basePath}/queueEntries/${nextQueueEntryId}`,
  nextQueueEntryData,
);

const previousEndAt = table.lastCycleEndAt;
await callFirestore('PATCH', `${basePath}/tables/${tableId}`, {
  tableNumber: 'T3',
  capacity: 4,
  tableType: '4-top',
  section: 'patio',
  status: 'occupied',
  currentQueueEntryId: nextQueueEntryId,
  currentTokenCode: nextTokenCode,
  reservedAt: now,
  occupiedAt: now,
  currentCycleStartAt: previousEndAt,
  currentCycleSource: 'previous_completion',
  sortOrder: 3,
  updatedAt: now,
});

await callFirestore('PATCH', `${basePath}/queueEntries/${nextQueueEntryId}`, {
  ...nextQueueEntryData,
  status: 'seated',
  assignedTableId: tableId,
  assignedTableNumber: 'T3',
  reservedAt: now,
  seatedAt: now,
  tableCycleStartAt: previousEndAt,
  tableCycleSource: 'previous_completion',
  updatedAt: now,
});

table = fromDocument(await callFirestore('GET', `${basePath}/tables/${tableId}`));
const nextQueueEntry = fromDocument(
  await callFirestore('GET', `${basePath}/queueEntries/${nextQueueEntryId}`),
);
assertEqual(
  table.currentCycleStartAt,
  previousEndAt,
  'next table cycle starts at previous end',
);
assertEqual(
  nextQueueEntry.tableCycleStartAt,
  previousEndAt,
  'next queue entry starts at previous table end',
);

console.log(
  JSON.stringify(
    {
      projectId,
      businessDate,
      queueEntryId,
      nextQueueEntryId,
      tokenCode,
      tableId,
      completedPartySize,
      status: 'PASS',
    },
    null,
    2,
  ),
);
