import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();

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

function requireString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${key} is required`);
  }
  return value.trim();
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

function branchPath(restaurantId: string, branchId: string): string {
  return `restaurants/${restaurantId}/branches/${branchId}`;
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
  const adminSnap = await db.doc(`restaurants/${restaurantId}/admins/${uid}`).get();
  if (!adminSnap.exists || adminSnap.get("isActive") !== true) {
    throw new HttpsError("permission-denied", "No admin access");
  }
  const branchIds = adminSnap.get("branchIds") as string[] | undefined;
  if (!branchIds?.includes(branchId)) {
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
    const tableId = queueSnap.get("assignedTableId") as string | null;
    if (tableId) {
      transaction.update(db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`), {
        status: "available" satisfies TableStatus,
        currentQueueEntryId: null,
        currentTokenCode: null,
        reservedAt: null,
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
  const tableId = requireString(data, "tableId");
  await assertAdminAccess(request.auth?.uid, restaurantId, branchId);
  const queueRef = db.doc(`${queueEntriesPath(restaurantId, branchId)}/${queueEntryId}`);
  const tableRef = db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`);
  const date = businessDate();

  await db.runTransaction(async (transaction) => {
    const [queueSnap, tableSnap] = await Promise.all([
      transaction.get(queueRef),
      transaction.get(tableRef),
    ]);
    if (!queueSnap.exists || queueSnap.get("status") !== "waiting") {
      throw new HttpsError("failed-precondition", "Queue entry is not waiting");
    }
    if (!tableSnap.exists || tableSnap.get("status") !== "available") {
      throw new HttpsError("failed-precondition", "Table is not available");
    }
    const assignedAt = FieldValue.serverTimestamp();
    transaction.update(queueRef, {
      status: "seated" satisfies QueueStatus,
      assignedTableId: tableId,
      assignedTableNumber: tableSnap.get("tableNumber"),
      reservedAt: assignedAt,
      seatedAt: assignedAt,
      updatedAt: assignedAt,
    });
    transaction.update(tableRef, {
      status: "occupied" satisfies TableStatus,
      currentQueueEntryId: queueEntryId,
      currentTokenCode: queueSnap.get("tokenCode"),
      reservedAt: assignedAt,
      occupiedAt: assignedAt,
      updatedAt: assignedAt,
    });
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
    const tableId = queueSnap.get("assignedTableId") as string | null;
    if (!tableId) throw new HttpsError("failed-precondition", "No table assigned");
    transaction.update(queueRef, {
      status: "seated" satisfies QueueStatus,
      seatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`), {
      status: "occupied" satisfies TableStatus,
      occupiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
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
    const tableId = queueSnap.get("assignedTableId") as string | null;
    transaction.update(queueRef, {
      status: "no_show" satisfies QueueStatus,
      noShowAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (tableId) {
      transaction.update(db.doc(`${tablesPath(restaurantId, branchId)}/${tableId}`), {
        status: "available" satisfies TableStatus,
        currentQueueEntryId: null,
        currentTokenCode: null,
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
