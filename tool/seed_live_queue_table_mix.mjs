import { request } from 'node:https';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const apiKey = 'AIzaSyD6Arqm1ECATHxiA0aUTFNgCe_WHlU5N-4';
const restaurantId = 'the-spice-house';
const branchId = 'indiranagar';
const basePath = `restaurants/${restaurantId}/branches/${branchId}`;

const businessDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Kolkata',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(new Date());

const now = new Date();
const isoNow = now.toISOString();
const minutesAgo = (minutes) =>
  new Date(now.getTime() - minutes * 60_000).toISOString();

function partySizeBand(partySize) {
  if (partySize <= 2) return '1-2';
  if (partySize <= 4) return '3-4';
  if (partySize <= 6) return '5-6';
  return '7+';
}

function toField(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toField) } };
  }
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, nested]) => [key, toField(nested)]),
        ),
      },
    };
  }
  return { stringValue: String(value) };
}

function toDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, toField(value)]),
    ),
  };
}

function requestJson(method, path, data, fieldPaths = []) {
  const body = data === undefined ? undefined : JSON.stringify(toDocument(data));
  const updateMask = fieldPaths
    .map((field) => `&updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('');
  const url =
    `/v1/projects/${projectId}/databases/(default)/documents/${path}` +
    `?key=${apiKey}${updateMask}`;

  return new Promise((resolve, reject) => {
    const req = request(
      {
        method,
        hostname: 'firestore.googleapis.com',
        path: url,
        headers: {
          'Content-Type': 'application/json',
          ...(body ? { 'Content-Length': Buffer.byteLength(body) } : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => {
          raw += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(raw ? JSON.parse(raw) : null);
          } else {
            reject(new Error(`${method} ${path} -> ${res.statusCode}: ${raw}`));
          }
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function patch(path, data) {
  await requestJson('PATCH', path, data, Object.keys(data));
}

async function seedSeatedEntry(path, entry) {
  await patch(path, {
    ...entry,
    status: 'waiting',
    assignedTableId: null,
    assignedTableNumber: null,
    reservedAt: null,
    seatedAt: null,
    tableCycleStartAt: null,
    tableCycleSource: null,
  });
  await patch(path, entry);
}

function queueEntry({
  tokenNumber,
  tokenCode,
  customerName,
  phone,
  partySize,
  status = 'waiting',
  queuePosition,
  joinedAt,
  preference = 'ANY_AVAILABLE',
  assignedTableId = null,
  assignedTableNumber = null,
  notes = null,
}) {
  const estimatedWaitMinutes = Math.max(5, Math.min(120, queuePosition * 4));
  return {
    tokenNumber,
    tokenCode,
    businessDate,
    customerName,
    phone,
    partySize,
    partySizeBand: partySizeBand(partySize),
    notes,
    customerId: null,
    sessionType: 'web_guest',
    appSource: 'web',
    status,
    assignedTableId,
    assignedTableNumber,
    estimatedWaitMinutes,
    queuePosition,
    extensionUsed: false,
    joinedAt,
    reservedAt: status === 'seated' ? joinedAt : null,
    onTheWayAt: null,
    seatedAt: status === 'seated' ? joinedAt : null,
    skippedAt: null,
    cancelledAt: null,
    noShowAt: null,
    expiredAt: null,
    autoExpiredReason: null,
    completedAt: null,
    completedPartySize: null,
    tableCycleStartAt: status === 'seated' ? joinedAt : null,
    tableCycleEndAt: null,
    tableCycleSource: status === 'seated' ? 'live_mix_seed' : null,
    customerPreferences: {
      seatingPreference: preference,
      floorPreference: null,
      accessibilityRequired: false,
      acceptedLongerWait: preference === 'EMPTY_TABLE_ONLY',
      etaShared: Math.max(8, Math.min(65, estimatedWaitMinutes)),
      etaEmptyTable: Math.max(18, Math.min(90, estimatedWaitMinutes + 14)),
      selectedAt: joinedAt,
    },
    updatedAt: isoNow,
  };
}

const tablePlan = [
  ['t1', 'T1', 2, 2],
  ['t5', 'T5', 2, 1],
  ['t6', 'T6', 2, 2],
  ['t7', 'T7', 2, 0],
  ['t15', 'T15', 2, 1],
  ['t16', 'T16', 2, 0],
  ['t17', 'T17', 2, 2],
  ['t2', 'T2', 4, 4],
  ['t3', 'T3', 4, 2],
  ['t8', 'T8', 4, 3],
  ['t9', 'T9', 4, 0],
  ['t10', 'T10', 4, 1],
  ['t18', 'T18', 4, 0],
  ['t19', 'T19', 4, 2],
  ['t20', 'T20', 4, 0],
  ['t21', 'T21', 4, 0],
  ['t4', 'T4', 6, 6],
  ['t11', 'T11', 6, 2],
  ['t12', 'T12', 6, 4],
  ['t22', 'T22', 6, 0],
  ['t23', 'T23', 6, 5],
  ['t24', 'T24', 6, 0],
  ['t13', 'T13', 8, 3],
  ['t25', 'T25', 8, 8],
  ['t26', 'T26', 8, 0],
  ['t14', 'T14', 10, 10],
  ['t27', 'T27', 10, 0],
  ['t28', 'T28', 10, 6],
];

const partySizes = [
  2, 4, 5, 3, 1, 6, 7, 2, 8, 4,
  5, 3, 2, 6, 9, 4, 1, 7, 5, 2,
  3, 8, 6, 4, 10, 2, 5, 7, 3, 1,
];

const waitMinutes = [
  4, 8, 12, 16, 21, 25, 29, 33, 37, 41,
  45, 49, 53, 57, 61, 65, 69, 73, 77, 81,
  84, 86, 10, 18, 26, 34, 42, 50, 58, 66,
];

async function seedTables() {
  for (const [tableId, tableNumber, capacity, occupied] of tablePlan) {
    const isOccupied = occupied > 0;
    const queueEntryId = isOccupied ? `seed-table-${tableId}` : null;
    const tokenCode = isOccupied ? `S${tableNumber.replace(/\D/g, '').padStart(2, '0')}` : null;
    const cycleStartAt = isOccupied ? minutesAgo(18 + occupied * 7) : null;

    if (isOccupied) {
      await seedSeatedEntry(
        `${basePath}/queueEntries/${queueEntryId}`,
        queueEntry({
          tokenNumber: 800 + Number(tableNumber.replace(/\D/g, '')),
          tokenCode,
          customerName: `${tableNumber} seated party`,
          phone: `+91988047${String(8000 + Number(tableNumber.replace(/\D/g, ''))).slice(-4)}`,
          partySize: occupied,
          status: 'seated',
          queuePosition: 0,
          joinedAt: cycleStartAt,
          preference: 'ANY_AVAILABLE',
          assignedTableId: tableId,
          assignedTableNumber: tableNumber,
          notes: 'Seeded seated party for live table mix',
        }),
      );
    }

    await patch(`${basePath}/tables/${tableId}`, {
      tableNumber,
      capacity,
      tableType: `${capacity}-top`,
      section: 'main',
      floorId: 'F1',
      status: isOccupied ? 'occupied' : 'available',
      occupancy: occupied,
      currentQueueEntryId: queueEntryId,
      currentTokenCode: tokenCode,
      currentCycleStartAt: cycleStartAt,
      currentCycleSource: isOccupied ? 'live_mix_seed' : null,
      occupiedAt: cycleStartAt,
      reservedAt: cycleStartAt,
      sortOrder: Number(tableNumber.replace(/\D/g, '')),
      updatedAt: isoNow,
    });
  }
}

async function seedQueue() {
  for (let index = 0; index < partySizes.length; index += 1) {
    const tokenNumber = 101 + index;
    const tokenCode = `Q${tokenNumber}`;
    const preference = index % 3 === 1 ? 'EMPTY_TABLE_ONLY' : 'ANY_AVAILABLE';
    await patch(
      `${basePath}/queueEntries/seed-live-${String(index + 1).padStart(2, '0')}`,
      queueEntry({
        tokenNumber,
        tokenCode,
        customerName: `Live Test ${String(index + 1).padStart(2, '0')}`,
        phone: `+91988047${String(9000 + index).slice(-4)}`,
        partySize: partySizes[index],
        queuePosition: index + 1,
        joinedAt: minutesAgo(waitMinutes[index]),
        preference,
        notes:
          preference === 'EMPTY_TABLE_ONLY'
            ? 'Seeded empty-table preference'
            : 'Seeded shared-seating preference',
      }),
    );
  }
}

console.log(`Seeding live queue/table mix for ${projectId}`);
console.log(`Branch: ${basePath}`);
console.log(`Business date: ${businessDate}`);
await seedTables();
await seedQueue();
console.log('Done. Added 30 waiting entries and refreshed table occupancy mix.');
