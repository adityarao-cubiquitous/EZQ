import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  GeoPoint,
  getFirestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const auth = getAuth();
const temporaryAdminOtp = "123456";

type QueueStatus =
  | "waiting"
  | "reserved"
  | "on_the_way"
  | "seated"
  | "skipped"
  | "cancelled"
  | "no_show"
  | "expired";

type TableStatus = "available" | "reserved" | "occupied" | "blocked";

interface JoinQueueInput {
  restaurantId: string;
  branchId: string;
  customerName: string;
  phone: string;
  partySize: number;
  notes?: string | null;
  appSource?: "web" | "android" | "ios" | "admin_walkin";
}

function assertPlatformProvisioner(uid: string | undefined, token: Record<string, unknown> | undefined) {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Platform provisioning login required");
  }
  if (token?.platformProvisioner !== true) {
    throw new HttpsError("permission-denied", "Platform provisioning access required");
  }
}

function requireString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${key} is required`);
  }
  return value.trim();
}

function optionalString(data: Record<string, unknown>, key: string): string | null {
  const value = data[key];
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${key} must be a string`);
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function optionalRecord(data: Record<string, unknown>, key: string): Record<string, unknown> | null {
  const value = data[key];
  if (value == null) return null;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${key} must be an object`);
  }
  return value as Record<string, unknown>;
}

function optionalStringArray(data: Record<string, unknown>, key: string): string[] {
  const value = data[key];
  if (value == null) return [];
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new HttpsError("invalid-argument", `${key} must be an array of strings`);
  }
  const items = value
    .map((item) => (item as string).trim())
    .filter((item) => item.length > 0);
  return items;
}

function assignedTableIds(queueSnapshot: {get(field: string): unknown}): string[] {
  const storedIds = queueSnapshot.get("assignedTableIds");
  if (Array.isArray(storedIds)) {
    const ids = storedIds
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    if (ids.length > 0) return [...new Set(ids)];
  }
  const singleId = queueSnapshot.get("assignedTableId");
  return typeof singleId === "string" && singleId.trim().length > 0 ?
    [singleId.trim()] :
    [];
}

function isEmptyTableOnlyPreference(customerPreferences: unknown): boolean {
  if (
    customerPreferences == null ||
    typeof customerPreferences !== "object" ||
    Array.isArray(customerPreferences)
  ) {
    return false;
  }
  return (
    (customerPreferences as Record<string, unknown>).seatingPreference ===
    "EMPTY_TABLE_ONLY"
  );
}

function requireGeoPoint(data: Record<string, unknown>): GeoPoint | null {
  const value = data.geoPoint;
  if (value == null) return null;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "geoPoint must be an object");
  }
  const point = value as Record<string, unknown>;
  const latitude = point.latitude;
  const longitude = point.longitude;
  if (typeof latitude !== "number" || typeof longitude !== "number") {
    throw new HttpsError("invalid-argument", "geoPoint latitude and longitude are required");
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new HttpsError("invalid-argument", "geoPoint is outside valid latitude/longitude bounds");
  }
  return new GeoPoint(latitude, longitude);
}

function normalizeSlug(value: string, key: string): string {
  const slug = value.trim().toLowerCase();
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
    throw new HttpsError("invalid-argument", `${key} must use lowercase letters, numbers, and hyphens`);
  }
  return slug;
}

function createDisplayName(restaurantName: string, branchName: string): string {
  return `${restaurantName} - ${branchName}`;
}

function requirePartySize(data: Record<string, unknown>): number {
  const value = data.partySize;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1 || value > 20) {
    throw new HttpsError("invalid-argument", "partySize must be a whole number from 1 to 20");
  }
  return value;
}

function normalizePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith("91")) return `+${digits}`;
  if (phone.startsWith("+") && digits.length >= 10) return phone;
  throw new HttpsError("invalid-argument", "Enter a valid mobile number");
}

function partySizeBand(partySize: number): string {
  if (partySize <= 2) return "1-2";
  if (partySize <= 4) return "3-4";
  if (partySize <= 6) return "5-6";
  return "7+";
}

function tokenCode(tokenNumber: number): string {
  return `Q${tokenNumber.toString().padStart(2, "0")}`;
}

function businessDate(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function restaurantBranchIdFromRoute(restaurantId: string, branchId: string): string {
  if (restaurantId === branchId) return restaurantId;
  return `${restaurantId}-${branchId}`;
}

function branchPath(restaurantId: string, branchId: string): string {
  return `restaurantBranches/${restaurantBranchIdFromRoute(restaurantId, branchId)}`;
}

function queueEntriesPath(restaurantId: string, branchId: string): string {
  return `${branchPath(restaurantId, branchId)}/queueEntries`;
}

function tablesPath(restaurantId: string, branchId: string): string {
  return `${branchPath(restaurantId, branchId)}/tables`;
}

function dailyCounterPath(
  restaurantId: string,
  branchId: string,
  date: string,
): string {
  return `${branchPath(restaurantId, branchId)}/dailyCounters/${date}`;
}

async function assertBranchActive(restaurantId: string, branchId: string) {
  const branchRef = db.doc(branchPath(restaurantId, branchId));
  const branchSnap = await branchRef.get();
  if (!branchSnap.exists || branchSnap.get("isActive") !== true) {
    throw new HttpsError("failed-precondition", "Branch is not active");
  }
  return branchSnap;
}

async function assertAdminAccess(
  uid: string | undefined,
  restaurantId: string,
  branchId: string,
) {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Admin login required");
  }
  const restaurantBranchId = restaurantBranchIdFromRoute(restaurantId, branchId);
  const adminSnap = await db.doc(`admins/${uid}`).get();
  if (!adminSnap.exists || adminSnap.get("isActive") !== true) {
    throw new HttpsError("permission-denied", "No admin access");
  }
  if (adminSnap.get("restaurantBranchId") !== restaurantBranchId) {
    throw new HttpsError("permission-denied", "No branch access");
  }
}

function estimateWaitMinutes(groupsAhead: number): number {
  return Math.max(5, Math.min(120, groupsAhead * 10));
}

async function createQueueEntry(input: JoinQueueInput, sessionType: string) {
  const restaurantId = input.restaurantId;
  const branchId = input.branchId;
  const date = businessDate();
  await assertBranchActive(restaurantId, branchId);

  const counterRef = db.doc(dailyCounterPath(restaurantId, branchId, date));
  const queueRef = db.collection(queueEntriesPath(restaurantId, branchId)).doc();
  const phone = normalizePhone(input.phone);

  return db.runTransaction(async (transaction) => {
    const counterSnap = await transaction.get(counterRef);
    const lastTokenNumber = (counterSnap.get("lastTokenNumber") as number | undefined) ?? 0;
    const nextTokenNumber = lastTokenNumber + 1;
    const code = tokenCode(nextTokenNumber);
    const queuePosition = nextTokenNumber;
    const estimatedWaitMinutes = estimateWaitMinutes(Math.max(0, queuePosition - 1));

    transaction.set(
      counterRef,
      {
        businessDate: date,
        lastTokenNumber: nextTokenNumber,
        totalJoined: FieldValue.increment(1),
        totalSeated: counterSnap.exists ? FieldValue.increment(0) : 0,
        totalSkipped: counterSnap.exists ? FieldValue.increment(0) : 0,
        totalCancelled: counterSnap.exists ? FieldValue.increment(0) : 0,
        totalNoShow: counterSnap.exists ? FieldValue.increment(0) : 0,
        peakQueueDepth: Math.max(
          (counterSnap.get("peakQueueDepth") as number | undefined) ?? 0,
          queuePosition,
        ),
        createdAt: counterSnap.exists ? counterSnap.get("createdAt") : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.set(queueRef, {
      tokenNumber: nextTokenNumber,
      tokenCode: code,
      businessDate: date,
      customerName: input.customerName.trim(),
      phone,
      partySize: input.partySize,
      partySizeBand: partySizeBand(input.partySize),
      notes: input.notes ?? null,
      customerId: null,
      sessionType,
      appSource: input.appSource ?? "web",
      status: "waiting" satisfies QueueStatus,
      assignedTableId: null,
      assignedTableNumber: null,
      assignedTableIds: [],
      assignedTableNumbers: [],
      estimatedWaitMinutes,
      queuePosition,
      extensionUsed: false,
      joinedAt: FieldValue.serverTimestamp(),
      reservedAt: null,
      onTheWayAt: null,
      seatedAt: null,
      skippedAt: null,
      cancelledAt: null,
      expiredAt: null,
      noShowAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      queueEntryId: queueRef.id,
      tokenNumber: nextTokenNumber,
      tokenCode: code,
      estimatedWaitMinutes,
    };
  });
}

export const signInAdminWithTemporaryOtp = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const phone = normalizePhone(requireString(data, "phone"));
  const code = requireString(data, "code");
  if (code !== temporaryAdminOtp) {
    throw new HttpsError("permission-denied", "Invalid temporary OTP");
  }

  const adminQuery = await db
    .collection("admins")
    .where("phone", "==", phone)
    .limit(2)
    .get();
  if (adminQuery.empty) {
    throw new HttpsError("not-found", "No active admin mapping was found");
  }
  if (adminQuery.size != 1) {
    throw new HttpsError(
      "failed-precondition",
      "Multiple admin mappings use this phone number",
    );
  }

  const adminSnapshot = adminQuery.docs[0];
  const restaurantBranchId = adminSnapshot.get("restaurantBranchId");
  if (
    adminSnapshot.get("isActive") !== true ||
    typeof restaurantBranchId !== "string" ||
    restaurantBranchId.trim().length === 0
  ) {
    throw new HttpsError("permission-denied", "No active admin access");
  }

  const [adminUser, branchSnapshot] = await Promise.all([
    auth.getUser(adminSnapshot.id),
    db.doc(`restaurantBranches/${restaurantBranchId}`).get(),
  ]);
  if (adminUser.disabled) {
    throw new HttpsError("permission-denied", "Admin account is disabled");
  }
  if (!branchSnapshot.exists || branchSnapshot.get("isActive") !== true) {
    throw new HttpsError("failed-precondition", "Restaurant branch is inactive");
  }

  return {
    customToken: await auth.createCustomToken(adminSnapshot.id),
  };
});

export const createRestaurantBranch = onCall(async (request) => {
  assertPlatformProvisioner(request.auth?.uid, request.auth?.token);
  const data = request.data as Record<string, unknown>;
  const restaurantBranchId = normalizeSlug(
    requireString(data, "restaurantBranchId"),
    "restaurantBranchId",
  );
  const slug = normalizeSlug(requireString(data, "slug"), "slug");
  const restaurantName = requireString(data, "restaurantName");
  const branchName = requireString(data, "branchName");
  const area = requireString(data, "area");
  const address = requireString(data, "address");
  const qrSlug = normalizeSlug(requireString(data, "qrSlug"), "qrSlug");
  const geoPoint = requireGeoPoint(data);
  const subscription = optionalRecord(data, "subscription") ?? {
    plan: "starter",
    status: "trial",
  };
  const branchRef = db.doc(`restaurantBranches/${restaurantBranchId}`);
  const duplicateSlugQuery = db
    .collection("restaurantBranches")
    .where("slug", "==", slug)
    .limit(1);

  await db.runTransaction(async (transaction) => {
    const [branchSnap, duplicateSlugSnap] = await Promise.all([
      transaction.get(branchRef),
      transaction.get(duplicateSlugQuery),
    ]);

    if (branchSnap.exists) {
      throw new HttpsError(
        "already-exists",
        `restaurantBranches/${restaurantBranchId} already exists`,
      );
    }
    const duplicateSlugDoc = duplicateSlugSnap.docs.find((doc) => doc.id !== restaurantBranchId);
    if (duplicateSlugDoc) {
      throw new HttpsError(
        "already-exists",
        `slug ${slug} is already used by restaurantBranches/${duplicateSlugDoc.id}`,
      );
    }

    transaction.create(branchRef, {
      id: restaurantBranchId,
      slug,
      restaurantName,
      branchName,
      displayName: createDisplayName(restaurantName, branchName),
      area,
      address,
      geoPoint,
      subscription,
      qrSlug,
      isActive: true,
      onboardingCompleted: false,
      provisioningStatus: "pending",
      floorCount: 0,
      totalTables: 0,
      totalSeats: 0,
      capacityTypes: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    restaurantBranchId,
    path: `restaurantBranches/${restaurantBranchId}`,
  };
});

export const assignRestaurantBranchAdmin = onCall(async (request) => {
  assertPlatformProvisioner(request.auth?.uid, request.auth?.token);
  const data = request.data as Record<string, unknown>;
  const uid = requireString(data, "uid");
  const restaurantBranchId = normalizeSlug(
    requireString(data, "restaurantBranchId"),
    "restaurantBranchId",
  );
  const role = requireString(data, "role");
  const name = optionalString(data, "name");
  const email = optionalString(data, "email");
  const phone = optionalString(data, "phone");
  const isActive = typeof data.isActive === "boolean" ? data.isActive : true;
  const branchRef = db.doc(`restaurantBranches/${restaurantBranchId}`);
  const adminRef = db.doc(`admins/${uid}`);

  await db.runTransaction(async (transaction) => {
    const [branchSnap, adminSnap] = await Promise.all([
      transaction.get(branchRef),
      transaction.get(adminRef),
    ]);

    if (!branchSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        `restaurantBranches/${restaurantBranchId} must exist before assigning an admin`,
      );
    }
    const onboardingCompleted = branchSnap.get("onboardingCompleted") === true;

    if (adminSnap.exists) {
      const currentRestaurantBranchId = adminSnap.get("restaurantBranchId") as string | undefined;
      if (currentRestaurantBranchId !== restaurantBranchId) {
        throw new HttpsError(
          "already-exists",
          `admins/${uid} is already assigned to restaurantBranches/${currentRestaurantBranchId ?? ""}`,
        );
      }
      transaction.update(adminRef, {
        uid,
        restaurantBranchId,
        role,
        ...(name ? {name} : {}),
        ...(email ? {email} : {}),
        ...(phone ? {phone: normalizePhone(phone)} : {}),
        isActive,
        onboardingCompleted,
        ...(onboardingCompleted
          ? {onboardedAt: branchSnap.get("onboardingCompletedAt") ?? FieldValue.serverTimestamp()}
          : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    transaction.create(adminRef, {
      uid,
      ...(name ? {name} : {}),
      ...(email ? {email} : {}),
      ...(phone ? {phone: normalizePhone(phone)} : {}),
      restaurantBranchId,
      role,
      isActive,
      onboardingCompleted,
      ...(onboardingCompleted
        ? {onboardedAt: branchSnap.get("onboardingCompletedAt") ?? FieldValue.serverTimestamp()}
        : {}),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    uid,
    restaurantBranchId,
    path: `admins/${uid}`,
  };
});

export const provisionRestaurantBranchAdmin = onCall(async (request) => {
  assertPlatformProvisioner(request.auth?.uid, request.auth?.token);
  const data = request.data as Record<string, unknown>;
  const phone = normalizePhone(requireString(data, "phone"));
  const restaurantBranchId = normalizeSlug(
    requireString(data, "restaurantBranchId"),
    "restaurantBranchId",
  );
  const role = requireString(data, "role");
  const name = optionalString(data, "name");
  const email = optionalString(data, "email");
  const isActive = typeof data.isActive === "boolean" ? data.isActive : true;
  const branchRef = db.doc(`restaurantBranches/${restaurantBranchId}`);

  let adminUser;
  try {
    adminUser = await auth.getUserByPhoneNumber(phone);
  } catch (error: unknown) {
    const code = (error as {code?: string}).code;
    if (code !== "auth/user-not-found") throw error;
    adminUser = await auth.createUser({
      phoneNumber: phone,
      displayName: name ?? undefined,
      email: email ?? undefined,
      disabled: !isActive,
    });
  }

  if (
    (name && adminUser.displayName !== name) ||
    (email && adminUser.email !== email) ||
    adminUser.disabled === isActive
  ) {
    adminUser = await auth.updateUser(adminUser.uid, {
      displayName: name ?? adminUser.displayName,
      email: email ?? adminUser.email,
      disabled: !isActive,
    });
  }

  const adminRef = db.doc(`admins/${adminUser.uid}`);

  await db.runTransaction(async (transaction) => {
    const [branchSnap, adminSnap] = await Promise.all([
      transaction.get(branchRef),
      transaction.get(adminRef),
    ]);

    if (!branchSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        `restaurantBranches/${restaurantBranchId} must exist before assigning an admin`,
      );
    }
    const onboardingCompleted = branchSnap.get("onboardingCompleted") === true;

    if (adminSnap.exists) {
      const currentRestaurantBranchId = adminSnap.get("restaurantBranchId") as string | undefined;
      if (currentRestaurantBranchId !== restaurantBranchId) {
        throw new HttpsError(
          "already-exists",
          `admins/${adminUser.uid} is already assigned to restaurantBranches/${currentRestaurantBranchId ?? ""}`,
        );
      }
      transaction.update(adminRef, {
        uid: adminUser.uid,
        name: name ?? adminSnap.get("name") ?? adminUser.displayName ?? "",
        email: email ?? adminSnap.get("email") ?? adminUser.email ?? "",
        phone,
        restaurantBranchId,
        role,
        isActive,
        authProvider: "phone",
        onboardingCompleted,
        ...(onboardingCompleted
          ? {onboardedAt: branchSnap.get("onboardingCompletedAt") ?? FieldValue.serverTimestamp()}
          : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    transaction.create(adminRef, {
      uid: adminUser.uid,
      name: name ?? adminUser.displayName ?? "",
      email: email ?? adminUser.email ?? "",
      phone,
      restaurantBranchId,
      role,
      isActive,
      authProvider: "phone",
      onboardingCompleted,
      ...(onboardingCompleted
        ? {onboardedAt: branchSnap.get("onboardingCompletedAt") ?? FieldValue.serverTimestamp()}
        : {}),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    uid: adminUser.uid,
    phone,
    restaurantBranchId,
    authProvider: "phone",
    path: `admins/${adminUser.uid}`,
  };
});

export const joinQueue = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  return createQueueEntry(
    {
      restaurantId: requireString(data, "restaurantId"),
      branchId: requireString(data, "branchId"),
      customerName: requireString(data, "customerName"),
      phone: requireString(data, "phone"),
      partySize: requirePartySize(data),
      notes: typeof data.notes === "string" ? data.notes.trim() : null,
      appSource: "web",
    },
    "web_guest",
  );
});

export const addWalkIn = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  return createQueueEntry(
    {
      restaurantId,
      branchId,
      customerName: requireString(data, "customerName"),
      phone: requireString(data, "phone"),
      partySize: requirePartySize(data),
      notes: typeof data.notes === "string" ? data.notes.trim() : null,
      appSource: "admin_walkin",
    },
    "admin_created",
  );
});

export const markOnTheWay = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  const phone = normalizePhone(requireString(data, "phone"));
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const queueSnap = await queueRef.get();
  if (!queueSnap.exists || queueSnap.get("phone") !== phone) {
    throw new HttpsError("permission-denied", "Queue entry not found for phone");
  }
  if (queueSnap.get("status") !== "reserved") {
    throw new HttpsError("failed-precondition", "Only reserved entries can be marked on the way");
  }
  await queueRef.update({
    status: "on_the_way" satisfies QueueStatus,
    onTheWayAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

export const extendHold = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  const phone = normalizePhone(requireString(data, "phone"));
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const queueSnap = await queueRef.get();
  if (!queueSnap.exists || queueSnap.get("phone") !== phone) {
    throw new HttpsError("permission-denied", "Queue entry not found for phone");
  }
  const status = queueSnap.get("status") as QueueStatus;
  if (!["reserved", "on_the_way"].includes(status)) {
    throw new HttpsError("failed-precondition", "Only active reservations can be extended");
  }
  if (queueSnap.get("extensionUsed") === true) {
    throw new HttpsError("failed-precondition", "Extension already used");
  }
  await queueRef.update({
    extensionUsed: true,
    extensionRequestedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

export const cancelQueueEntry = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  const phone = typeof data.phone === "string" ? normalizePhone(data.phone) : null;
  const date = businessDate();
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const counterRef = db.doc(dailyCounterPath(restaurantId, branchId, date));

  await db.runTransaction(async (transaction) => {
    const queueSnap = await transaction.get(queueRef);
    if (!queueSnap.exists) {
      throw new HttpsError("not-found", "Queue entry not found");
    }
    if (!request.auth && queueSnap.get("phone") !== phone) {
      throw new HttpsError("permission-denied", "Phone does not match queue entry");
    }
    const status = queueSnap.get("status") as QueueStatus;
    if (!["waiting", "reserved", "on_the_way"].includes(status)) {
      throw new HttpsError("failed-precondition", "Queue entry cannot be cancelled");
    }
    for (const tableId of assignedTableIds(queueSnap)) {
      transaction.update(db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`), {
        status: "available" satisfies TableStatus,
        currentQueueEntryId: null,
        currentTokenCode: null,
        currentPartySize: null,
        reservedAt: null,
        occupiedAt: null,
        currentCycleStartAt: null,
        currentCycleSource: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.update(queueRef, {
      status: "cancelled" satisfies QueueStatus,
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(
      counterRef,
      {
        totalCancelled: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });
  return {ok: true};
});

export const reserveTable = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  const requestedTableIds = optionalStringArray(data, "tableIds");
  const tableIds = requestedTableIds.length > 0 ?
    requestedTableIds :
    [requireString(data, "tableId")];
  if (new Set(tableIds).size !== tableIds.length) {
    throw new HttpsError("invalid-argument", "tableIds cannot contain duplicates");
  }
  if (tableIds.length > 2) {
    throw new HttpsError("invalid-argument", "At most two tables can be combined");
  }
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const tableRefs = tableIds.map(
    (tableId) => db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`),
  );
  const date = businessDate();

  await db.runTransaction(async (transaction) => {
    const [queueSnap, ...tableSnaps] = await Promise.all([
      transaction.get(queueRef),
      ...tableRefs.map((tableRef) => transaction.get(tableRef)),
    ]);
    if (!queueSnap.exists || queueSnap.get("status") !== "waiting") {
      throw new HttpsError("failed-precondition", "Queue entry is not waiting");
    }
    if (tableSnaps.some(
      (tableSnap) => !tableSnap.exists || tableSnap.get("status") !== "available",
    )) {
      throw new HttpsError("failed-precondition", "A selected table is not available");
    }
    if (tableIds.length > 1) {
      const floorIds = new Set(tableSnaps.map(
        (tableSnap) => (tableSnap.get("floorId") as string | undefined)?.trim() ?? "",
      ));
      if (floorIds.size !== 1 || floorIds.has("")) {
        throw new HttpsError(
          "failed-precondition",
          "Combined tables must belong to the same valid floor",
        );
      }
    }
    const assignedAt = FieldValue.serverTimestamp();
    const tableNumbers = tableSnaps.map((tableSnap) => {
      const displayTableName = tableSnap.get("displayTableName");
      if (typeof displayTableName === "string" && displayTableName.trim().length > 0) {
        return displayTableName.trim();
      }
      return (tableSnap.get("tableNumber") as string | undefined) ?? "";
    });
    const partySize = (queueSnap.get("partySize") as number | undefined) ?? 0;
    const capacities = tableSnaps.map(
      (tableSnap) => (tableSnap.get("capacity") as number | undefined) ?? 0,
    );
    if (partySize <= 0 || capacities.reduce((total, capacity) => total + capacity, 0) < partySize) {
      throw new HttpsError("failed-precondition", "Selected tables cannot fit this party");
    }
    const cycleStarts: unknown[] = [];
    const cycleSources: string[] = [];
    const shouldFillAssignedTables = isEmptyTableOnlyPreference(
      queueSnap.get("customerPreferences"),
    );
    let remainingPartySize = partySize;
    for (const tableSnap of tableSnaps) {
      const previousCycleEndAt =
        tableSnap.get("lastCycleEndAt") ?? tableSnap.get("lastCompletedAt");
      cycleStarts.push(previousCycleEndAt ?? assignedAt);
      cycleSources.push(previousCycleEndAt == null ? "first_reservation" : "previous_completion");
    }
    transaction.update(queueRef, {
      status: "seated" satisfies QueueStatus,
      assignedTableId: tableIds[0],
      assignedTableNumber: tableNumbers.join(" + "),
      assignedTableIds: tableIds,
      assignedTableNumbers: tableNumbers,
      reservedAt: assignedAt,
      seatedAt: assignedAt,
      tableCycleStartAt: cycleStarts[0],
      tableCycleSource: tableIds.length === 1 ? cycleSources[0] : "combined_tables",
      updatedAt: assignedAt,
    });
    for (let index = 0; index < tableRefs.length; index++) {
      const capacity = (tableSnaps[index].get("capacity") as number | undefined) ?? 0;
      const occupiedSeatCount = shouldFillAssignedTables ?
        capacity :
        Math.max(0, Math.min(remainingPartySize, capacity));
      if (!shouldFillAssignedTables) {
        remainingPartySize -= occupiedSeatCount;
      }
      transaction.update(tableRefs[index], {
        status: "occupied" satisfies TableStatus,
        currentQueueEntryId: queueEntryId,
        currentTokenCode: queueSnap.get("tokenCode"),
        currentPartySize: occupiedSeatCount,
        reservedAt: assignedAt,
        occupiedAt: assignedAt,
        currentCycleStartAt: cycleStarts[index],
        currentCycleSource: cycleSources[index],
        updatedAt: assignedAt,
      });
    }
    transaction.set(
      db.doc(dailyCounterPath(restaurantId, branchId, date)),
      {totalSeated: FieldValue.increment(1), updatedAt: assignedAt},
      {merge: true},
    );
    transaction.set(db.collection("notifications").doc(), {
      restaurantId,
      branchId,
      queueEntryId,
      customerId: queueSnap.get("customerId") ?? null,
      type: "table_ready",
      channel: "mock",
      recipientPhone: queueSnap.get("phone"),
      title: "Your table is ready",
      message: "Please proceed to the seating desk.",
      status: "created",
      createdAt: FieldValue.serverTimestamp(),
      sentAt: null,
      error: null,
    });
  });
  return {ok: true};
});

export const confirmSeated = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const date = businessDate();

  await db.runTransaction(async (transaction) => {
    const queueSnap = await transaction.get(queueRef);
    if (!queueSnap.exists) throw new HttpsError("not-found", "Queue entry not found");
    const status = queueSnap.get("status") as QueueStatus;
    if (!["reserved", "on_the_way"].includes(status)) {
      throw new HttpsError("failed-precondition", "Queue entry cannot be seated");
    }
    const tableIds = assignedTableIds(queueSnap);
    if (tableIds.length === 0) {
      throw new HttpsError("failed-precondition", "No table assigned");
    }
    transaction.update(queueRef, {
      status: "seated" satisfies QueueStatus,
      seatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    for (const tableId of tableIds) {
      transaction.update(db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`), {
        status: "occupied" satisfies TableStatus,
        occupiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.set(
      db.doc(dailyCounterPath(restaurantId, branchId, date)),
      {totalSeated: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  });
  return {ok: true};
});

export const updateTableStatus = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const tableId = requireString(data, "tableId");
  const status = requireString(data, "status") as TableStatus;
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  if (!["available", "reserved", "occupied", "blocked"].includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid table status");
  }
  const update: Record<string, unknown> = {
    status,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (status === "available") {
    update.currentQueueEntryId = null;
    update.currentTokenCode = null;
    update.reservedAt = null;
  }
  await db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`).update(update);
  return {ok: true};
});

export const skipCustomer = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  await db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`).update({
    status: "skipped" satisfies QueueStatus,
    skippedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

export const markNoShow = onCall(async (request) => {
  const data = request.data as Record<string, unknown>;
  const restaurantId = requireString(data, "restaurantId");
  const branchId = requireString(data, "branchId");
  const queueEntryId = requireString(data, "queueEntryId");
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const date = businessDate();

  await db.runTransaction(async (transaction) => {
    const queueSnap = await transaction.get(queueRef);
    if (!queueSnap.exists) throw new HttpsError("not-found", "Queue entry not found");
    transaction.update(queueRef, {
      status: "no_show" satisfies QueueStatus,
      noShowAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    for (const tableId of assignedTableIds(queueSnap)) {
      transaction.update(db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`), {
        status: "available" satisfies TableStatus,
        currentQueueEntryId: null,
        currentTokenCode: null,
        currentPartySize: null,
        reservedAt: null,
        occupiedAt: null,
        currentCycleStartAt: null,
        currentCycleSource: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.set(
      db.doc(dailyCounterPath(restaurantId, branchId, date)),
      {totalNoShow: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  });
  return {ok: true};
});
