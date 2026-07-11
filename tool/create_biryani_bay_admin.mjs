import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const apiKey = 'AIzaSyD6Arqm1ECATHxiA0aUTFNgCe_WHlU5N-4';
const password = 'Welcome@123';
const restaurantBranchId = 'biryani-bay-domlur-edge';
const now = new Date();
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

const adminAccount = {
  email: 'biryani.bay.admin@ezq-demo.cubiquitous.in',
  displayName: 'Biryani Bay Admin',
  phone: '+919999000222',
};

function httpsJson({ method = 'POST', hostname, path, headers = {}, body }) {
  const payload = body ? JSON.stringify(body) : undefined;
  return new Promise((resolve, reject) => {
    const req = request(
      {
        method,
        hostname,
        path,
        headers: {
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
          ...headers,
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
          reject(new Error(`${res.statusCode} ${JSON.stringify(parsed)}`));
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function createOrSignInUser(account) {
  const authBody = {
    email: account.email,
    password,
    displayName: account.displayName,
    returnSecureToken: true,
  };

  try {
    return await httpsJson({
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signUp?key=${apiKey}`,
      body: authBody,
    });
  } catch (error) {
    if (!String(error.message).includes('EMAIL_EXISTS')) throw error;
    return httpsJson({
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithPassword?key=${apiKey}`,
      body: {
        email: account.email,
        password,
        returnSecureToken: true,
      },
    });
  }
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

function firestoreDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

async function patchDocument(path, data) {
  await httpsJson({
    method: 'PATCH',
    hostname: 'firestore.googleapis.com',
    path: `/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    headers: { Authorization: `Bearer ${accessToken}` },
    body: firestoreDocument(data),
  });
}

async function getDocument(path) {
  return httpsJson({
    method: 'GET',
    hostname: 'firestore.googleapis.com',
    path: `/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}

const adminAuth = await createOrSignInUser(adminAccount);

await patchDocument(`restaurantBranches/${restaurantBranchId}`, {
  id: restaurantBranchId,
  slug: restaurantBranchId,
  restaurantName: 'Biryani Bay',
  branchName: 'Domlur Edge',
  displayName: 'Biryani Bay - Domlur Edge',
  area: 'Domlur',
  address: 'Domlur Edge, Bengaluru',
  geoPoint: {
    latitude: 12.9611,
    longitude: 77.6387,
  },
  subscription: {
    plan: 'starter',
    status: 'trial',
  },
  qrSlug: 'biryani-bay-domlur-edge',
  isActive: true,
  onboardingCompleted: false,
  floorCount: 0,
  totalTables: 0,
  totalSeats: 0,
  capacityTypes: [],
  createdAt: now,
  updatedAt: now,
});

await patchDocument(`admins/${adminAuth.localId}`, {
  uid: adminAuth.localId,
  name: adminAccount.displayName,
  email: adminAccount.email,
  phone: adminAccount.phone,
  restaurantBranchId,
  role: 'owner',
  isActive: true,
  onboardingCompleted: false,
  createdAt: now,
  updatedAt: now,
});

const [restaurantBranchDoc, adminDoc] = await Promise.all([
  getDocument(`restaurantBranches/${restaurantBranchId}`),
  getDocument(`admins/${adminAuth.localId}`),
]);

console.log(
  JSON.stringify(
    {
      restaurantBranchId,
      admin: {
        uid: adminAuth.localId,
        email: adminAccount.email,
        password,
        role: 'owner',
      },
      documents: {
        restaurantBranch: restaurantBranchDoc.name,
        admin: adminDoc.name,
      },
    },
    null,
    2,
  ),
);
