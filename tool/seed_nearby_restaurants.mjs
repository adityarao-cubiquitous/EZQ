import { readFile } from 'node:fs/promises';
import { request } from 'node:https';
import { homedir } from 'node:os';

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

const now = new Date().toISOString();

const restaurants = [
  {
    id: 'the-spice-house',
    name: 'The Spice House',
    cuisine: 'Modern Indian',
    branchId: 'indiranagar',
    branchName: 'Indiranagar',
    area: 'Indiranagar',
    address: '100 Feet Road, Indiranagar, Bengaluru',
    latitude: 12.9784,
    longitude: 77.6408,
  },
  {
    id: 'cubbon-curry',
    name: 'Cubbon Curry',
    cuisine: 'South Indian',
    branchId: 'cubbon-curry-indiranagar',
    branchName: 'Indiranagar',
    area: 'Indiranagar',
    address: '12th Main Road, Indiranagar, Bengaluru',
    latitude: 12.979,
    longitude: 77.6418,
  },
  {
    id: 'noodle-yard',
    name: 'Noodle Yard',
    cuisine: 'Asian',
    branchId: 'noodle-yard-indiranagar',
    branchName: 'Indiranagar',
    area: 'Indiranagar',
    address: 'CMH Road, Indiranagar, Bengaluru',
    latitude: 12.9769,
    longitude: 77.6387,
  },
  {
    id: 'taco-tawa',
    name: 'Taco Tawa',
    cuisine: 'Mexican-Indian',
    branchId: 'taco-tawa-indiranagar',
    branchName: 'Indiranagar',
    area: 'Indiranagar',
    address: '80 Feet Road, Indiranagar, Bengaluru',
    latitude: 12.9758,
    longitude: 77.6432,
  },
  {
    id: 'dosa-lab',
    name: 'Dosa Lab',
    cuisine: 'Modern South Indian',
    branchId: 'dosa-lab-indiranagar',
    branchName: 'Indiranagar',
    area: 'Indiranagar',
    address: 'Defence Colony, Indiranagar, Bengaluru',
    latitude: 12.9821,
    longitude: 77.6395,
  },
  {
    id: 'pasta-pepper',
    name: 'Pasta Pepper',
    cuisine: 'Italian',
    branchId: 'hal-2nd-stage',
    branchName: 'HAL 2nd Stage',
    area: 'HAL 2nd Stage',
    address: 'Double Road, HAL 2nd Stage, Bengaluru',
    latitude: 12.9812,
    longitude: 77.647,
  },
  {
    id: 'biryani-bay',
    name: 'Biryani Bay',
    cuisine: 'Hyderabadi',
    branchId: 'domlur-edge',
    branchName: 'Domlur Edge',
    area: 'Domlur',
    address: 'Domlur Service Road, Bengaluru',
    latitude: 12.9719,
    longitude: 77.6415,
  },
  {
    id: 'momo-mill',
    name: 'Momo Mill',
    cuisine: 'Tibetan',
    branchId: 'indiranagar-metro',
    branchName: 'Indiranagar Metro',
    area: 'Indiranagar',
    address: 'Near Indiranagar Metro Station, Bengaluru',
    latitude: 12.9788,
    longitude: 77.6364,
  },
  {
    id: 'salad-studio',
    name: 'Salad Studio',
    cuisine: 'Healthy Bowls',
    branchId: '12th-main',
    branchName: '12th Main',
    area: 'Indiranagar',
    address: '12th Main, Indiranagar, Bengaluru',
    latitude: 12.9709,
    longitude: 77.645,
  },
  {
    id: 'grill-garden',
    name: 'Grill Garden',
    cuisine: 'Barbecue',
    branchId: 'old-airport-road',
    branchName: 'Old Airport Road',
    area: 'Old Airport Road',
    address: 'Old Airport Road, Bengaluru',
    latitude: 12.9649,
    longitude: 77.6407,
  },
];

const documents = Object.fromEntries(
  restaurants.flatMap((restaurant) => [
    [
      `restaurants/${restaurant.id}`,
      {
        name: restaurant.name,
        brandName: restaurant.name,
        cuisine: restaurant.cuisine,
        city: 'Bengaluru',
        contactPhone: '+919900000000',
        isActive: true,
        signedUp: true,
        logoUrl: null,
        createdAt: now,
        updatedAt: now,
      },
    ],
    [
      `restaurants/${restaurant.id}/branches/${restaurant.branchId}`,
      {
        restaurantId: restaurant.id,
        restaurantName: restaurant.name,
        branchId: restaurant.branchId,
        branchSlug: restaurant.branchName
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/^-+|-+$/g, ''),
        name: restaurant.branchName,
        area: restaurant.area,
        address: restaurant.address,
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        qrSlug: `${restaurant.id}-${restaurant.branchName
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/^-+|-+$/g, '')}`,
        queueUrl:
          `https://ezq-dev-cubiquitous.web.app/customer/` +
          `${restaurant.id}/${restaurant.branchName
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-+|-+$/g, '')}`,
        qrImageUrl:
          `https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/` +
          `qr-codes/${restaurant.id}-${restaurant.branchName
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-+|-+$/g, '')}.png`,
        qrSvgUrl:
          `https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/` +
          `qr-codes/${restaurant.id}-${restaurant.branchName
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-+|-+$/g, '')}.svg`,
        isActive: true,
        signedUp: true,
        cuisine: restaurant.cuisine,
        logoUrl: null,
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
        averageDiningMinutes: 35,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        averageTurnoverMinutes: 40,
        menuPdfUrl: '/demo-menu.pdf',
        menuPreviewImageUrl: '/demo-menu-page-1.png',
        createdAt: now,
        updatedAt: now,
      },
    ],
  ]),
);

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
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

function toFirestoreDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function patchDocument(path, data) {
  const body = JSON.stringify(toFirestoreDocument(data));
  const requestPath = `/v1/projects/${projectId}/databases/(default)/documents/${path}`;

  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname: 'firestore.googleapis.com',
        method: 'PATCH',
        path: requestPath,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let response = '';
        res.on('data', (chunk) => {
          response += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve();
            return;
          }
          reject(
            new Error(
              `Failed to write ${path}: ${res.statusCode} ${response}`,
            ),
          );
        });
      },
    );

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

for (const [path, data] of Object.entries(documents)) {
  await patchDocument(path, data);
  console.log(`Seeded ${path}`);
}

console.log(`Seeded ${restaurants.length} nearby restaurants to ${projectId}.`);
