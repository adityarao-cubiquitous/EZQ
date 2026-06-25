# EZQ by Cubiquitous — Feature Hierarchy & Implementation Logic

**Source:** EZQ Product Architecture & Build Handout + 2026-06-22 Implementation Addendum
**Purpose:** Every feature in the product, organized by platform (Web App → Android → iOS), with the recommended implementation logic/working behind each feature so an engineer (human or AI agent) can build it consistently across platforms from one Flutter + Firebase codebase.

> Convention: Features are grouped by **experience** (Customer / Hostess-Admin) and then by **platform tier**, since EZQ is one Flutter codebase. "Web App" = MVP priority. "Android" and "iOS" = Phase 2, built on the same models/repositories/Cloud Functions — only the presentation shell and platform capabilities differ.

---

## A. WEB APP (MVP — Customer + Hostess/Admin)

### A.1 Customer Web — Join Queue

**Feature:** Customer scans QR / opens branch URL and joins queue with name, phone, party size, optional notes.

**Implementation logic:**
- Route: `/customer/:restaurantId/:branchId`. Resolve restaurant + branch doc on load; if `isActive == false`, show a "currently not accepting queue" state instead of the form.
- Party size: exact-value picklist (1, 2, 3, 4, 5, 6, 7+), not free text — prevents invalid input and simplifies table matching.
- On submit, call Cloud Function `joinQueue` (never write Firestore directly from client).
- `joinQueue` runs a Firestore transaction on `dailyCounters/{businessDate}`:
    1. Read counter doc.
    2. Increment `lastTokenNumber` → assign `tokenNumber` / `tokenCode`.
    3. Increment `totalJoined`.
    4. Create `queueEntries/{queueEntryId}` with `status = "waiting"`.
    5. Compute `estimatedWaitMinutes` (see Wait Time Logic, Section D).
- Business date is computed server-side using the branch's `timezone` field, not client device time.
- After success, store `queueEntryId` locally (in-memory/session state, never localStorage as source of truth) and navigate to the status route.
- **Disable re-join:** once a queue entry exists for the current session/phone, the Join Queue button/form is disabled and the user is redirected to their existing status page — prevents duplicate tokens.

### A.2 Customer Web — Queue Status (live)

**Feature:** Real-time status page showing token, position, live countdown, and state-specific UI.

**Implementation logic:**
- Subscribe to `queueEntries/{queueEntryId}` via a Firestore stream (`CustomerQueueRepository.watchQueueEntry()`); no polling.
- Derive `queuePosition` from the count of `waiting` entries with `joinedAt` earlier than this entry within the branch — or read the denormalized `queuePosition` field if maintained by the function.
- **Countdown, not static estimate:** on the client, take `estimatedWaitMinutes` + `joinedAt` and run a local ticking timer (`Stream.periodic`) to count down `remaining = (joinedAt + estimatedWaitMinutes) - now`, recalculated whenever Firestore pushes an update (e.g., after a reserve event shortens/extends it).
- UI swaps based on `status`:
    - `waiting` → "You are in the queue" + progress bar + countdown.
    - `reserved` → trigger Table Ready Alert (A.3).
    - `on_the_way` → keep table-ready styling, disable "I'm on my way" button.
    - `seated` → Seated Screen (A.4).
    - `skipped` / `cancelled` / `no_show` → terminal state screen with no further actions.
- Actions on this screen call dedicated Cloud Functions, verified by phone match: `markOnTheWay`, `extendHold`, `cancelQueueEntry`.
- "View Menu" opens `menuPdfUrl` from the branch document in a scrollable PDF viewer (e.g., `pdfx`/`flutter_pdfview` web-compatible viewer) — never hardcode menu content.
- Hidden-object puzzle widget reads `hiddenObjectPuzzleImageUrl` (fallback `waitPuzzleImageUrl`); if null, render a static placeholder card — never a broken image.

### A.3 Customer Web — Table Ready Alert

**Feature:** Full-screen alert when table is reserved for the customer, with a hold timer.

**Implementation logic:**
- Triggered purely by `status == "reserved"` from the live stream — no separate push needed for MVP since it's web/foreground.
- Hold timer = `branch.holdMinutes` (default 5) counted from `reservedAt`.
- "I'm on my way" → `markOnTheWay` Cloud Function → sets `onTheWayAt`, status `on_the_way`. Table status remains `reserved` (table is not occupied until actual seating).
- "Need 5 more minutes" → `extendHold` Cloud Function:
    - Validates `extensionUsed == false` and status is `reserved`/`on_the_way`.
    - Sets `extensionUsed = true`, extends effective hold deadline by 5 minutes (client recalculates countdown using an `extensionGrantedAt` or similar timestamp).
    - Button disables permanently after first use (one-time only, enforced server-side, not just UI-side).
- Warning copy is static, always visible while in `reserved`/`on_the_way`: late arrival risks losing the spot.

### A.4 Customer Web — Seated Screen

**Feature:** Confirms customer has been seated.

**Implementation logic:**
- Triggered by `status == "seated"` from the live stream.
- Read-only confirmation screen; no further customer actions except optional feedback placeholder (non-functional in MVP, reserved for Phase 2).
- This is a terminal UI state — once shown, no further status transitions are expected for this queue entry except backend completion (`completed`), which doesn't change customer-facing UI.

### A.5 Customer Web — Optional App Install Prompt

**Feature:** Non-blocking nudge to install the app for repeat visits.

**Implementation logic:**
- Rendered as a dismissible banner/screen, never a modal that blocks the join-queue or status flow.
- "Continue in browser" always available and equally prominent as "Install app".
- Tracks `appInstalled` flag on `customers/{customerId}` only once an actual install + login occurs in Phase 2 — in MVP this is purely a UI nudge with no backend effect.

### A.6 Hostess/Admin Web — Login

**Feature:** Manager/admin authentication.

**Implementation logic:**
- Firebase Authentication, email/password (finalized per addendum — no anonymous/phone auth for admins).
- On successful auth, fetch matching `restaurants/{restaurantId}/admins/{adminUserId}` doc by `uid` to get `role` and `branchIds`.
- All subsequent admin-only Cloud Function calls pass the Firebase ID token; the function re-validates `role`/`branchIds` server-side — client-side role checks are UX-only, never the security boundary.

### A.7 Hostess/Admin Web — Branch Selector

**Feature:** Shown only if admin has access to more than one branch.

**Implementation logic:**
- If `admin.branchIds.length == 1`, skip this screen and route directly to that branch's dashboard.
- Each branch card streams a lightweight count query (`waiting` queue entries) for "today's queue count" — keep this query cheap (count aggregation, not full document fetch, where Firestore count() is available).

### A.8 Hostess/Admin Web — Dashboard (Table Grid + Queue Panel)

**Feature:** Primary operational screen — live table grid and live queue list with actions.

**Implementation logic:**
- Two independent Firestore stream subscriptions: `tables` (where `branchId` matches) and `queueEntries` (where `status in [waiting, reserved, on_the_way]`), combined via Riverpod providers (`StreamProvider` + a derived combining provider) — avoid one mega-query.
- **Table grid grouping:** group tables client-side by `capacity` bucket (2/4/6/8/10-top) and sort by `sortOrder` within each bucket. Do not display section/location labels (explicitly removed).
- **Tile state → action mapping:**
  | Table status | Tile action | Notes |
  |---|---|---|
  | `available` | none | shows `Occ 0` |
  | `reserved` | "Mark seated" | shows linked token + party size |
  | `occupied` | "Meal finished" | shows linked token + party size, prompts for `completedPartySize` |
  | `blocked` | none (MVP) | reserved for future admin control |
- **Reserve flow:** tapping "Reserve" on a queue entry opens a table picklist ranked by `TableRecommendationEngine` (see F3) — ordered by recommendation type (`EXACT_MATCH` → `SHARED_MATCH` → `LARGER_ALTERNATIVE` → `COMBINED_TABLE`), then by `recommendationScore` descending within each type. Each item displays table number, capacity, occupancy, and a recommendation tag. Selecting a table calls `reserveTable` Cloud Function.
- **Mark Seated:** calls `confirmSeated` — transactionally updates queue entry to `seated`, table to `occupied`, sets `currentCycleStartAt`, increments `dailyCounters.totalSeated`.
- **Meal Finished:** opens a small confirmation requiring `completedPartySize`; calls a (new/updated) Cloud Function that sets queue entry `completed`, table back to `available`, records `lastCycleStartAt`/`lastCycleEndAt`, clears `currentQueueEntryId`/`currentTokenCode`.
- **Skip:** calls `skipCustomer`, only valid from `waiting`.
- **Cancel:** calls `cancelQueueEntry`, valid from `waiting`/`reserved`/`on_the_way`; releases table if one was reserved.
- **No-show:** calls `markNoShow`, only valid from `reserved`/`on_the_way`; releases table.
- Topbar metrics (`Free`, `Occupied`, `Waiting`) are derived client-side from the same streams — no extra read needed.
- **Bidirectional recommendation / visual decision support (F3):** clicking a table card highlights best-matching queue parties with colored borders (green = exact match, yellow = next-best alternatives); clicking a queue party card highlights eligible tables in the grid (green = exact-fit empty, orange = shared seating, blue = combined tables). Both directions run through a single `TableRecommendationEngine` — one engine, one output, no duplicated logic across surfaces.
- UI must remain responsive with **no nested menus**; every action above is reachable in at most one tap + one confirmation.

### A.9 Hostess/Admin Web — Add Walk-in

**Feature:** Manually add a walk-in customer to the queue from the dashboard.

**Implementation logic:**
- Modal collects name, phone, party size, optional notes (same validation as customer join form).
- Calls `addWalkIn` Cloud Function — identical transaction logic to `joinQueue` but sets `sessionType = "admin_created"`, `appSource = "admin_walkin"`.
- Optional "Add and seat directly" toggle, enabled only if at least one matching `available` table exists — if used, chains `addWalkIn` then immediately `reserveTable`/`confirmSeated` in sequence (still two discrete server calls, not a special combined endpoint, to keep functions composable).

### A.10 Hostess/Admin Web — Table Detail Modal

**Feature:** Inspect and directly manage an individual table.

**Implementation logic:**
- Opened by tapping a table tile (secondary tap target, distinct from the primary action button).
- Shows current status, current guest (if any), and a list of currently `waiting` queue entries that match this table's capacity (computed client-side from the already-subscribed queue stream — no extra query).
- Actions available here mirror grid actions plus admin-only manual overrides: "Mark occupied", "Mark cleaning" (**removed per addendum — do not implement**), "Mark available", "Block table" — all route through `updateTableStatus`, which validates the transition server-side against the allowed table-status transition table.

### A.11 Hostess/Admin Web — Daily Summary

**Feature:** Simple end-of-day / live operational stats.

**Implementation logic:**
- Reads a single `dailyCounters/{businessDate}` document via stream — all counters (`totalJoined`, `totalSeated`, `totalSkipped`, `totalCancelled`, `totalNoShow`, `peakQueueDepth`) are maintained incrementally by the Cloud Functions, never recomputed client-side by scanning all queue entries.
- "Waiting now" and "Average wait time" are the two values not stored on the counter doc directly — compute "waiting now" from the live queue stream count, and average wait time client-side from completed entries' `joinedAt`→`seatedAt` deltas for the current `businessDate` (acceptable to be simple/approximate in MVP).

---

## B. ANDROID (Phase 2 — Customer App)

> Built from the **same** Flutter codebase, models, and repositories as the Web App. Only the shell, navigation chrome, and platform integrations differ.

### B.1 App Landing

**Implementation logic:**
- `go_router` route `/app/home`. "Continue with phone" and "Continue as guest" both lead into the same `CustomerQueueRepository`/`CustomerProfileRepository` used by web — guest sessions simply skip the `customers/{customerId}` profile linkage.
- "Recently visited restaurants" reads from `customers/{customerId}/visits` (requires phone auth) — for guest mode, this list is empty/hidden rather than erroring.
- "Scan restaurant QR" — only on native (Android/iOS) is the actual camera-based QR scanner implemented (explicitly excluded from MVP web). Use a Flutter QR scanning package gated behind a platform check so it never appears in the Web build.

### B.2 Restaurant Detail

**Implementation logic:**
- Reuses the same branch document shape as web's join screen; adds opening hours/address fields already modeled on `branches/{branchId}` (extend model if not already present, do not create a parallel model).
- "Favorite" toggles a `favoriteBranchIds` array on the customer profile — Phase 2 only, no effect on MVP queue logic.

### B.3 Join Queue (Android)

**Implementation logic:**
- Same `joinQueue` Cloud Function and same form validation as Web (A.1). Difference is purely presentational (native form widgets vs. web layout) — **do not fork business logic per platform**.
- If logged in via phone, pre-fill name/phone/`defaultPartySize` from `customers/{customerId}`.

### B.4 My Queue (Status)

**Implementation logic:**
- Identical stream subscription pattern to A.2, rendered with native widgets. Countdown timer logic must be the shared implementation (e.g., a single `WaitCountdownController` class used by both web and mobile UI) to avoid divergent behavior.
- Adds native push notification support: when `status` transitions to `reserved`, a Cloud Function trigger (`onQueueEntryUpdate`) sends an FCM push via `PushNotificationProvider` (Phase 2 notification provider) in addition to the existing in-app notification record.

### B.5 Visit History

**Implementation logic:**
- Reads `customers/{customerId}/visits` ordered by `createdAt` descending.
- A visit document is created by a Cloud Function trigger when a queue entry reaches a terminal state (`seated`/`completed`, `cancelled`, `no_show`) for a logged-in customer — guest sessions do not generate visit history (no `customerId` to attach to).

### B.6 Profile

**Implementation logic:**
- Simple form bound to `customers/{customerId}` fields: `displayName`, `phone` (read-only post-verification), `preferredLanguage`, `defaultPartySize`, notification toggle (maps to FCM token registration/unregistration).
- Writes go through a Cloud Function (`updateCustomerProfile`, to be added in Phase 2) rather than direct client writes, consistent with the "no direct critical writes" principle — profile isn't queue-critical, but keeping the pattern consistent simplifies security rules.

### B.7 Deep Linking (Android)

**Implementation logic:**
- Android App Links configured against `https://ezq.cubiquitous.in/customer/{restaurantId}/{branchId}` (same URL as the QR/web link — no separate scheme).
- `go_router` resolves the same route definitions used by web; if the app is installed, the link opens natively, otherwise it falls back to the web app automatically (standard App Links behavior) — no custom fallback logic needed in-app.

---

## C. iOS (Phase 2 — Customer App)

> Mirrors Android feature-for-feature on the same shared codebase. Notes below cover only iOS-specific implementation differences.

### C.1 App Landing / Restaurant Detail / Join Queue / My Queue / Visit History / Profile

**Implementation logic:**
- Functionally identical to Android (B.1–B.6); same Riverpod providers, same repositories, same Cloud Functions. No business logic fork — only iOS-specific platform widgets/permissions (e.g., `NSCameraUsageDescription` for QR scanner, APNs setup for push instead of/alongside FCM).

### C.2 Push Notifications (iOS)

**Implementation logic:**
- Use Firebase Cloud Messaging with APNs configuration (certificates/keys) — same `onQueueEntryUpdate` trigger as Android sends through FCM, which forwards to APNs; no separate notification-sending code path needed per platform.

### C.3 Deep Linking (iOS)

**Implementation logic:**
- iOS Universal Links configured against the same canonical URL pattern (`apple-app-site-association` file hosted alongside Firebase Hosting). Same `go_router` routes resolve identically to Android and Web — this is the payoff of having designed the QR/URL strategy once, platform-agnostically, from MVP.

---

## D. SHARED BACKEND LOGIC (used identically across Web, Android, iOS)

These are not platform features but the shared logic every platform calls into — included here because every feature above depends on getting this right once, not three times.

### D.1 Table Matching Logic

```
partySize 1–2 → prefer capacity 2
partySize 3–4 → prefer capacity 4
partySize 5–6 → prefer capacity 6
partySize 7+  → prefer largest table / manual override

match if table.capacity >= partySize
priority: smallest sufficient capacity → same section (if tracked) →
          longest-waiting matching party → hostess manual override
```
- Implemented once in `functions/src/lib/tableMatching.ts`; both the customer-facing wait-estimate logic and the admin reserve-picklist sort call this same module — never duplicate the matching rule in Dart and TypeScript separately if avoidable (TS is source of truth; Dart side only renders what the function returns).
- **Extended by `TableRecommendationEngine` (F3/F4):** client-side Dart layer (`lib/features/recommendation/domain/table_recommendation_engine.dart`) applies factor-based weighted scoring on top of these eligibility rules to produce ranked `TableRecommendation` lists for both recommendation directions and the Reserve dropdown. The TS module determines eligibility; the Dart engine determines recommendation type classification (`EXACT_MATCH` / `SHARED_MATCH` / `LARGER_ALTERNATIVE` / `COMBINED_TABLE`) and score.

### D.2 Wait Time Logic

```
If matching table available:
  estimatedWaitMinutes = max(5, groupsAhead * 5)
If no matching table available:
  estimatedWaitMinutes = min(120, max(10, groupsAhead * averageDiningMinutes / matchingTableCount))
Fallback: groupsAhead * 10
Clamp: 5–120 minutes
```
- Computed server-side in `joinQueue`/`addWalkIn` at creation time, and may be recomputed on subsequent reads if groupsAhead changes — kept simple and explainable per non-negotiables, not ML-driven.

### D.3 Status Transition Guards

- Both `queueEntries` and `tables` status changes are validated against the explicit allowed-transition tables (see Non-Negotiables doc, Section 3) inside every relevant Cloud Function, before any write — implemented as a shared `validators.ts` helper (`assertValidQueueTransition`, `assertValidTableTransition`) so every callable function uses the same guard rather than re-implementing checks inline.

### D.4 Notification Records

- `notifications/{notificationId}` is created by the relevant Cloud Function (e.g., on `reserveTable`) with `channel = "mock"` in MVP.
- Phase 2 swaps in `WhatsAppNotificationProvider` / `SmsNotificationProvider` / `PushNotificationProvider` behind the same `NotificationProvider` interface — calling code in the Cloud Functions does not change, only the provider implementation injected.

---

## F. ADVANCED FEATURES — Bidirectional Recommendation & Large Party Seating

> These features extend the Hostess/Admin Web Dashboard (A.8) and Shared Backend Logic (D.1). F3 establishes `TableRecommendationEngine` as the single source of truth for all recommendation surfaces on the dashboard. F4 extends the engine with combined-table recommendations for parties larger than any single available table.

### F3 — Bidirectional Recommendation & Visual Decision Support Engine

**Feature:** `TableRecommendationEngine` drives every recommendation surface on the admin dashboard: table card → queue party highlights (extended direction), queue party card → table grid highlights (new direction), and the Reserve dropdown. All ranking and recommendation-type classification logic lives in exactly one class. No surface reimplements or duplicates logic.

**Implementation logic:**

**`TableRecommendation` model:**
```
TableRecommendation {
  tableId,
  tableNumber,
  recommendationType,      // EXACT_MATCH | SHARED_MATCH | LARGER_ALTERNATIVE | COMBINED_TABLE
  recommendationScore,     // integer 0–100
  recommendationReason,    // mandatory human-readable string, never null
  availableSeats,
  occupancy,
  capacity
}
```

`recommendationReason` examples: `"Exact Capacity Match"`, `"Best Shared Seating Option"`, `"Closest Available Alternative"`, `"Customer Prefers Empty Table"`, `"Adjacent Combined Table Recommendation"`.

**Direction 1 — Table card → queue party highlights (extended from existing behavior):**
- Clicking a table card evaluates all waiting parties against: table capacity, current occupancy, remaining seats, waiting time, party size, and customer seating preference.
- Queue party cards are highlighted with colored borders by recommendation type:
  - **Green border + green glow (`EXACT_MATCH`):** party size exactly fills the table's capacity or remaining seats. Always shown first. At least one alternative must accompany it — never highlight only a single party.
  - **Yellow border (`SHARED_MATCH` / `LARGER_ALTERNATIVE`):** party size fits but capacity or remaining seats exceed the requirement. Manager always sees alternatives.

**Direction 2 — Queue party card → table grid highlights (new):**
- Clicking a queue party card evaluates all `available` and partially occupied tables against: party size, waiting time, queue position, customer preference, capacity fit, and available seats.
- Table tiles are highlighted with colored borders by recommendation type:
  - **Green border + green glow (`EXACT_MATCH`):** empty table whose capacity exactly equals party size.
  - **Orange border + orange glow (`SHARED_MATCH`):** partially occupied table where `(capacity − occupancy) >= partySize` with minimal capacity waste.
  - **Blue border + blue glow (`COMBINED_TABLE`):** adjacent table combination (see F4); used when no single table qualifies.
- Reserve dropdown is populated from the identical ranked output — same order and types as the table grid highlights.

**Reserve dropdown:**
- Consumes `TableRecommendationEngine` output directly — no widget-level re-sort.
- Ordering: `EXACT_MATCH` → `SHARED_MATCH` → `LARGER_ALTERNATIVE` → `COMBINED_TABLE`, then by `recommendationScore` descending within each type.
- Each item displays: table number, capacity, occupancy, and a recommendation tag:
  - 🟢 Exact Match
  - 🟠 Shared Seating
  - 🟡 Larger Alternative
  - 🔵 Combined Tables

**Customer empty-table preference (future compatibility hook):**
- If a customer's recorded preference is `EMPTY_TABLE_ONLY`, `SHARED_MATCH` recommendations must be suppressed for that party.
- Suppressed items are replaced with a `"Not Recommended — Customer Prefers Exclusive Table Seating"` entry, rendered distinctly and non-actionable.
- This check is applied inside `TableRecommendationEngine` before output is emitted — not at the widget layer — so table grid, queue panel, and Reserve dropdown all reflect the preference automatically with no additional widget logic.

**Implementation:** `lib/features/recommendation/domain/table_recommendation_engine.dart`, exposed as a Riverpod provider consumed by the queue panel widget, table grid widget, and Reserve dropdown widget. Zero recommendation logic is permitted outside this class.

**Data sources — mandatory, no mock data permitted:**
- Queue entries: `restaurants/{restaurantId}/branches/{branchId}/queueEntries` (Firestore stream; `status in [waiting, reserved, on_the_way]`)
- Tables: `restaurants/{restaurantId}/branches/{branchId}/tables` (Firestore stream)
- Branch config: `restaurants/{restaurantId}/branches/{branchId}` (capacity rules, hold settings)
- All occupancy, capacity, and status values must come from live Firestore documents. Mock repositories, local JSON, hardcoded table sets, and in-memory fake data are not permitted at any layer.

**Mandatory architecture — Firestore → Repository → Engine → UI:**
- The repository layer subscribes to Firestore streams and exposes typed Dart streams.
- `TableRecommendationEngine` consumes repository output only — it never reads Firestore directly.
- UI widgets observe engine output via Riverpod providers and render results only.
- UI components must never construct, modify, or own recommendation data.

**F3 acceptance criteria (all must pass against live Firestore data):**
1. Clicking a real queue party card immediately highlights real Firestore-backed table tiles.
2. Clicking a real table card immediately highlights real Firestore-backed queue party cards.
3. Reserve dropdown ordering derives from live Firestore table and queue data.
4. Highlights update immediately when Firestore data changes (status, occupancy, party joins/leaves) — no manual refresh.
5. All F3 validation runs against Firebase Emulator Suite or the EZQ development Firebase project. Mock repository testing and local fake data are not valid acceptance methods.

#### F3 Implementation Status (as of 2026-06-24)

| Capability | Status | Notes |
|---|---|---|
| Bidirectional recommendations (party→table, table→party) | ✅ Implemented | `computeRecommendationsForParty`, `computeRecommendationsForTable` in engine |
| Highlight colors (green / orange / yellow / blue) | ✅ Implemented | `TableGrid` + `QueuePanel` multi-color border + bg tint |
| Reserve dialog engine ordering | ✅ Implemented | `_ReserveTableDialog` consumes `partyRecommendationProvider` directly; no re-sort |
| Suppression logic (`EMPTY_TABLE_ONLY`) | ✅ Implemented | `isSuppressed` flag; filtered from `tableHighlightMapProvider`; shown disabled in dialog |
| Riverpod integration | ✅ Implemented | `partyRecommendationProvider`, `tableRecommendationProvider`, `tableHighlightMapProvider`, `queueHighlightMapProvider`; `BranchRef` family key |
| Auto-clear selection on status change | ✅ Implemented | `ref.listen` in `AdminDashboardScreen`; mutual exclusion on tap |
| Score formula (F3-19: score = 79) | ✅ Unit-tested | Engine test P2T-01 |
| `SHARED_MATCH` — orange highlight + shared Reserve | ⚠️ CF-Blocked | Engine logic implemented; blocked on `confirmSeated` CF writing `occupancy = partySize` |
| Firebase acceptance criteria (criteria 1–5 above) | 🔥 Pending Firebase validation | 14 of 20 F3 scenarios verified by unit test or static analysis; 3 blocked on CF; 3 require live stream tests |

### F4 — Large Party Seating & Combined Table Recommendation Engine

**Feature:** When no single table can accommodate the party size, `TableRecommendationEngine` runs a combined-table search and emits `COMBINED_TABLE` entries in the standard `TableRecommendation` list. Queue panel, table grid, and Reserve dropdown handle them via the same codepath — no special-case branches.

**When activated:** engine produces zero qualifying `EXACT_MATCH` or `LARGER_ALTERNATIVE` single-table results for the given `partySize`.

**`CombinedTableRecommendation` model:**
```
CombinedTableRecommendation {
  recommendationId,
  tableIds[],            // 2 or more tables
  combinedCapacity,
  recommendationScore,   // integer 0–100
  recommendationReason   // mandatory string
}
```

**Table metadata additions (extend existing table model; do not create a new model):**
```
Table {
  ...existing fields...,
  floorId,
  adjacentTableIds[],   // tableIds of physically adjacent tables
  x,                    // logical floor coordinate (integer)
  y
}
```
Example: `{ "tableId": "T4", "floorId": "F1", "adjacentTableIds": ["T3","T5"], "x": 120, "y": 80 }`

`floorId`, `adjacentTableIds`, and coordinates must be stored on every table document even in single-floor MVP deployments — required for multi-floor extension without a data migration.

**Combined-table priority rules (applied in this order):**
1. **Adjacency first:** only combine tables connected via `adjacentTableIds` graph traversal.
2. **Smallest capacity waste:** prefer combinations where `combinedCapacity` is closest to `partySize`.
3. **Minimum tables consumed:** prefer 2-table sets over 3-table sets.
4. **Reduced waiting time:** prioritize combinations that unblock the longest-waiting party.
5. **Queue fairness:** avoid stranding upcoming small-party seatings.
6. **Preserve small tables:** avoid consuming tables that are the sole available match for smaller future parties.

**Combined table highlighting:**
- All tiles in a recommended combination receive a **blue border + blue glow**.
- Each tile in the set displays a `"Combined Tables"` tag listing its partner table(s).

**`RecommendationContext` (engine input):**
```
RecommendationContext {
  partySize,
  waitingTime,
  queuePosition,
  availableTables,
  occupiedTables,
  partiallyOccupiedTables
}
```

**`RecommendationFactors` (configurable scoring weights):**
```
RecommendationFactors {
  capacityFitWeight,
  occupancyWeight,
  waitTimeWeight,
  adjacencyWeight,
  fairnessWeight
}
```

**MVP score formula:**
```
score = (capacityFit      × 40)
      + (occupancyMatch   × 25)
      + (waitTimeImpact   × 15)
      + (adjacencyQuality × 15)
      + (fairness         ×  5)

Normalize result to 0–100.
```

**Future extensibility — plug-and-play factors:**
- Each scoring factor is a discrete, independently testable contributor.
- New factors — empty-table preference, floor preference, window preference, accessibility preference, high chair requirement, VIP seating, loyalty tier, historical acceptance patterns — must plug in as additional weighted contributors without modifying the core ranking loop or any existing factor implementation.
- No engine rewrite is required to introduce a new factor.

**Data sources — mandatory, no mock data permitted:**
- Tables: `restaurants/{restaurantId}/branches/{branchId}/tables` (live documents including `floorId`, `adjacentTableIds`, `x`, `y`, `status`, `occupancy`, `capacity`)
- Queue entries: `restaurants/{restaurantId}/branches/{branchId}/queueEntries`
- No hardcoded adjacency graph, sample table sets, or fake table combinations. All adjacency data must come from `adjacentTableIds` on live Firestore table documents.

**F4 acceptance criteria (all must pass against live Firestore data):**
1. Combined-table recommendations are generated from live Firestore table documents with real `adjacentTableIds` data.
2. Changes to table occupancy in Firestore immediately affect which combinations are recommended.
3. Changes to queue party size immediately affect which combinations are surfaced.
4. Recommendation results remain consistent and correct as Firestore updates propagate.
5. All F4 validation runs against Firebase Emulator Suite or the EZQ development Firebase project. Adjacency graphs must be seeded into the emulator or real project — never hardcoded in test code.

#### F4 Implementation Status (as of 2026-06-24)

| Capability | Status | Notes |
|---|---|---|
| Combined table engine (`computeCombinedTableOptions`) | ✅ Implemented | Pairs before triples; top 3 results |
| BFS adjacency search using Firestore document IDs | ✅ Implemented | Keyed on `table.id`; C-3 compliant |
| C-5 trigger condition (no single table qualifies) | ✅ Implemented + unit-tested | Engine test F4-12 |
| Pair preference over triple (fewer tables) | ✅ Unit-tested | Engine test F4-05 |
| Triangle vs linear chain adjacency scoring | ✅ Unit-tested | Engine test F4-07; adjacencyScore 100 vs 70 |
| Small table fairness penalty | ✅ Unit-tested | Engine test F4-08 |
| Score formula (F4-17: score = 83) | ✅ Unit-tested | Engine test F4-01 |
| Combined table entries in `partyRecommendationProvider` | ✅ Implemented | Engine test F4-13 |
| Blue highlight on all constituent table tiles | ✅ Implemented | `tableHighlightMapProvider` emits one entry per constituent table ID |
| `combinedPartnerIds` in `TableHighlight` | ✅ Implemented | `recommendation_providers.dart` line 141 |
| Combined table Reserve (sequential `reserveTable` calls) | ✅ Implemented | `_reserveQueueEntry` loop; `combinedTableIds` drives call count |
| Reserve dialog dedup for combined combos | ✅ Implemented | Canonical key: sorted IDs joined with `,` |
| `adjacentTableIds` seed script with doc IDs | ✅ Created | `tool/seed_f4_adjacency_scenario.mjs` — 11 tables, bidirectional |
| Firebase acceptance criteria (criteria 1–5 above) | 🔥 Pending Firebase validation | 13 of 20 F4 scenarios unit-tested; 7 require live Firestore/Emulator test |

---

## G. Known Open Dependencies (F3/F4)

> These are external dependencies that block specific F3/F4 behaviors. Requirements are not changed — these items must be resolved before the blocked behaviors can be accepted.

| # | Dependency | Blocks | Owner |
|---|---|---|---|
| 1 | `confirmSeated` Cloud Function must write `tables/{tableId}.occupancy = partySize` | All `SHARED_MATCH` recommendations (F3-03, F3-04, F3-10) | Cloud Function implementer |
| 2 | `completeMeal` Cloud Function must write `tables/{tableId}.occupancy = 0` | `SHARED_MATCH` lifecycle correctness (occupied table returns to 0 after meal) | Cloud Function implementer |
| 3 | Firebase Emulator smoke test using `tool/seed_f4_adjacency_scenario.mjs` | F4 acceptance criteria 1–4 (live adjacency, occupancy reactivity, stream consistency) | Flutter engineer |
| 4 | Production table documents must have `adjacentTableIds` populated with Firestore document IDs | F4 live operation in production branch | Admin setup / data migration |
| 5 | F4-18 bidirectionality validator must pass against the production branch | Confirms no `tableNumber` strings exist in `adjacentTableIds` | QA / Flutter engineer |

**Seed scripts available:**
- `tool/seed_f4_adjacency_scenario.mjs` — F4 adjacency scenario (11 tables, 3 queue entries, bidirectional doc-ID adjacency). Run with `--emulator` flag for Firebase Emulator.
- `tool/seed_partial_seat_scenario.mjs` — F3 partial-seat scenario (6-top with 4 occupied, 2 remaining). Updated with `occupancy`, `floorId`, `adjacentTableIds`, `x`, `y` fields.

---

## H. Production Readiness (F3/F4)

> Assessed as of 2026-06-24. This section reflects implementation state, not requirements.

| Feature / Flow | Ready? | Condition |
|---|---|---|
| `EXACT_MATCH` — party→table highlight + Reserve dialog | ✅ Ready | No blockers. Unit-tested, static-verified. |
| `LARGER_ALTERNATIVE` — yellow highlight + Reserve dialog | ✅ Ready | No blockers. Unit-tested, static-verified. |
| Table→party highlights (bidirectional, F3 direction 1) | ✅ Ready | No blockers. Unit-tested, static-verified. |
| Selection mutual exclusion + auto-clear | ✅ Ready | No blockers. Static-verified. |
| `COMBINED_TABLE` (F4) — blue highlight + combined Reserve | ✅ Ready (pending smoke test) | Requires Firebase Emulator smoke test sign-off (F4-01, F4-09, F4-18, F4-20). Engine fully unit-tested. |
| `SHARED_MATCH` — orange highlight + shared Reserve | ⚠️ Partially Ready | Engine and UI implemented. Blocked on Cloud Function occupancy writes (Dependencies 1 and 2 above). |
| Full F3 Firebase acceptance criteria | 🔥 Pending | 3 scenarios CF-blocked; 3 require live stream testing. |
| Full F4 Firebase acceptance criteria | 🔥 Pending | 7 scenarios require live Firestore/Emulator test. |

**Overall:** The recommendation engine, Riverpod providers, and dashboard wiring are production-ready for exactMatch, largerAlternative, and combinedTable flows. SharedMatch requires Cloud Function delivery. Full acceptance sign-off requires Firebase Emulator validation session.

---

## E. Feature Priority Summary (build order)

1. **Web App (MVP):** A.1 → A.2 → A.3 → A.4 → A.6 → A.7 → A.8 → A.9 → A.10 → A.11 → A.5
2. **Android (Phase 2):** B.3/B.4 (core loop reused from web logic) → B.1/B.2 (shell) → B.6 (profile) → B.5 (history) → B.7 (deep links) → push notifications
3. **iOS (Phase 2):** Mirrors Android once shared codebase is proven; C.2/C.3 are the only platform-specific build items.
4. **Advanced Dashboard Features (F3 → F4):** F3 (`TableRecommendationEngine` core + bidirectional highlighting + Reserve dropdown integration) must be complete before F4. F4 extends the engine with `COMBINED_TABLE` type and requires the table model to be extended with `floorId`, `adjacentTableIds`, and coordinate fields before combined-table graph traversal can run.

---

*This document will be extended with the new feature set once provided, inserted under the appropriate platform section (Web App / Android / iOS) rather than as a disconnected appendix, so build order and dependencies stay coherent.*