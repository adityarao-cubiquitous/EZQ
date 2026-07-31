import { readFile, writeFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const DEFAULT_PROJECT_ID = 'ezq-dev-cubiquitous';
const ACTIVE_QUEUE_STATUSES = new Set([
  'waiting',
  'reserved',
  'on_the_way',
  'seated',
]);
const CANCELLABLE_QUEUE_STATUSES = new Set([
  'waiting',
  'reserved',
  'on_the_way',
]);
const RESETTABLE_TABLE_STATUSES = new Set([
  'reserved',
  'occupied',
  'cleaning',
]);

const args = process.argv.slice(2);
const execute = args.includes('--execute');
const positional = positionalArgs(args);
const reason = valueAfter('--reason') ?? 'manual fail-safe queue clear';
const projectId =
  positional.length >= 2 ? positional[0] : DEFAULT_PROJECT_ID;
const restaurantBranchId =
  positional.length >= 2 ? positional[1] : positional[0];

if (args.includes('--help') || args.includes('-h')) {
  printUsage();
  process.exit(0);
}

if (!restaurantBranchId) {
  printUsage();
  process.exit(1);
}

const basePath = `restaurantBranches/${restaurantBranchId}`;
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
let accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

await refreshFirebaseCliTokenIfNeeded();

const runStartedAt = new Date();
const runId = `clear-${compactTimestamp(runStartedAt)}-${Math.random()
  .toString(36)
  .slice(2, 8)}`;
const businessDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Kolkata',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(runStartedAt);

const branchDoc = await getDocument(basePath);
if (!branchDoc) {
  throw new Error(`Restaurant branch not found: ${basePath}`);
}

const [queueDocs, tableDocs] = await Promise.all([
  listCollection(`${basePath}/queueEntries`),
  listCollection(`${basePath}/tables`),
]);

const liveQueuePlans = queueDocs
  .map((doc) => planQueueUpdate(doc, runStartedAt))
  .filter(Boolean);
const tablePlans = tableDocs
  .map((doc) => planTableUpdate(doc, runStartedAt))
  .filter(Boolean);

const cancelledCount = liveQueuePlans.filter(
  (plan) => plan.after.status === 'cancelled',
).length;
const completedCount = liveQueuePlans.filter(
  (plan) => plan.after.status === 'completed',
).length;
const guestsCompleted = liveQueuePlans.reduce((total, plan) => {
  if (plan.after.status !== 'completed') return total;
  return total + integerFrom(plan.before.partySize, 0);
}, 0);

printPlan({
  execute,
  projectId,
  restaurantBranchId,
  runId,
  reason,
  queueDocs,
  tableDocs,
  liveQueuePlans,
  tablePlans,
  cancelledCount,
  completedCount,
  guestsCompleted,
});

if (!execute) {
  console.log('\nDry run only. Re-run with --execute to apply these changes.');
  process.exit(0);
}

for (const plan of liveQueuePlans) {
  await patchDocument(plan.path, plan.after);
}

for (const plan of tablePlans) {
  await patchDocument(plan.path, plan.after);
}

const counterPath = `${basePath}/dailyCounters/${businessDate}`;
const existingCounter = await getDocument(counterPath);
const counter = existingCounter ? decodeFields(existingCounter.fields ?? {}) : {};
await patchDocument(counterPath, {
  businessDate,
  totalCancelled: integerFrom(counter.totalCancelled, 0) + cancelledCount,
  totalCompleted: integerFrom(counter.totalCompleted, 0) + completedCount,
  totalGuestsCompleted:
    integerFrom(counter.totalGuestsCompleted, 0) + guestsCompleted,
  lastQueueClearRunId: runId,
  lastQueueClearAt: runStartedAt,
  lastQueueClearReason: reason,
  updatedAt: runStartedAt,
});

await patchDocument(`${basePath}/adminActions/${runId}`, {
  type: 'clear_branch_queue',
  restaurantBranchId,
  reason,
  dryRun: false,
  queueEntriesScanned: queueDocs.length,
  queueEntriesUpdated: liveQueuePlans.length,
  tablesScanned: tableDocs.length,
  tablesUpdated: tablePlans.length,
  cancelledCount,
  completedCount,
  guestsCompleted,
  createdAt: runStartedAt,
  updatedAt: runStartedAt,
});

console.log(
  `\nApplied ${runId}: updated ${liveQueuePlans.length} queue entries and ${tablePlans.length} tables.`,
);

function valueAfter(flag) {
  const equalsArg = args.find((arg) => arg.startsWith(`${flag}=`));
  if (equalsArg) return equalsArg.slice(flag.length + 1);
  const index = args.indexOf(flag);
  if (index === -1) return null;
  return args[index + 1] && !args[index + 1].startsWith('--')
    ? args[index + 1]
    : null;
}

function positionalArgs(rawArgs) {
  const values = [];
  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg === '--reason') {
      index += 1;
      continue;
    }
    if (arg.startsWith('--')) continue;
    values.push(arg);
  }
  return values;
}

function printUsage() {
  console.log(`
Usage:
  node tool/clear_branch_queue.mjs <restaurantBranchId> [--reason "text"]
  node tool/clear_branch_queue.mjs <projectId> <restaurantBranchId> [--execute] [--reason "text"]

Examples:
  node tool/clear_branch_queue.mjs grill-garden-old-airport-road
  node tool/clear_branch_queue.mjs ezq-dev-cubiquitous grill-garden-old-airport-road --execute --reason "closing reset"

Behavior:
  - Dry-run by default.
  - Never deletes queue history.
  - Cancels waiting/reserved/on-the-way entries.
  - Completes seated entries and releases their tables.
  - Releases occupied/reserved/cleaning tables or tables with stale queue linkage.
  - Writes an audit document under restaurantBranches/{branchId}/adminActions/{runId}.
`);
}

function compactTimestamp(date) {
  return date.toISOString().replaceAll(/[-:.TZ]/g, '').slice(0, 14);
}

function documentId(doc) {
  return doc.name.split('/').pop();
}

function documentPath(doc) {
  return doc.name.split('/documents/')[1];
}

function planQueueUpdate(doc, nowDate) {
  const data = decodeFields(doc.fields ?? {});
  const status = String(data.status ?? 'waiting');
  if (!ACTIVE_QUEUE_STATUSES.has(status)) return null;

  const common = {
    clearedByFailSafe: true,
    clearQueueReason: reason,
    clearQueueRunId: runId,
    updatedAt: nowDate,
  };

  if (status === 'seated') {
    return {
      id: documentId(doc),
      path: documentPath(doc),
      before: data,
      after: {
        ...common,
        status: 'completed',
        completedAt: nowDate,
        completedPartySize: data.completedPartySize ?? integerFrom(data.partySize, 1),
        tableCycleStartAt: data.tableCycleStartAt ?? data.seatedAt ?? data.reservedAt ?? null,
        tableCycleEndAt: nowDate,
      },
    };
  }

  if (CANCELLABLE_QUEUE_STATUSES.has(status)) {
    return {
      id: documentId(doc),
      path: documentPath(doc),
      before: data,
      after: {
        ...common,
        status: 'cancelled',
        cancelledAt: nowDate,
      },
    };
  }

  return null;
}

function planTableUpdate(doc, nowDate) {
  const data = decodeFields(doc.fields ?? {});
  const status = String(data.status ?? 'available');
  const hasQueueLink =
    data.currentQueueEntryId != null ||
    data.currentTokenCode != null ||
    data.currentPartySize != null ||
    data.reservedAt != null ||
    data.occupiedAt != null ||
    data.currentCycleStartAt != null;

  if (!RESETTABLE_TABLE_STATUSES.has(status) && !hasQueueLink) return null;

  const wasActiveCycle =
    status === 'occupied' ||
    status === 'reserved' ||
    data.currentCycleStartAt != null ||
    data.occupiedAt != null;

  return {
    id: documentId(doc),
    path: documentPath(doc),
    before: data,
    after: {
      status: 'available',
      currentQueueEntryId: null,
      currentTokenCode: null,
      currentPartySize: null,
      reservedAt: null,
      occupiedAt: null,
      cleaningStartedAt: null,
      currentCycleStartAt: null,
      currentCycleSource: null,
      lastCompletedQueueEntryId: data.currentQueueEntryId ?? null,
      lastCycleStartAt: data.currentCycleStartAt ?? data.occupiedAt ?? null,
      lastCycleEndAt: wasActiveCycle ? nowDate : data.lastCycleEndAt ?? null,
      lastCompletedAt: wasActiveCycle ? nowDate : data.lastCompletedAt ?? null,
      clearedByFailSafe: true,
      clearQueueReason: reason,
      clearQueueRunId: runId,
      updatedAt: nowDate,
    },
  };
}

function printPlan({
  execute: shouldExecute,
  projectId: targetProjectId,
  restaurantBranchId: targetBranchId,
  runId: targetRunId,
  reason: clearReason,
  queueDocs: allQueueDocs,
  tableDocs: allTableDocs,
  liveQueuePlans: plannedQueueUpdates,
  tablePlans: plannedTableUpdates,
  cancelledCount: plannedCancelledCount,
  completedCount: plannedCompletedCount,
  guestsCompleted: plannedGuestsCompleted,
}) {
  console.log(`${shouldExecute ? 'EXECUTE' : 'DRY RUN'} clear-branch-queue`);
  console.log(`Project: ${targetProjectId}`);
  console.log(`Branch: ${targetBranchId}`);
  console.log(`Run ID: ${targetRunId}`);
  console.log(`Reason: ${clearReason}`);
  console.log(`Queue entries scanned: ${allQueueDocs.length}`);
  console.log(`Queue entries to update: ${plannedQueueUpdates.length}`);
  console.log(`  cancel waiting/reserved/on-the-way: ${plannedCancelledCount}`);
  console.log(`  complete seated: ${plannedCompletedCount}`);
  console.log(`  guests completed from seated entries: ${plannedGuestsCompleted}`);
  console.log(`Tables scanned: ${allTableDocs.length}`);
  console.log(`Tables to release/reset: ${plannedTableUpdates.length}`);

  if (plannedQueueUpdates.length) {
    console.log('\nQueue changes:');
    for (const plan of plannedQueueUpdates.slice(0, 20)) {
      console.log(`  ${plan.id}: ${plan.before.status} -> ${plan.after.status}`);
    }
    if (plannedQueueUpdates.length > 20) {
      console.log(`  ...${plannedQueueUpdates.length - 20} more`);
    }
  }

  if (plannedTableUpdates.length) {
    console.log('\nTable changes:');
    for (const plan of plannedTableUpdates.slice(0, 20)) {
      const tableName = plan.before.tableNumber ?? plan.id;
      console.log(`  ${tableName}: ${plan.before.status ?? 'available'} -> available`);
    }
    if (plannedTableUpdates.length > 20) {
      console.log(`  ...${plannedTableUpdates.length - 20} more`);
    }
  }
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

async function getDocument(documentPathToGet) {
  try {
    return await firestoreRequest(
      'GET',
      `/v1/projects/${projectId}/databases/(default)/documents/${documentPathToGet}`,
    );
  } catch (error) {
    if (error.message.includes('404')) return null;
    throw error;
  }
}

async function patchDocument(documentPathToPatch, data) {
  const fieldPaths = Object.keys(data);
  const updateMask = fieldPaths
    .map((fieldPath) => `updateMask.fieldPaths=${encodeURIComponent(fieldPath)}`)
    .join('&');
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/${documentPathToPatch}?${updateMask}`,
    firestoreDocument(data),
  );
}

async function firestoreRequest(method, path, data) {
  const body = data ? JSON.stringify(data) : null;
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
          const parsed = responseBody ? JSON.parse(responseBody) : {};
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
            return;
          }
          reject(new Error(`${method} ${path} failed: ${res.statusCode} ${responseBody}`));
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function firestoreDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
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

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function decodeValue(value) {
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('stringValue' in value) return value.stringValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  if ('mapValue' in value) return decodeFields(value.mapValue.fields ?? {});
  return undefined;
}

function integerFrom(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
}
