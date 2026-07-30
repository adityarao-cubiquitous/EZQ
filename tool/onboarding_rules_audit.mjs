import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';

const require = createRequire(
  new URL('../functions/package.json', import.meta.url),
);
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  writeBatch,
} = require('firebase/firestore');

const projectId = process.env.GCLOUD_PROJECT ?? 'ezq-dev-cubiquitous';
const [host, portText] = (
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080'
).split(':');
const rules = await readFile(
  new URL('../firestore.rules', import.meta.url),
  'utf8',
);
const testEnvironment = await initializeTestEnvironment({
  projectId,
  firestore: {
    host,
    port: Number(portText),
    rules,
  },
});

function pendingBranch(branchId) {
  return {
    id: branchId,
    slug: branchId,
    restaurantName: 'Rules Audit Restaurant',
    branchName: 'Main',
    area: 'Indiranagar',
    address: '12th Main',
    isActive: true,
    onboardingCompleted: false,
    provisioningStatus: 'pending',
    floorCount: 0,
    totalTables: 0,
    totalSeats: 0,
    capacityTypes: [],
    updatedAt: new Date(),
  };
}

function admin(uid, branchId, { isActive = true } = {}) {
  return {
    uid,
    name: 'Rules Audit Admin',
    email: `${uid}@example.test`,
    phone: '+919999000000',
    restaurantBranchId: branchId,
    role: 'owner',
    isActive,
    onboardingCompleted: false,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

async function seed(uid, branchId, options = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(
      doc(firestore, 'restaurantBranches', branchId),
      pendingBranch(branchId),
    );
    if (!options.deletedAdmin) {
      await setDoc(
        doc(firestore, 'admins', uid),
        admin(uid, branchId, options),
      );
    }
  });
}

function provisioningBatch(firestore, uid, branchId) {
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'restaurantBranches', branchId), {
    ...pendingBranch(branchId),
    onboardingCompleted: true,
    provisioningStatus: 'completed',
    onboardingCompletedAt: new Date(),
    provisioningFingerprint: `v1|${branchId}|1|4|2|2|8`,
    qrEnabled: true,
    qrSlug: branchId,
    queueUrl: `https://example.test/customer/${branchId}`,
    qrPngLocalPath: `assets/qr/${branchId}/${branchId}.png`,
    qrSvgLocalPath: `assets/qr/${branchId}/${branchId}.svg`,
    floorCount: 1,
    totalTables: 2,
    totalSeats: 8,
    capacityTypes: [4],
  });
  batch.set(doc(firestore, 'restaurantBranches', branchId, 'floors', 'F1'), {
    floorId: 'F1',
    floorName: 'Floor 1',
    displayOrder: 1,
    tableCount: 2,
    seatCount: 8,
  });
  for (const tableId of ['T1', 'T2']) {
    batch.set(
      doc(firestore, 'restaurantBranches', branchId, 'tables', tableId),
      {
        tableId,
        tableNumber: tableId,
        floorId: 'F1',
        capacity: 4,
        status: 'available',
      },
    );
  }
  batch.set(
    doc(firestore, 'restaurantBranches', branchId, 'settings', 'general'),
    {
      averageDiningMinutes: 35,
      averageCleaningMinutes: 5,
      reservationHoldMinutes: 5,
    },
  );
  batch.update(doc(firestore, 'admins', uid), {
    onboardingCompleted: true,
    onboardedAt: new Date(),
  });
  return batch;
}

async function assertNoPartialData(branchId) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const branch = await getDoc(
      doc(firestore, 'restaurantBranches', branchId),
    );
    const floor = await getDoc(
      doc(firestore, 'restaurantBranches', branchId, 'floors', 'F1'),
    );
    if (branch.data()?.onboardingCompleted !== false || floor.exists()) {
      throw new Error('Rejected batch left partial provisioning data.');
    }
  });
}

async function rejectedScenario({
  name,
  uid,
  branchId,
  actingUid,
  seedOptions,
  unauthenticated = false,
}) {
  await seed(uid, branchId, seedOptions);
  const context = unauthenticated
    ? testEnvironment.unauthenticatedContext()
    : testEnvironment.authenticatedContext(actingUid ?? uid, {
        email: `${actingUid ?? uid}@example.test`,
        firebase: { sign_in_provider: 'password' },
      });
  await assertFails(
    provisioningBatch(context.firestore(), actingUid ?? uid, branchId).commit(),
  );
  await assertNoPartialData(branchId);
  console.log(`PASS rejected ${name}, atomic rollback confirmed`);
}

try {
  const validUid = 'rules-valid-admin';
  const validBranch = 'rules-valid-branch';
  await seed(validUid, validBranch);
  const validContext = testEnvironment.authenticatedContext(validUid, {
    email: `${validUid}@example.test`,
    firebase: { sign_in_provider: 'password' },
  });
  await assertSucceeds(
    provisioningBatch(
      validContext.firestore(),
      validUid,
      validBranch,
    ).commit(),
  );
  console.log('PASS valid assigned active admin provisioning');

  await assertFails(
    provisioningBatch(
      validContext.firestore(),
      validUid,
      validBranch,
    ).commit(),
  );
  console.log('PASS completed onboarding is immutable');

  await rejectedScenario({
    name: 'wrong UID',
    uid: 'rules-owner-admin',
    actingUid: 'rules-intruder',
    branchId: 'rules-wrong-uid-branch',
  });

  const mappedUid = 'rules-mapped-admin';
  await seed(mappedUid, 'rules-mapped-branch');
  await rejectedScenario({
    name: 'wrong restaurant/branch mapping',
    uid: 'rules-foreign-admin',
    actingUid: mappedUid,
    branchId: 'rules-foreign-branch',
  });

  await rejectedScenario({
    name: 'inactive admin',
    uid: 'rules-inactive-admin',
    branchId: 'rules-inactive-branch',
    seedOptions: { isActive: false },
  });

  await rejectedScenario({
    name: 'deleted admin',
    uid: 'rules-deleted-admin',
    branchId: 'rules-deleted-branch',
    seedOptions: { deletedAdmin: true },
  });

  await rejectedScenario({
    name: 'anonymous user',
    uid: 'rules-anonymous-admin',
    branchId: 'rules-anonymous-branch',
    unauthenticated: true,
  });

  // Firebase Auth rejects an expired ID token before Firestore rules execute;
  // Firestore receives the same unauthenticated context asserted here.
  await rejectedScenario({
    name: 'expired authentication (request.auth == null)',
    uid: 'rules-expired-admin',
    branchId: 'rules-expired-branch',
    unauthenticated: true,
  });

  console.log('Onboarding Firestore security audit passed.');
} finally {
  await testEnvironment.cleanup();
}
