const projectId = process.env.GCLOUD_PROJECT ?? 'ezq-dev-cubiquitous';
const branchId = 'biryani-bay-domlur-edge';
const email = 'biryani.bay.admin@ezq-demo.cubiquitous.in';
const password = 'Welcome@123';

const signup = await fetch(
  'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/' +
    'accounts:signUp?key=emulator-key',
  {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  },
);
if (!signup.ok) throw new Error(`Auth seed failed: ${await signup.text()}`);
const { localId: uid } = await signup.json();

function value(input) {
  if (typeof input === 'string') return { stringValue: input };
  if (typeof input === 'boolean') return { booleanValue: input };
  if (Number.isInteger(input)) return { integerValue: String(input) };
  if (Array.isArray(input)) {
    return { arrayValue: { values: input.map(value) } };
  }
  return { timestampValue: input.toISOString() };
}

function write(path, data) {
  return {
    update: {
      name:
        `projects/${projectId}/databases/(default)/documents/${path}`,
      fields: Object.fromEntries(
        Object.entries(data).map(([key, item]) => [key, value(item)]),
      ),
    },
  };
}

const now = new Date();
const response = await fetch(
  `http://127.0.0.1:8080/v1/projects/${projectId}/` +
    'databases/(default)/documents:commit',
  {
    method: 'POST',
    headers: {
      authorization: 'Bearer owner',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      writes: [
        write(`restaurantBranches/${branchId}`, {
          id: branchId,
          slug: branchId,
          restaurantName: 'Biryani Bay',
          branchName: 'Domlur Edge',
          area: 'Domlur',
          address: 'Domlur Edge, Bengaluru',
          isActive: true,
          onboardingCompleted: false,
          provisioningStatus: 'pending',
          floorCount: 0,
          totalTables: 0,
          totalSeats: 0,
          capacityTypes: [],
          qrEnabled: false,
          createdAt: now,
          updatedAt: now,
        }),
        write(`admins/${uid}`, {
          uid,
          name: 'Biryani Bay Admin',
          email,
          phone: '+919999000222',
          restaurantBranchId: branchId,
          role: 'owner',
          isActive: true,
          onboardingCompleted: false,
          createdAt: now,
          updatedAt: now,
        }),
      ],
    }),
  },
);
if (!response.ok) {
  throw new Error(`Firestore seed failed: ${await response.text()}`);
}
console.log(
  JSON.stringify({ uid, branchId, phone: '+919999000222' }),
);
