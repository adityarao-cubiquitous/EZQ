import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const dryRun = process.argv.includes('--dry-run');
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

const legacySubcollections = [
  'floors',
  'tables',
  'settings',
  'queueEntries',
  'dailyReports',
  'dailyCounters',
];

const summary = {
  projectId,
  dryRun,
  legacyRestaurantsFound: 0,
  legacyBranchesFound: 0,
  restaurantBranchesCreated: 0,
  restaurantBranchesSkipped: 0,
  restaurantBranchesFailed: 0,
  subcollectionsMigrated: {},
  subcollectionsSkipped: {},
  failed: [],
  migrationPlan: [],
  adminMappings: {
    checked: 0,
    valid: 0,
    broken: [],
  },
  legacyCollectionsRemaining: [],
};

function httpsJson({ method = 'GET', path, body }) {
  const payload = body ? JSON.stringify(body) : undefined;
  return new Promise((resolve, reject) => {
    const req = request(
      {
        method,
        hostname: 'firestore.googleapis.com',
        path,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
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
          const error = new Error(`${res.statusCode} ${JSON.stringify(parsed)}`);
          error.statusCode = res.statusCode;
          error.response = parsed;
          reject(error);
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function documentsBase() {
  return `/v1/projects/${projectId}/databases/(default)/documents`;
}

function encodePath(path) {
  return path
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

async function listDocuments(collectionPath) {
  const documents = [];
  let pageToken;
  do {
    const params = new URLSearchParams({ pageSize: '100' });
    if (pageToken) params.set('pageToken', pageToken);
    const response = await httpsJson({
      path: `${documentsBase()}/${encodePath(collectionPath)}?${params}`,
    });
    documents.push(...(response.documents ?? []));
    pageToken = response.nextPageToken;
  } while (pageToken);
  return documents;
}

async function getDocument(path) {
  try {
    return await httpsJson({ path: `${documentsBase()}/${encodePath(path)}` });
  } catch (error) {
    if (error.statusCode === 404) return null;
    throw error;
  }
}

async function createDocument(path, document) {
  if (dryRun) return { dryRun: true };
  return httpsJson({
    method: 'PATCH',
    path: `${documentsBase()}/${encodePath(path)}?currentDocument.exists=false`,
    body: document,
  });
}

function documentId(document) {
  return document.name.split('/').pop();
}

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((item) => firestoreValue(item)),
      },
    };
  }
  if (typeof value === 'object') {
    if (
      typeof value.latitude === 'number' &&
      typeof value.longitude === 'number' &&
      Object.keys(value).length === 2
    ) {
      return {
        geoPointValue: {
          latitude: value.latitude,
          longitude: value.longitude,
        },
      };
    }
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, nestedValue]) => [
            key,
            firestoreValue(nestedValue),
          ]),
        ),
      },
    };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  return { stringValue: String(value) };
}

function fromFirestoreValue(value) {
  if (!value) return undefined;
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('stringValue' in value) return value.stringValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('geoPointValue' in value) return value.geoPointValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map((item) =>
      fromFirestoreValue(item),
    );
  }
  if ('mapValue' in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields ?? {}).map(([key, nestedValue]) => [
        key,
        fromFirestoreValue(nestedValue),
      ]),
    );
  }
  return undefined;
}

function fromDocument(document) {
  return Object.fromEntries(
    Object.entries(document.fields ?? {}).map(([key, value]) => [
      key,
      fromFirestoreValue(value),
    ]),
  );
}

function toDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function slugify(value) {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');
}

function firstString(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return '';
}

function timestampOrNow(value) {
  if (typeof value === 'string' && value.trim().length > 0) {
    return new Date(value);
  }
  return new Date();
}

function normalizeGeoPoint(data) {
  const point = data.geoPoint ?? data.geoLocation ?? data.location;
  if (
    point &&
    typeof point.latitude === 'number' &&
    typeof point.longitude === 'number'
  ) {
    return {
      latitude: point.latitude,
      longitude: point.longitude,
    };
  }
  return null;
}

function tableCapacity(table) {
  const capacity = Number(table.capacity ?? table.seats ?? 0);
  return Number.isFinite(capacity) && capacity > 0 ? capacity : null;
}

function inferFloorId(table) {
  return firstString(table.floorId, table.floorName, table.floor) || 'F1';
}

async function buildRestaurantBranchDocument({
  restaurantId,
  branchId,
  restaurantData,
  branchData,
  tables,
  floors,
}) {
  const restaurantName = firstString(
    branchData.restaurantName,
    restaurantData.restaurantName,
    restaurantData.name,
    restaurantId,
  );
  const branchName = firstString(branchData.branchName, branchData.name, branchId);
  const capacityTypes = [
    ...new Set(tables.map(tableCapacity).filter((capacity) => capacity != null)),
  ].sort((left, right) => left - right);
  const totalTables = tables.length;
  const totalSeats = tables.reduce(
    (sum, table) => sum + (tableCapacity(table) ?? 0),
    0,
  );
  const inferredFloors = new Set([
    ...floors.map((floor) => firstString(floor.floorId, floor.floorName, floor.id)),
    ...tables.map(inferFloorId),
  ]);
  const floorCount = Math.max(1, inferredFloors.size);

  return toDocument({
    id: `${slugify(restaurantId)}-${slugify(branchId)}`,
    slug: firstString(branchData.slug, branchData.qrSlug, `${restaurantId}-${branchId}`),
    restaurantName,
    branchName,
    displayName: firstString(
      branchData.displayName,
      `${restaurantName} - ${branchName}`,
    ),
    area: firstString(branchData.area, branchData.locality, restaurantData.area),
    address: firstString(branchData.address, restaurantData.address),
    geoPoint: normalizeGeoPoint(branchData),
    subscription: branchData.subscription ?? restaurantData.subscription ?? {
      plan: 'starter',
      status: 'trial',
    },
    isActive: branchData.isActive ?? restaurantData.isActive ?? true,
    onboardingCompleted: branchData.onboardingCompleted ?? totalTables > 0,
    capacityTypes,
    floorCount,
    totalTables,
    totalSeats,
    createdAt: timestampOrNow(branchData.createdAt ?? restaurantData.createdAt),
    updatedAt: new Date(),
  });
}

async function copySubcollection({ legacyBasePath, targetBasePath, collection }) {
  const legacyDocs = await listDocuments(`${legacyBasePath}/${collection}`);
  summary.subcollectionsMigrated[collection] ??= 0;
  summary.subcollectionsSkipped[collection] ??= 0;
  for (const legacyDoc of legacyDocs) {
    const id = documentId(legacyDoc);
    const targetPath = `${targetBasePath}/${collection}/${id}`;
    const existing = await getDocument(targetPath);
    if (existing) {
      summary.subcollectionsSkipped[collection]++;
      continue;
    }
    await createDocument(targetPath, { fields: legacyDoc.fields ?? {} });
    summary.subcollectionsMigrated[collection]++;
  }
  return legacyDocs.length;
}

async function migrate() {
  const restaurants = await listDocuments('restaurants');
  summary.legacyRestaurantsFound = restaurants.length;
  if (restaurants.length > 0) summary.legacyCollectionsRemaining.push('restaurants');

  for (const restaurantDoc of restaurants) {
    const restaurantId = documentId(restaurantDoc);
    const restaurantData = fromDocument(restaurantDoc);
    const branches = await listDocuments(`restaurants/${restaurantId}/branches`);

    for (const branchDoc of branches) {
      const branchId = documentId(branchDoc);
      const restaurantBranchId = `${slugify(restaurantId)}-${slugify(branchId)}`;
      const legacyBasePath = `restaurants/${restaurantId}/branches/${branchId}`;
      const targetBasePath = `restaurantBranches/${restaurantBranchId}`;
      const branchData = fromDocument(branchDoc);
      const [tableDocs, floorDocs] = await Promise.all([
        listDocuments(`${legacyBasePath}/tables`),
        listDocuments(`${legacyBasePath}/floors`),
      ]);
      const tables = tableDocs.map(fromDocument);
      const floors = floorDocs.map(fromDocument);

      summary.legacyBranchesFound++;
      summary.migrationPlan.push({
        legacyPath: legacyBasePath,
        targetPath: targetBasePath,
        restaurantName: firstString(
          branchData.restaurantName,
          restaurantData.restaurantName,
          restaurantData.name,
          restaurantId,
        ),
        branchName: firstString(branchData.branchName, branchData.name, branchId),
        area: firstString(branchData.area, branchData.locality),
        tables: tableDocs.length,
        floors: Math.max(1, floors.length || new Set(tables.map(inferFloorId)).size),
      });

      try {
        const existing = await getDocument(targetBasePath);
        if (existing) {
          summary.restaurantBranchesSkipped++;
        } else {
          const targetDoc = await buildRestaurantBranchDocument({
            restaurantId,
            branchId,
            restaurantData,
            branchData,
            tables,
            floors,
          });
          await createDocument(targetBasePath, targetDoc);
          summary.restaurantBranchesCreated++;
        }

        for (const collection of legacySubcollections) {
          await copySubcollection({ legacyBasePath, targetBasePath, collection });
        }
      } catch (error) {
        summary.restaurantBranchesFailed++;
        summary.failed.push({
          legacyPath: legacyBasePath,
          targetPath: targetBasePath,
          error: error.message,
        });
      }
    }
  }

  await verifyAdminMappings();
}

async function verifyAdminMappings() {
  const admins = await listDocuments('admins');
  summary.adminMappings.checked = admins.length;
  for (const adminDoc of admins) {
    const adminId = documentId(adminDoc);
    const adminData = fromDocument(adminDoc);
    const restaurantBranchId = firstString(adminData.restaurantBranchId);
    if (!restaurantBranchId) {
      summary.adminMappings.broken.push({
        adminId,
        reason: 'Missing restaurantBranchId',
      });
      continue;
    }
    const target = await getDocument(`restaurantBranches/${restaurantBranchId}`);
    if (!target) {
      summary.adminMappings.broken.push({
        adminId,
        restaurantBranchId,
        reason: `Missing restaurantBranches/${restaurantBranchId}`,
      });
      continue;
    }
    summary.adminMappings.valid++;
  }
}

await migrate();

console.log(JSON.stringify(summary, null, 2));
