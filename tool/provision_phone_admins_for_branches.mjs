import { createRequire } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
const admin = require('../functions/node_modules/firebase-admin');

/**
 * Provision Firebase Auth phone admins for every EZQ restaurant branch.
 *
 * Authentication priority:
 * 1. GOOGLE_APPLICATION_CREDENTIALS
 *    Set this to the absolute path of a Firebase service account JSON file.
 *    The JSON file must stay outside this repository and must never be
 *    committed.
 *
 * 2. Application Default Credentials (ADC)
 *    If GOOGLE_APPLICATION_CREDENTIALS is not set, the Firebase Admin SDK uses
 *    ADC from the local environment. This can come from
 *    `gcloud auth application-default login`, a managed runtime, or another
 *    Google-auth supported ADC source.
 *
 * Required Firebase permissions:
 * - Firestore read/write access to restaurantBranches and admins.
 * - Firebase Authentication permission to get, create, and update users.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json \
 *     node tool/provision_phone_admins_for_branches.mjs ezq-dev-cubiquitous --dry-run
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json \
 *     node tool/provision_phone_admins_for_branches.mjs ezq-dev-cubiquitous
 *
 * Dry run reads Firebase and prints the planned provisioning result. Omit
 * --dry-run only after the output looks correct.
 */

const projectId = process.argv[2] ?? 'ezq-dev-cubiquitous';
const dryRun = process.argv.includes('--dry-run');

function credentialHelp() {
  return [
    'Firebase Admin credentials are required to provision phone admins.',
    '',
    'Supported authentication methods:',
    '1. Service account JSON:',
    '   export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json',
    '   node tool/provision_phone_admins_for_branches.mjs ezq-dev-cubiquitous --dry-run',
    '',
    '2. Application Default Credentials:',
    '   gcloud auth application-default login',
    '   node tool/provision_phone_admins_for_branches.mjs ezq-dev-cubiquitous --dry-run',
    '',
    'The credential must have Firestore read/write access and Firebase Auth',
    'user get/create/update permissions for project ezq-dev-cubiquitous.',
    '',
    'Do not commit service account JSON files to this repository.',
  ].join('\n');
}

function loadServiceAccountCredential(path) {
  if (!existsSync(path)) {
    throw new Error(
      `GOOGLE_APPLICATION_CREDENTIALS points to a missing file: ${path}`,
    );
  }

  try {
    const serviceAccount = JSON.parse(readFileSync(path, 'utf8'));
    return admin.credential.cert(serviceAccount);
  } catch (error) {
    throw new Error(
      [
        `Unable to read Firebase service account JSON from: ${path}`,
        `Reason: ${error.message}`,
      ].join('\n'),
    );
  }
}

function initializeFirebaseAdmin() {
  const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
  const appOptions = { projectId };

  if (credentialPath) {
    appOptions.credential = loadServiceAccountCredential(credentialPath);
    admin.initializeApp(appOptions);
    return 'service-account-json';
  }

  appOptions.credential = admin.credential.applicationDefault();
  admin.initializeApp(appOptions);
  return 'application-default-credentials';
}

function isMissingCredentialError(error) {
  const message = String(error?.message ?? error);
  return (
    message.includes('Could not load the default credentials') ||
    message.includes('Unable to detect a Project Id') ||
    message.includes('Your default credentials were not found') ||
    message.includes('Could not refresh access token')
  );
}

function failCredentialSetup(message) {
  console.error([message, '', credentialHelp()].join('\n'));
  process.exit(1);
}

function normalizePhone(phone) {
  const value = String(phone ?? '').trim();
  const digits = value.replace(/\D/g, '');
  if (value.startsWith('+') && digits.length >= 10) return value;
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  throw new Error(`Invalid admin phone: ${phone}`);
}

let credentialSource = 'uninitialized';
if (!admin.apps.length) {
  try {
    credentialSource = initializeFirebaseAdmin();
  } catch (error) {
    failCredentialSetup(error.message);
  }
}

const db = admin.firestore();
const auth = admin.auth();

let branchSnap;
let adminSnap;
try {
  [branchSnap, adminSnap] = await Promise.all([
    db.collection('restaurantBranches').get(),
    db.collection('admins').get(),
  ]);
} catch (error) {
  if (isMissingCredentialError(error)) {
    console.error(
      [
        `Unable to authenticate with Firebase Admin SDK using ${credentialSource}.`,
        '',
        credentialHelp(),
        '',
        `Original error: ${error.message}`,
      ].join('\n'),
    );
    process.exit(1);
  }
  throw error;
}

const adminsByBranch = new Map();
for (const doc of adminSnap.docs) {
  const data = doc.data();
  const restaurantBranchId = String(data.restaurantBranchId ?? '').trim();
  if (!restaurantBranchId) continue;
  const existing = adminsByBranch.get(restaurantBranchId) ?? [];
  existing.push({ id: doc.id, ref: doc.ref, data });
  adminsByBranch.set(restaurantBranchId, existing);
}

const results = [];

for (const branchDoc of branchSnap.docs) {
  const restaurantBranchId = branchDoc.id;
  if (restaurantBranchId.startsWith('codex-rule-sync-')) {
    results.push({ restaurantBranchId, skipped: 'codex rule sync branch' });
    continue;
  }

  const existingAdmins = adminsByBranch.get(restaurantBranchId) ?? [];
  if (existingAdmins.length === 0) {
    results.push({ restaurantBranchId, skipped: 'no existing admin mapping' });
    continue;
  }

  const sourceAdmin = existingAdmins.find((entry) =>
    String(entry.data.phone ?? '').trim().isNotEmpty
  );
  if (!sourceAdmin) {
    results.push({ restaurantBranchId, skipped: 'no admin phone available' });
    continue;
  }

  const source = sourceAdmin.data;
  const phone = normalizePhone(source.phone);
  const name = String(source.name ?? '').trim();
  const email = String(source.email ?? '').trim();
  const role = String(source.role ?? 'owner').trim();
  const isActive = source.isActive !== false;

  let user;
  let createdAuthUser = false;
  if (!dryRun) {
    try {
      user = await auth.getUserByPhoneNumber(phone);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      user = await auth.createUser({
        phoneNumber: phone,
        displayName: name || undefined,
        email: email || undefined,
        disabled: !isActive,
      });
      createdAuthUser = true;
    }

    const needsAuthUpdate =
      (name && user.displayName !== name) ||
      (email && user.email !== email) ||
      user.disabled === isActive;
    if (needsAuthUpdate) {
      user = await auth.updateUser(user.uid, {
        displayName: name || user.displayName,
        email: email || user.email,
        disabled: !isActive,
      });
    }

    const canonicalAdminRef = db.collection('admins').doc(user.uid);
    await db.runTransaction(async (transaction) => {
      transaction.set(
        canonicalAdminRef,
        {
          uid: user.uid,
          name,
          phone,
          email,
          restaurantBranchId,
          role,
          isActive,
          authProvider: 'phone',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt:
            source.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
          ...(source.onboardedAt ? { onboardedAt: source.onboardedAt } : {}),
        },
        { merge: true },
      );

      for (const staleAdmin of existingAdmins) {
        if (staleAdmin.id !== user.uid) transaction.delete(staleAdmin.ref);
      }
    });
  }

  results.push({
    restaurantBranchId,
    phone,
    uid: dryRun ? '(dry-run)' : user.uid,
    createdAuthUser,
    staleAdminDocsRemoved: dryRun
      ? existingAdmins.length
      : existingAdmins.filter((entry) => entry.id !== user.uid).length,
  });
}

console.log(JSON.stringify({ projectId, dryRun, results }, null, 2));
