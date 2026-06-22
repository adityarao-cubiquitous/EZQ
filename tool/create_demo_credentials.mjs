import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const apiKey = 'AIzaSyD6Arqm1ECATHxiA0aUTFNgCe_WHlU5N-4';
const password = 'Welcome@123';
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

const accounts = {
  manager: {
    email: 'manager@ezq-demo.cubiquitous.in',
    displayName: 'The Spice House Manager',
    phone: '+919999000111',
  },
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
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map((item) => firestoreValue(item)) } };
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

const managerAuth = await createOrSignInUser(accounts.manager);

await patchDocument(`restaurants/the-spice-house/admins/${managerAuth.localId}`, {
  uid: managerAuth.localId,
  name: accounts.manager.displayName,
  email: accounts.manager.email,
  phone: accounts.manager.phone,
  role: 'manager',
  branchIds: ['indiranagar'],
  isActive: true,
  createdAt: new Date().toISOString(),
});

console.log(
  JSON.stringify(
    {
      restaurantId: 'the-spice-house',
      branchId: 'indiranagar',
      password,
      manager: {
        email: accounts.manager.email,
        uid: managerAuth.localId,
        role: 'manager',
      },
    },
    null,
    2,
  ),
);
