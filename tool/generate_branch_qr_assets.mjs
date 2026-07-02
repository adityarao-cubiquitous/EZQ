import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { request } from 'node:https';
import { homedir } from 'node:os';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const require = createRequire(import.meta.url);
const QRCode = require('qrcode');
const execFileAsync = promisify(execFile);

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const hostingOrigin =
  process.env.EZQ_HOSTING_ORIGIN ?? 'https://ezq-dev-cubiquitous.web.app';
const assetMode = process.env.EZQ_QR_ASSET_MODE ?? 'local';
const localQrOutputDir = process.env.EZQ_QR_OUTPUT_DIR ?? 'assets/qr';
const driveExportDir = process.env.EZQ_QR_DRIVE_EXPORT_DIR ?? 'drive_export';
const qrBundlePath = process.env.EZQ_QR_BUNDLE_PATH ?? 'qr_bundle.zip';
const storageBucket =
  process.env.EZQ_STORAGE_BUCKET ?? `${projectId}.firebasestorage.app`;
const storageLocation = process.env.EZQ_STORAGE_LOCATION ?? 'ASIA-SOUTH1';
const configPath = `${homedir()}/.config/configstore/firebase-tools.json`;
const firebaseToolsConfig = JSON.parse(await readFile(configPath, 'utf8'));
const refreshToken = firebaseToolsConfig.tokens?.refresh_token;
let accessToken = firebaseToolsConfig.tokens?.access_token;

if (!accessToken && !refreshToken) {
  throw new Error('No Firebase CLI access token found. Run firebase login first.');
}

async function refreshAccessToken() {
  if (!refreshToken) return accessToken;
  const body = new URLSearchParams({
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  return new Promise((resolve, reject) => {
    const req = request(
      {
        hostname: 'oauth2.googleapis.com',
        method: 'POST',
        path: '/token',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
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
            resolve(JSON.parse(response).access_token);
            return;
          }
          reject(new Error(`Failed to refresh Firebase token: ${response}`));
        });
      },
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
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

async function patchDocument(path, data, deleteFields = []) {
  const mask = [...new Set([...Object.keys(data), ...deleteFields])]
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
    return slugify(branch.pathBranchId);
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
  constructor({ bucket, location, outputDir }) {
    this.bucket = bucket;
    this.location = location;
    this.outputDir = outputDir;
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
    await patchDocument(path, metadata, ['branchId', 'branchSlug']);
  }

  async saveLocalAsset({ restaurantId, branchSlug, extension, body }) {
    const restaurantDir = path.join(this.outputDir, restaurantId, branchSlug);
    await mkdir(restaurantDir, { recursive: true });
    const relativePath = path
      .join(this.outputDir, restaurantId, branchSlug, `${branchSlug}.${extension}`)
      .replaceAll(path.sep, '/');
    await writeFile(relativePath, body);
    return {
      localPath: relativePath,
      downloadUrl: relativePath,
    };
  }

  async saveLocalDistributionIndex({ assets }) {
    await mkdir(this.outputDir, { recursive: true });
    const manifestPath = path.join(this.outputDir, 'manifest.json');
    const indexPath = path.join(this.outputDir, 'index.html');
    await writeFile(
      manifestPath,
      `${JSON.stringify({ generatedAt: new Date().toISOString(), assets }, null, 2)}\n`,
    );
    await writeFile(indexPath, printIndexHtml(assets));
    return {
      manifestPath: manifestPath.replaceAll(path.sep, '/'),
      indexPath: indexPath.replaceAll(path.sep, '/'),
    };
  }

  async saveDriveExport({ assets, exportDir }) {
    await rm(exportDir, { recursive: true, force: true });
    for (const asset of assets) {
      const restaurantDir = path.join(exportDir, asset.restaurantId);
      await mkdir(restaurantDir, { recursive: true });
      await copyFile(
        asset.pngPath,
        path.join(restaurantDir, `${asset.branchSlug}.png`),
      );
      await copyFile(
        asset.svgPath,
        path.join(restaurantDir, `${asset.branchSlug}.svg`),
      );
    }
  }

  async saveZipBundle({ bundlePath, sourceDirs }) {
    await rm(bundlePath, { force: true });
    await execFileAsync('zip', ['-qr', bundlePath, ...sourceDirs]);
    return bundlePath;
  }
}

function printIndexHtml(assets) {
  const cards = assets
    .map(
      (asset) => `
      <article class="qr-card">
        <h2>${escapeHtml(asset.restaurantName)}</h2>
        <p>${escapeHtml(asset.branchName)} · ${escapeHtml(asset.branchSlug)}</p>
        <img src="${relativeFromQrRoot(asset.pngPath)}" alt="${escapeHtml(asset.qrSlug)} QR code">
        <code>${escapeHtml(asset.queueUrl)}</code>
        <div class="actions">
          <a href="${relativeFromQrRoot(asset.pngPath)}" download>Download PNG</a>
          <a href="${relativeFromQrRoot(asset.svgPath)}" download>Download SVG</a>
        </div>
      </article>`,
    )
    .join('\n');

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>EZQ QR Assets</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 24px; color: #123; }
    header { margin-bottom: 24px; }
    main { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 18px; }
    .qr-card { break-inside: avoid; border: 1px solid #D8E3E5; border-radius: 8px; padding: 16px; }
    h1, h2, p { margin: 0; }
    h1 { font-size: 24px; }
    h2 { font-size: 18px; margin-bottom: 4px; }
    p { color: #52666B; margin-bottom: 12px; }
    img { width: 100%; max-width: 260px; display: block; margin: 0 auto 12px; }
    code { display: block; font-size: 12px; white-space: normal; overflow-wrap: anywhere; }
    .actions { display: flex; gap: 10px; margin-top: 12px; }
    a { color: #006B72; font-weight: 700; }
    @media print {
      body { margin: 8mm; }
      .actions { display: none; }
      .qr-card { page-break-inside: avoid; }
    }
  </style>
</head>
<body>
  <header>
    <h1>EZQ QR Assets</h1>
  </header>
  <main>${cards}
  </main>
</body>
</html>
`;
}

function relativeFromQrRoot(filePath) {
  return filePath.replace(/^assets\/qr\//, '');
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
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
      branches.push({
        restaurantId,
        restaurantName:
          branchData.restaurantName ??
          restaurantData.brandName ??
          restaurantData.name ??
          restaurantId,
        pathBranchId,
        branchSlug: pathBranchId,
        path: `restaurants/${restaurantId}/branches/${pathBranchId}`,
        data: branchData,
      });
    }
  }

  return branches;
}

async function main() {
  accessToken = await refreshAccessToken();
  const branches = await loadBranches();
  const queueUrlGenerator = new QueueUrlGenerator({ origin: hostingOrigin });
  const qrService = new QrService({
    bucket: storageBucket,
    location: storageLocation,
    outputDir: localQrOutputDir,
  });
  if (assetMode === 'storage') {
    await qrService.ensureBucket();
  } else {
    await Promise.all([
      rm(localQrOutputDir, { recursive: true, force: true }),
      rm(driveExportDir, { recursive: true, force: true }),
      rm(qrBundlePath, { force: true }),
    ]);
  }

  queueUrlGenerator.assignBranchSlugs(branches);
  for (const branch of branches) {
    branch.queueUrl = queueUrlGenerator.generateQueueUrl({
      restaurantId: branch.restaurantId,
      branchSlug: branch.branchSlug,
    });
  }
  queueUrlGenerator.validateUrlUniqueness(branches);

  const generatedAssets = [];

  for (const branch of branches) {
    const queueUrl = qrService.generateQueueUrl({ queueUrl: branch.queueUrl });
    const qrSlug = `${branch.restaurantId}-${branch.branchSlug}`;
    const nextQrVersion =
      Number.isInteger(branch.data.qrVersion) && branch.data.qrVersion > 0
        ? branch.data.qrVersion + 1
        : 1;
    const [png, svg] = await Promise.all([
      qrService.generateQrPng(queueUrl),
      qrService.generateQrSvg(queueUrl),
    ]);
    const [pngAsset, svgAsset] =
      assetMode === 'storage'
        ? await Promise.all([
            qrService.uploadToStorage({
              objectName: `qr-codes/${qrSlug}.png`,
              contentType: 'image/png',
              body: png,
            }),
            qrService.uploadToStorage({
              objectName: `qr-codes/${qrSlug}.svg`,
              contentType: 'image/svg+xml',
              body: svg,
            }),
          ])
        : await Promise.all([
            qrService.saveLocalAsset({
              restaurantId: branch.restaurantId,
              branchSlug: branch.branchSlug,
              extension: 'png',
              body: png,
            }),
            qrService.saveLocalAsset({
              restaurantId: branch.restaurantId,
              branchSlug: branch.branchSlug,
              extension: 'svg',
              body: svg,
            }),
          ]);
    const generatedAt = new Date().toISOString();
    const metadata = {
      restaurantId: branch.restaurantId,
      restaurantName: branch.restaurantName,
      qrSlug,
      queueUrl,
      qrImageUrl: pngAsset.downloadUrl,
      qrPngUrl: pngAsset.downloadUrl,
      qrSvgUrl: svgAsset.downloadUrl,
      qrPngStoragePath: pngAsset.storagePath ?? null,
      qrSvgStoragePath: svgAsset.storagePath ?? null,
      qrPngLocalPath: pngAsset.localPath ?? null,
      qrSvgLocalPath: svgAsset.localPath ?? null,
      qrGeneratedAt: generatedAt,
      qrVersion: nextQrVersion,
      qrAssetMode: assetMode,
      qrCode: {
        queueUrl,
        pngUrl: pngAsset.downloadUrl,
        svgUrl: svgAsset.downloadUrl,
        pngStoragePath: pngAsset.storagePath ?? null,
        svgStoragePath: svgAsset.storagePath ?? null,
        pngLocalPath: pngAsset.localPath ?? null,
        svgLocalPath: svgAsset.localPath ?? null,
        generatedAt,
        version: nextQrVersion,
        assetMode,
      },
      updatedAt: generatedAt,
    };

    await qrService.saveQrMetadata({
      path: branch.path,
      metadata,
    });

    generatedAssets.push({
      restaurantId: branch.restaurantId,
      restaurantName: branch.restaurantName,
      branchSlug: branch.branchSlug,
      branchName: branch.data.name ?? branch.branchSlug,
      qrSlug,
      queueUrl,
      qrVersion: nextQrVersion,
      pngPath: pngAsset.localPath ?? pngAsset.storagePath,
      svgPath: svgAsset.localPath ?? svgAsset.storagePath,
    });
    console.log(`Generated QR assets for ${branch.path}: ${queueUrl}`);
  }

  if (assetMode === 'local') {
    const distribution = await qrService.saveLocalDistributionIndex({
      assets: generatedAssets,
    });
    await qrService.saveDriveExport({
      assets: generatedAssets,
      exportDir: driveExportDir,
    });
    const bundlePath = await qrService.saveZipBundle({
      bundlePath: qrBundlePath,
      sourceDirs: [localQrOutputDir, driveExportDir],
    });
    console.log(
      `Wrote local QR manifest ${distribution.manifestPath} and print index ${distribution.indexPath}`,
    );
    console.log(`Wrote Drive-ready export ${driveExportDir}`);
    console.log(`Wrote QR bundle ${bundlePath}`);
  }

  console.log(`Generated ${assetMode} QR assets for ${branches.length} branches.`);
}

await main();
