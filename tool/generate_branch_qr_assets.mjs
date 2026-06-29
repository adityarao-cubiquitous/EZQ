import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { request } from 'node:https';
import { homedir } from 'node:os';
import { randomUUID } from 'node:crypto';

const require = createRequire(import.meta.url);
const QRCode = require('qrcode');

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const hostingOrigin =
  process.env.EZQ_HOSTING_ORIGIN ?? 'https://ezq-dev-cubiquitous.web.app';
const storageBucket =
  process.env.EZQ_STORAGE_BUCKET ?? `${projectId}.firebasestorage.app`;
const storageLocation = process.env.EZQ_STORAGE_LOCATION ?? 'ASIA-SOUTH1';
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

function slugify(value) {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

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

function parseFirestoreValue(value) {
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('stringValue' in value) return value.stringValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(parseFirestoreValue);
  }
  if ('mapValue' in value) {
    return parseFirestoreFields(value.mapValue.fields ?? {});
  }
  return undefined;
}

function parseFirestoreFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, parseFirestoreValue(value)]),
  );
}

function toFirestoreDocument(data) {
  return {
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

function documentId(documentName) {
  return documentName.split('/').pop();
}

function jsonRequest({ hostname, method, path, body, headers = {} }) {
  const payload = body === undefined ? undefined : JSON.stringify(body);

  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname,
        method,
        path,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          ...headers,
          ...(payload === undefined
            ? {}
            : {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }),
        },
      },
      (res) => {
        let response = '';
        res.on('data', (chunk) => {
          response += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(response === '' ? {} : JSON.parse(response));
            return;
          }
          reject(new Error(`${method} ${path}: ${res.statusCode} ${response}`));
        });
      },
    );

    req.on('error', reject);
    if (payload !== undefined) req.write(payload);
    req.end();
  });
}

function rawRequest({ hostname, method, path, body, headers }) {
  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname,
        method,
        path,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          ...headers,
          'Content-Length': body.length,
        },
      },
      (res) => {
        let response = '';
        res.on('data', (chunk) => {
          response += chunk;
        });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(response === '' ? {} : JSON.parse(response));
            return;
          }
          reject(new Error(`${method} ${path}: ${res.statusCode} ${response}`));
        });
      },
    );

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function firestoreRequest(method, path, body) {
  return jsonRequest({
    hostname: 'firestore.googleapis.com',
    method,
    path,
    body,
  });
}

async function listCollection(collectionPath) {
  const documents = [];
  let pageToken;

  do {
    const query = new URLSearchParams({ pageSize: '300' });
    if (pageToken) query.set('pageToken', pageToken);
    const path =
      `/v1/projects/${projectId}/databases/(default)/documents/${collectionPath}` +
      `?${query.toString()}`;
    const response = await firestoreRequest('GET', path);
    documents.push(...(response.documents ?? []));
    pageToken = response.nextPageToken;
  } while (pageToken);

  return documents;
}

async function patchDocument(path, data) {
  const mask = Object.keys(data)
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${projectId}/databases/(default)/documents/${path}?${mask}`,
    toFirestoreDocument(data),
  );
}

class QueueUrlGenerator {
  constructor({ origin }) {
    this.origin = origin.replace(/\/+$/, '');
  }

  baseBranchSlug(branch) {
    const existing = branch.data.branchSlug;
    if (typeof existing === 'string' && existing.trim().length > 0) {
      return slugify(existing);
    }
    return (
      slugify(branch.data.name) ||
      slugify(branch.pathBranchId.replace(`${branch.restaurantId}-`, '')) ||
      slugify(branch.pathBranchId)
    );
  }

  assignBranchSlugs(branches) {
    const branchesByRestaurant = Map.groupBy(
      branches,
      (branch) => branch.restaurantId,
    );

    for (const restaurantBranches of branchesByRestaurant.values()) {
      const counts = new Map();
      for (const branch of restaurantBranches) {
        const baseSlug = this.baseBranchSlug(branch);
        counts.set(baseSlug, (counts.get(baseSlug) ?? 0) + 1);
      }

      const used = new Set();
      for (const branch of restaurantBranches) {
        const baseSlug = this.baseBranchSlug(branch);
        let branchSlug = baseSlug;
        if (counts.get(baseSlug) > 1) {
          branchSlug = slugify(`${baseSlug}-${branch.pathBranchId}`);
        }
        while (used.has(branchSlug)) {
          branchSlug = slugify(`${baseSlug}-${branch.pathBranchId}-${used.size + 1}`);
        }
        used.add(branchSlug);
        branch.branchSlug = branchSlug;
      }
    }
  }

  generateQueueUrl({ restaurantId, branchSlug }) {
    return `${this.origin}/customer/${restaurantId}/${branchSlug}`;
  }

  validateUrlUniqueness(branches) {
    const seen = new Map();
    const duplicates = [];
    for (const branch of branches) {
      const queueUrl = branch.queueUrl;
      if (seen.has(queueUrl)) {
        duplicates.push(`${queueUrl}: ${seen.get(queueUrl)} and ${branch.path}`);
      } else {
        seen.set(queueUrl, branch.path);
      }
    }
    if (duplicates.length > 0) {
      throw new Error(`Duplicate queueUrl values found:\n${duplicates.join('\n')}`);
    }
  }
}

class QrService {
  constructor({ bucket, location }) {
    this.bucket = bucket;
    this.location = location;
  }

  generateQueueUrl({ queueUrl }) {
    return queueUrl;
  }

  async generateQrPng(queueUrl) {
    return QRCode.toBuffer(queueUrl, {
      type: 'png',
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 960,
      color: {
        dark: '#043C3D',
        light: '#FFFFFF',
      },
    });
  }

  async generateQrSvg(queueUrl) {
    return QRCode.toString(queueUrl, {
      type: 'svg',
      errorCorrectionLevel: 'M',
      margin: 2,
      color: {
        dark: '#043C3D',
        light: '#FFFFFF',
      },
    });
  }

  async uploadToStorage({ objectName, contentType, body }) {
    const token = randomUUID();
    const metadata = {
      name: objectName,
      contentType,
      cacheControl: 'public, max-age=3600',
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    };
    const boundary = `ezq-qr-${randomUUID()}`;
    const multipartBody = Buffer.concat([
      Buffer.from(
        `--${boundary}\r\n` +
          'Content-Type: application/json; charset=UTF-8\r\n\r\n' +
          `${JSON.stringify(metadata)}\r\n` +
          `--${boundary}\r\n` +
          `Content-Type: ${contentType}\r\n\r\n`,
      ),
      Buffer.isBuffer(body) ? body : Buffer.from(body),
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]);

    await rawRequest({
      hostname: 'storage.googleapis.com',
      method: 'POST',
      path:
        `/upload/storage/v1/b/${encodeURIComponent(this.bucket)}/o` +
        `?uploadType=multipart&name=${encodeURIComponent(objectName)}`,
      headers: {
        'Content-Type': `multipart/related; boundary=${boundary}`,
      },
      body: multipartBody,
    });

    return {
      storagePath: objectName,
      downloadUrl:
        `https://firebasestorage.googleapis.com/v0/b/${this.bucket}/o/` +
        `${encodeURIComponent(objectName)}?alt=media&token=${token}`,
    };
  }

  async ensureBucket() {
    try {
      await jsonRequest({
        hostname: 'storage.googleapis.com',
        method: 'GET',
        path: `/storage/v1/b/${encodeURIComponent(this.bucket)}`,
      });
      return;
    } catch (error) {
      if (!String(error.message).includes(' 404 ')) {
        throw error;
      }
    }

    await jsonRequest({
      hostname: 'storage.googleapis.com',
      method: 'POST',
      path: `/storage/v1/b?project=${encodeURIComponent(projectId)}`,
      body: {
        name: this.bucket,
        location: this.location,
        iamConfiguration: {
          uniformBucketLevelAccess: {
            enabled: true,
          },
        },
      },
    });
    console.log(`Created Storage bucket ${this.bucket} in ${this.location}`);
  }

  async saveQrMetadata({ path, metadata }) {
    await patchDocument(path, metadata);
  }
}

async function loadBranches() {
  const restaurantDocs = await listCollection('restaurants');
  const branches = [];

  for (const restaurantDoc of restaurantDocs) {
    const restaurantId = documentId(restaurantDoc.name);
    const restaurantData = parseFirestoreFields(restaurantDoc.fields);
    const branchDocs = await listCollection(`restaurants/${restaurantId}/branches`);

    for (const branchDoc of branchDocs) {
      const pathBranchId = documentId(branchDoc.name);
      const branchData = parseFirestoreFields(branchDoc.fields);
      const branchId = branchData.branchId ?? pathBranchId;
      branches.push({
        restaurantId,
        restaurantName:
          branchData.restaurantName ??
          restaurantData.brandName ??
          restaurantData.name ??
          restaurantId,
        pathBranchId,
        branchId,
        path: `restaurants/${restaurantId}/branches/${pathBranchId}`,
        data: branchData,
      });
    }
  }

  return branches;
}

async function main() {
  const branches = await loadBranches();
  const queueUrlGenerator = new QueueUrlGenerator({ origin: hostingOrigin });
  const qrService = new QrService({
    bucket: storageBucket,
    location: storageLocation,
  });
  await qrService.ensureBucket();

  queueUrlGenerator.assignBranchSlugs(branches);
  for (const branch of branches) {
    branch.queueUrl = queueUrlGenerator.generateQueueUrl({
      restaurantId: branch.restaurantId,
      branchSlug: branch.branchSlug,
    });
  }
  queueUrlGenerator.validateUrlUniqueness(branches);

  for (const branch of branches) {
    const queueUrl = qrService.generateQueueUrl({ queueUrl: branch.queueUrl });
    const qrSlug = `${branch.restaurantId}-${branch.branchSlug}`;
    const pngPath = `qr-codes/${qrSlug}.png`;
    const svgPath = `qr-codes/${qrSlug}.svg`;
    const [png, svg] = await Promise.all([
      qrService.generateQrPng(queueUrl),
      qrService.generateQrSvg(queueUrl),
    ]);
    const [pngUpload, svgUpload] = await Promise.all([
      qrService.uploadToStorage({
        objectName: pngPath,
        contentType: 'image/png',
        body: png,
      }),
      qrService.uploadToStorage({
        objectName: svgPath,
        contentType: 'image/svg+xml',
        body: svg,
      }),
    ]);
    const generatedAt = new Date().toISOString();

    await qrService.saveQrMetadata({
      path: branch.path,
      metadata: {
        restaurantId: branch.restaurantId,
        restaurantName: branch.restaurantName,
        branchId: branch.branchId,
        branchSlug: branch.branchSlug,
        qrSlug,
        queueUrl,
        qrImageUrl: pngUpload.downloadUrl,
        qrPngUrl: pngUpload.downloadUrl,
        qrSvgUrl: svgUpload.downloadUrl,
        qrPngStoragePath: pngUpload.storagePath,
        qrSvgStoragePath: svgUpload.storagePath,
        qrGeneratedAt: generatedAt,
        qrCode: {
          queueUrl,
          pngUrl: pngUpload.downloadUrl,
          svgUrl: svgUpload.downloadUrl,
          pngStoragePath: pngUpload.storagePath,
          svgStoragePath: svgUpload.storagePath,
          generatedAt,
        },
        updatedAt: generatedAt,
      },
    });

    console.log(`Generated QR assets for ${branch.path}: ${queueUrl}`);
  }

  console.log(`Generated QR assets for ${branches.length} branches.`);
}

await main();
