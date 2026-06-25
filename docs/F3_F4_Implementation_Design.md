# EZQ F3/F4 — Implementation Design

**Date:** 2026-06-24
**Revision:** v2 — 2026-06-24 (Correction pass: C-1 through C-6, AR-2, MVP simplifications applied)
**Status:** Phases 1–4 implemented (2026-06-24). Firebase validation (Phase 5) pending. See §0 for per-component detail.
**Scope:** F3 Bidirectional Recommendation & Visual Decision Support Engine + F4 Large Party Seating & Combined Table Recommendation Engine.
**Prerequisite reading:** EZQ Feature Doc §F3, §F4; EZQ Non-Negotiables §10, §11.

**Corrections applied in this revision:**
| ID | Description |
|---|---|
| C-1 | Floating-point assert in `RecommendationFactors` replaced with epsilon comparison |
| C-2 | Provider-side state mutation removed; auto-clear moved to `ref.listen` in `AdminDashboardScreen` |
| C-3 | `adjacentTableIds` standardised to Firestore document IDs throughout schema, examples, and test cases |
| C-4 | `occupancy` write ownership formalised with Cloud Function contract; SHARED_MATCH prerequisite documented |
| C-5 | Combined table trigger condition corrected to include `validSharedMatch.isEmpty` |
| C-6 | `isSuppressed` flag added to `TableRecommendation`; suppressed entries excluded from highlight maps; dropdown shows them disabled |
| AR-2 | `RecommendationContext` retained; engine interface updated to accept it as input (Option A) |
| SMP | Simplifications: `reserveDropdownProvider` removed; `RecommendationResult` wrapper removed; `CombinedTableRecommendation.recommendationId` removed; model files merged from 12 → 9 |

---

## 0. Implementation Status

> This section tracks implementation reality against the design. Requirements in §§1–13 are unchanged.

### 0.1 Phase Summary

| Phase | Scope | Status |
|---|---|---|
| Phase 1 | Domain models, Firestore model extensions, repository cleanup, Riverpod provider stubs | ✅ Implemented |
| Phase 2 | `TableRecommendationEngine` — all three public methods + private helpers | ✅ Implemented · 39 unit tests passing |
| Phase 3 | `partyRecommendationProvider`, `tableRecommendationProvider`, `tableHighlightMapProvider`, `queueHighlightMapProvider` | ✅ Implemented |
| Phase 4 | `AdminDashboardScreen` Riverpod migration, `TableGrid` multi-color highlights, `QueuePanel` highlights, `_ReserveTableDialog` engine wiring | ✅ Implemented |
| Phase 5 | Firebase Emulator end-to-end validation | 🔥 Pending Firebase validation |

**`flutter analyze`:** No issues found.  
**`flutter test`:** 60/60 passing (39 engine + 20 algorithm + 1 widget).

---

### 0.2 Component Status

| Component | File(s) | Status | Notes |
|---|---|---|---|
| `RecommendationType`, `SeatingPreference` | `recommendation_types.dart` | ✅ Implemented | Wire names: `EMPTY_TABLE_ONLY`, `ANY_AVAILABLE` |
| `CustomerPreferences` | `customer_preferences.dart` | ✅ Implemented | `fromMap`/`toMap`, `const .defaults()` |
| `TableRecommendation` | `table_recommendation.dart` | ✅ Implemented | `isSuppressed` (C-6), `combinedTableIds` |
| `QueuePartyRecommendation` | `queue_party_recommendation.dart` | ✅ Implemented | exactMatch + largerAlternative types only |
| `CombinedTableRecommendation` | `combined_table_recommendation.dart` | ✅ Implemented | No `recommendationId` (SMP) |
| `RecommendationContext` | `recommendation_context.dart` | ✅ Implemented | AR-2 Option A engine input |
| `RecommendationFactors` | `recommendation_factors.dart` | ✅ Implemented | C-1: epsilon assert, not `.abs()` |
| `TableHighlight`, `QueueHighlight` | `highlight_models.dart` | ✅ Implemented | `isGreen`/`isOrange`/`isYellow`/`isBlue` getters |
| `TableRecommendationEngine` | `table_recommendation_engine.dart` | ✅ Implemented | All 3 public methods; 39 unit tests |
| `computeRecommendationsForParty` | engine | ✅ Tested | P2T-01–14 (14 tests); F3-19 score=79 verified |
| `computeRecommendationsForTable` | engine | ✅ Tested | T2P-01–12 (12 tests) |
| `computeCombinedTableOptions` | engine | ✅ Tested | F4-01–13 (13 tests); F4-17 score=83 verified |
| C-5 trigger condition | engine | ✅ Tested | Unit test F4-12 |
| C-6 suppression | engine + provider | ✅ Implemented | `isSuppressed` flag; provider filters line 135 |
| `selectedQueueEntryIdProvider` | `selection_providers.dart` | ✅ Implemented | `legacy.dart` import (Riverpod 3.x) |
| `selectedTableIdProvider` | `selection_providers.dart` | ✅ Implemented | |
| `BranchRef` | `recommendation_providers.dart` | ✅ Implemented | `@immutable`; `==`/`hashCode` |
| `partyRecommendationProvider` | `recommendation_providers.dart` | ✅ Implemented | Returns `null` when loading or no selection |
| `tableRecommendationProvider` | `recommendation_providers.dart` | ✅ Implemented | |
| `tableHighlightMapProvider` | `recommendation_providers.dart` | ✅ Implemented | Filters `!r.isSuppressed` (C-6) |
| `queueHighlightMapProvider` | `recommendation_providers.dart` | ✅ Implemented | |
| `AdminDashboardScreen` Riverpod migration | `admin_dashboard_screen.dart` | ✅ Implemented | `late final BranchRef _branch`; no inline construction |
| C-2 auto-clear (party + table) | `admin_dashboard_screen.dart` | ✅ Implemented | `ref.listen` callbacks, lines 67–88 |
| Selection mutual exclusion | `admin_dashboard_screen.dart` | ✅ Implemented | Each tap nulls the other provider |
| `TableGrid` multi-color highlights | `table_grid.dart` | ✅ Implemented | green/orange/yellow/blue border + bg tint |
| `QueuePanel` queue highlights | `queue_panel.dart` | ✅ Implemented | green/yellow border; teal for selected |
| `_ReserveTableDialog` engine wiring | `admin_dashboard_screen.dart` | ✅ Implemented | Consumes `partyRecommendationProvider` |
| Combined table reserve (2 calls) | `admin_dashboard_screen.dart` | ✅ Implemented | Sequential `reserveTable` per constituent table |
| `RestaurantTable` field extensions | `restaurant_table.dart` | ✅ Implemented | `occupancy`, `floorId`, `adjacentTableIds`, `x`, `y` |
| `QueueEntry.customerPreferences` | `queue_entry.dart` | ✅ Implemented | Nullable; null → anyAvailable |
| Mock repositories removed | `table_repository.dart`, `queue_repository.dart` | ✅ Implemented | Always Firebase |
| `seed_partial_seat_scenario.mjs` | `tool/` | ✅ Updated | Fixed `toField` array bug; added F3/F4 fields |
| `seed_f4_adjacency_scenario.mjs` | `tool/` | ✅ Created | 11 tables, 3 queue entries, bidirectional adjacency |
| `F3_F4_Validation_Report.md` | `docs/` | ✅ Created | Full scenario coverage and production readiness |

---

### 0.3 What Is NOT Yet Complete

| Item | Status | Blocked by |
|---|---|---|
| SharedMatch flow end-to-end (F3-03, F3-04, F3-10) | ⚠️ CF-BLOCKED | `confirmSeated` CF must write `occupancy = partySize`; `completeMeal` CF must write `occupancy = 0` |
| Firebase Emulator smoke test (F4-01, 09, 12, 13, 18, 19, 20) | 🔥 Pending | Firebase Emulator session required |
| F4-18 bidirectionality validator | 🔥 Pending | Live Firestore query required |
| Firebase acceptance criteria (F3 §6.1, F4 §6.2) | 🔥 Pending | All 11 FIREBASE-REQUIRED scenarios in Validation Report |

---

### 0.4 Known Open Dependencies

1. **`confirmSeated` Cloud Function** must write `tables/{tableId}.occupancy = partySize`. Blocks all SharedMatch tests.
2. **`completeMeal` Cloud Function** must write `tables/{tableId}.occupancy = 0`. Required for SharedMatch lifecycle.
3. **Firebase Emulator** must be seeded with `tool/seed_f4_adjacency_scenario.mjs` before F4 manual validation.
4. **Production table documents** must have `adjacentTableIds` populated with Firestore document IDs (not `tableNumber` strings) for F4 to function. See §3.1 C-3 contract and the F4-18 bidirectionality validator.

---

### 0.5 Production Readiness

| Flow | Ready? | Condition |
|---|---|---|
| `exactMatch` — party → table highlight + Reserve | ✅ Ready | No blockers |
| `largerAlternative` — party → table highlight + Reserve | ✅ Ready | No blockers |
| `combinedTable` (F4) — blue highlight + combined Reserve | ✅ Ready | Needs Firebase smoke test pass |
| Table → party highlights (bidirectional F3) | ✅ Ready | No blockers |
| Selection auto-clear + mutual exclusion | ✅ Ready | No blockers |
| `sharedMatch` — orange highlight + shared Reserve | ⚠️ Blocked | Requires Cloud Function occupancy writes |
| Full Firebase acceptance criteria (§6.1, §6.2) | 🔥 Pending | 11 scenarios require live Firebase validation |

---

## 1. Existing Codebase State & What Changes

### 1.1 What Already Exists (Do Not Break)

| File | Current Role | Change Required for F3/F4 |
|---|---|---|
| `lib/features/tables/domain/restaurant_table.dart` | `RestaurantTable` model | Add 5 new fields |
| `lib/features/tables/data/table_repository.dart` | `TableRepository` abstract + `FirebaseTableRepository` + `MockTableRepository` | Remove `MockTableRepository`; keep Firebase impl unchanged |
| `lib/features/queue/domain/queue_entry.dart` | `QueueEntry` model | Add `customerPreferences` field |
| `lib/features/queue/data/queue_repository.dart` | `QueueRepository` abstract + `FirebaseQueueRepository` + `MockQueueRepository` | Remove `MockQueueRepository` |
| `lib/features/admin/presentation/admin_dashboard_screen.dart` | Dashboard + selection state + `_bestFitTables` / `_tablesForParty` + `_ReserveTableDialog` | Lift selection state to Riverpod; add `ref.listen` auto-clear; remove `_bestFitTables` / `_tablesForParty`; wire Reserve dialog to engine output |

### 1.2 The Existing Logic Being Replaced

**`_bestFitTables()`** (lines 834–883, `admin_dashboard_screen.dart`):
```
Current behavior: returns only the single best priority group (P1 or P2 or P3 or P4).
Problem: returns one group, no scoring, no multi-type simultaneous highlights.
Replacement: TableRecommendationEngine.computeRecommendationsForParty()
```

**`_tablesForParty()`** (line 885+, `admin_dashboard_screen.dart`):
```
Current behavior: filters tables where remaining >= partySize, used only in ReserveTableDialog.
Problem: no ranking, no reason strings, no type classification.
Replacement: partyRecommendationProvider output consumed by ReserveTableDialog directly.
```

**`_selectedQueueEntry` (setState in `_AdminDashboardScreenState`)**:
```
Current behavior: local widget state.
Problem: cannot be consumed by separate TableGrid widget without prop drilling.
Replacement: selectedQueueEntryIdProvider (Riverpod StateProvider).
```

**`occupiedCountFor()` (computed from queue data, line 109–113)**:
```
Current behavior: estimates occupancy as partySize of the assigned queue entry.
Problem: approximation — does not use actual guest count.
Replacement: RestaurantTable.occupancy field written exclusively by Cloud Functions.
```

**`tableRepositoryProvider` and `queueRepositoryProvider` (USE_FIREBASE flag)**:
```
Current behavior: MockTableRepository when USE_FIREBASE=false.
Required change: Always use FirebaseTableRepository / FirebaseQueueRepository.
Mock repositories must be removed before F3/F4 testing begins.
```

---

## 2. New File Structure

All new files go under `lib/features/recommendation/`. Do not place recommendation logic inside `tables/`, `queue/`, or `admin/`.

**[SMP] File count reduced from 12 → 9 domain files by merging small related enums and models.**

```
lib/features/recommendation/
  domain/
    recommendation_types.dart         ← RecommendationType enum + SeatingPreference enum (merged)
    customer_preferences.dart         ← CustomerPreferences model
    table_recommendation.dart         ← TableRecommendation model (includes isSuppressed)
    queue_party_recommendation.dart   ← QueuePartyRecommendation model
    combined_table_recommendation.dart← CombinedTableRecommendation model
    recommendation_context.dart       ← RecommendationContext (engine input — AR-2 Option A)
    recommendation_factors.dart       ← RecommendationFactors model
    highlight_models.dart             ← TableHighlight + QueueHighlight (merged)
    table_recommendation_engine.dart  ← TableRecommendationEngine class
  providers/
    recommendation_providers.dart     ← All Riverpod providers for F3/F4
    selection_providers.dart          ← selectedTableIdProvider, selectedQueueEntryIdProvider
```

**Removed files (vs v1):**
- `recommendation_type.dart` + `seating_preference.dart` → merged into `recommendation_types.dart`
- `table_highlight.dart` + `queue_highlight.dart` → merged into `highlight_models.dart`
- `recommendation_result.dart` → removed entirely (wrapper eliminated, §4.8)

---

## 3. Firestore Schema

### 3.1 `tables` Collection

**Path:** `restaurants/{restaurantId}/branches/{branchId}/tables/{tableId}`

**Existing fields (unchanged):**

| Field | Type | Description |
|---|---|---|
| `tableNumber` | `string` | Display name, e.g. "T4" |
| `capacity` | `int` | Maximum guests |
| `tableType` | `string` | e.g. "4-top" |
| `section` | `string` | Legacy — not shown in UI per addendum |
| `status` | `string` | available \| reserved \| occupied \| blocked |
| `currentQueueEntryId` | `string?` | Linked party |
| `currentTokenCode` | `string?` | Display token |
| `sortOrder` | `int` | Sort within capacity group |
| `reservedAt` | `Timestamp?` | |
| `occupiedAt` | `Timestamp?` | |
| `currentCycleStartAt` | `Timestamp?` | |
| `lastCycleStartAt` | `Timestamp?` | |
| `lastCycleEndAt` | `Timestamp?` | |

**New fields required by F3/F4:**

| Field | Type | Default | Written by | Reason |
|---|---|---|---|---|
| `occupancy` | `int` | `0` | `confirmSeated`, `completeMeal` Cloud Functions **only** | F3 SHARED_MATCH requires `capacity - occupancy`. See §3.4 for Cloud Function contract. |
| `floorId` | `string` | `"F1"` | Admin setup | F4 adjacency constraints are per-floor. Must be present even in single-floor deployments. |
| `adjacentTableIds` | `string[]` | `[]` | Admin setup (seeded) | F4 adjacency graph. **Must contain Firestore document IDs** — see §3.4 for the ID contract. |
| `x` | `int` | `0` | Admin setup | Logical floor coordinate for future adjacency visualization. Not consumed by F3/F4 engine. |
| `y` | `int` | `0` | Admin setup | Logical floor coordinate. Not consumed by F3/F4 engine. |

**Complete document example:**

```json
{
  "tableNumber": "T4",
  "capacity": 4,
  "tableType": "4-top",
  "section": "main",
  "status": "occupied",
  "occupancy": 2,
  "currentQueueEntryId": "qe_abc123",
  "currentTokenCode": "Q07",
  "sortOrder": 4,
  "floorId": "F1",
  "adjacentTableIds": ["tbl_f1a9c3d2e4b8", "tbl_2c7d9f0e1a3b"],
  "x": 120,
  "y": 80,
  "reservedAt": null,
  "occupiedAt": "2026-06-24T13:00:00Z",
  "currentCycleStartAt": "2026-06-24T13:00:00Z",
  "lastCycleStartAt": null,
  "lastCycleEndAt": null
}
```

**[C-3] `adjacentTableIds` field contract:**

`adjacentTableIds` must contain **Firestore document IDs** (the `id` field on `RestaurantTable` — the auto-generated UUID-style key), never `tableNumber` strings such as "T3" or "T5".

**Why this matters:** The F4 engine builds an adjacency graph keyed by `table.id`. If `adjacentTableIds` stores `tableNumber` values, the lookup `id exists in availableTables` compares against `RestaurantTable.id` (UUID), finds zero matches, and returns no combinations. F4 is silently broken.

**Validation rule:** Before any F4 test, run the bidirectionality validator (see F4-18). It will expose non-document-ID values immediately because the fetch by ID will return no document.

**Seed script requirement:** All seed scripts (`tool/seed_partial_seat_scenario.mjs`, `tool/seed_f4_adjacency_scenario.mjs`) must populate `adjacentTableIds` with the actual Firestore document IDs of the neighbour tables, not their `tableNumber` display strings.

### 3.2 `queueEntries` Collection

**Path:** `restaurants/{restaurantId}/branches/{branchId}/queueEntries/{queueEntryId}`

**Existing fields (unchanged):** all current `QueueEntry` fields.

**New field required by F3:**

| Field | Type | Default | Written by | Reason |
|---|---|---|---|---|
| `customerPreferences` | `map?` | `null` | `joinQueue` / `addWalkIn` Cloud Functions, or admin walk-in form | F3 customer empty-table preference. Null = `anyAvailable`. Engine checks this before emitting SHARED_MATCH recommendations. |

**`customerPreferences` sub-document:**
```json
{
  "seatingPreference": "ANY_AVAILABLE",
  "floorPreference": null,
  "accessibilityRequired": false
}
```

`seatingPreference` valid values: `"ANY_AVAILABLE"` | `"EMPTY_TABLE_ONLY"`

**Why on `queueEntry`, not on `customers/{customerId}`:** MVP customers are guests with no account. Preferences captured at join time belong to the entry, not a persistent profile. Phase 2: `joinQueue` Cloud Function can read from `customers/{customerId}.preferences` and copy into the entry — the engine interface does not change.

### 3.3 No `recommendations` Collection

Recommendations are computed client-side from live Firestore streams by `TableRecommendationEngine`. They are never written to Firestore. Writing them would create write-amplification and introduce stale-data risk.

### 3.4 `occupancy` Field — Cloud Function Ownership Contract

**[C-4] This section defines the single source of truth for the `occupancy` field. SHARED_MATCH in F3 is completely non-functional without this contract being implemented in Cloud Functions.**

`occupancy` is the count of guests currently seated at the table. It is:
- **Written exclusively by Cloud Functions.** No client write is permitted.
- **Never inferred** from `partySize` in application code. The `occupiedCountFor()` approximation in `admin_dashboard_screen.dart` is fully replaced by this field.

**Required Cloud Function behaviours:**

| Function | Trigger | Required Write |
|---|---|---|
| `confirmSeated` | Manager marks party as seated | `tables/{tableId}.occupancy = partySize` (from the queue entry's `partySize` field) |
| `completeMeal` | Manager finalises meal with guest count | `tables/{tableId}.occupancy = 0` (table is now empty) |

**SHARED_MATCH prerequisite:** SHARED_MATCH recommendations can only be generated for tables where `occupancy > 0 AND occupancy < capacity`. Until `confirmSeated` writes a non-zero `occupancy`, all occupied tables have `occupancy = 0` and are excluded from SHARED_MATCH by the filter `occupancy > 0`. SHARED_MATCH will not function until the Cloud Functions listed above are updated.

**Pre-coding action:** Confirm with the Cloud Function implementer that both `confirmSeated` and `completeMeal` will write `occupancy` in this sprint. If not, descope SHARED_MATCH from F3 acceptance criteria and add a tracking note.

**Migration behaviour for existing documents:** Documents without the `occupancy` field deserialise with default value `0`. The engine guard `occupancy > 0` in the SHARED_MATCH filter ensures these documents are never incorrectly classified as partially occupied. This is conservative and correct.

---

## 4. Domain Models (Design — Dart)

All models are immutable. Use `@immutable` annotation. Implement `==` and `hashCode` for every model (required for Riverpod `select()` to detect changes correctly).

### 4.1 `recommendation_types.dart` — merged enums

**[SMP] `RecommendationType` and `SeatingPreference` live in a single file.**

```dart
// lib/features/recommendation/domain/recommendation_types.dart

enum RecommendationType {
  exactMatch,         // Empty table, capacity == partySize
  sharedMatch,        // Partially occupied, (capacity - occupancy) >= partySize
  largerAlternative,  // Empty table, capacity > partySize
  combinedTable,      // 2+ adjacent tables combined (F4)
}

enum SeatingPreference {
  anyAvailable,
  emptyTableOnly;

  static SeatingPreference fromWireName(String? value) {
    return value == 'EMPTY_TABLE_ONLY' ? emptyTableOnly : anyAvailable;
  }

  String get wireName =>
      this == emptyTableOnly ? 'EMPTY_TABLE_ONLY' : 'ANY_AVAILABLE';
}
```

**Highlight color contract (UI must honor exactly):**
- `exactMatch` → green border + green glow
- `sharedMatch` (non-suppressed) → orange border + orange glow
- `sharedMatch` (suppressed by preference) → **no highlight**; appears in Reserve dropdown as disabled
- `largerAlternative` → yellow border
- `combinedTable` → blue border + blue glow

### 4.2 `CustomerPreferences`

```dart
// lib/features/recommendation/domain/customer_preferences.dart

@immutable
class CustomerPreferences {
  const CustomerPreferences({
    this.seatingPreference = SeatingPreference.anyAvailable,
    this.floorPreference,
    this.accessibilityRequired = false,
  });

  final SeatingPreference seatingPreference;
  final String? floorPreference;       // reserved for future factor
  final bool accessibilityRequired;    // reserved for future factor

  const CustomerPreferences.defaults()
      : seatingPreference = SeatingPreference.anyAvailable,
        floorPreference = null,
        accessibilityRequired = false;

  factory CustomerPreferences.fromMap(Map<String, dynamic> data) { ... }
  Map<String, dynamic> toMap() { ... }

  @override bool operator ==(Object other) { ... }
  @override int get hashCode { ... }
}
```

### 4.3 `TableRecommendation`

Represents a single table recommended for a selected queue party (party → table direction).

**[C-6] `isSuppressed` field added.**

```dart
// lib/features/recommendation/domain/table_recommendation.dart

@immutable
class TableRecommendation {
  const TableRecommendation({
    required this.tableId,
    required this.tableNumber,
    required this.recommendationType,
    required this.recommendationScore,
    required this.recommendationReason,
    required this.availableSeats,
    required this.occupancy,
    required this.capacity,
    this.isSuppressed = false,
    this.combinedTableIds,
  })  : assert(recommendationReason != ''),
        assert(recommendationScore >= 0 && recommendationScore <= 100);

  final String tableId;
  final String tableNumber;
  final RecommendationType recommendationType;
  final int recommendationScore;       // 0–100
  final String recommendationReason;   // Non-empty, human-readable
  final int availableSeats;            // capacity - occupancy
  final int occupancy;
  final int capacity;
  final bool isSuppressed;             // true when sharedMatch is blocked by customerPreferences
  final List<String>? combinedTableIds; // non-null only for combinedTable type

  @override bool operator ==(Object other) { ... }
  @override int get hashCode { ... }
}
```

**[C-6] `isSuppressed` contract:**
- `isSuppressed` is `true` only when `recommendationType == sharedMatch` AND the party's `customerPreferences.seatingPreference == emptyTableOnly`.
- Suppressed entries are **included** in the engine output list (so the Reserve dropdown can render them as disabled, informing the manager of the reason).
- Suppressed entries are **excluded** from the `tableHighlightMapProvider` output. No orange border is ever applied to them.
- The `recommendationReason` on a suppressed entry is always: `"Not Recommended — Customer Prefers Exclusive Table Seating"`.
- The `recommendationScore` on a suppressed entry retains its calculated value (not forced to 0). Suppressed entries are sorted after all non-suppressed `sharedMatch` entries within the group.

**`recommendationReason` contract — engine must produce exactly one of these strings per type:**

| Type | Condition | Reason string |
|---|---|---|
| `exactMatch` | — | `"Exact Capacity Match"` |
| `sharedMatch` | remaining == partySize, not suppressed | `"Best Shared Seating — ${availableSeats} Seats Available"` |
| `sharedMatch` | remaining > partySize, not suppressed | `"Can Accommodate Party — ${availableSeats} Seats Available"` |
| `sharedMatch` | suppressed | `"Not Recommended — Customer Prefers Exclusive Table Seating"` |
| `largerAlternative` | — | `"Closest Available Alternative — ${capacity}-Top"` |
| `combinedTable` | — | `"Combined Tables ${tableNumbers} — Capacity ${combinedCapacity}"` |
| fallback | no eligible table at all | `"No Available Table — Notify Manager"` |

### 4.4 `QueuePartyRecommendation`

Represents a queue party recommended for a selected table (table → party direction). No suppression mechanism in this direction.

```dart
// lib/features/recommendation/domain/queue_party_recommendation.dart

@immutable
class QueuePartyRecommendation {
  const QueuePartyRecommendation({
    required this.queueEntryId,
    required this.tokenCode,
    required this.customerName,
    required this.partySize,
    required this.recommendationType,
    required this.recommendationScore,
    required this.recommendationReason,
    required this.waitingMinutes,
    required this.queuePosition,
  })  : assert(recommendationReason != '');

  final String queueEntryId;
  final String tokenCode;
  final String customerName;
  final int partySize;
  final RecommendationType recommendationType;  // exactMatch or largerAlternative only
  final int recommendationScore;                // 0–100
  final String recommendationReason;
  final int waitingMinutes;
  final int queuePosition;

  @override bool operator ==(Object other) { ... }
  @override int get hashCode { ... }
}
```

**Reason strings for this direction:**

| Type | Reason string |
|---|---|
| `exactMatch` | `"Exact Party Size Match"` |
| `largerAlternative` | `"Party Fits — ${table.remainingSeats - partySize} Seats Remaining"` |

### 4.5 `CombinedTableRecommendation`

**[SMP] `recommendationId` removed — recommendations are never persisted, so a UUID serves no purpose.**

```dart
// lib/features/recommendation/domain/combined_table_recommendation.dart

@immutable
class CombinedTableRecommendation {
  const CombinedTableRecommendation({
    required this.tableIds,
    required this.tableNumbers,
    required this.combinedCapacity,
    required this.recommendationScore,
    required this.recommendationReason,
  })  : assert(tableIds.length >= 2),
        assert(recommendationReason != '');

  final List<String> tableIds;      // Firestore document IDs
  final List<String> tableNumbers;  // parallel to tableIds, for display
  final int combinedCapacity;
  final int recommendationScore;    // 0–100
  final String recommendationReason;

  @override bool operator ==(Object other) { ... }
  @override int get hashCode { ... }
}
```

### 4.6 `RecommendationContext` — Engine Input (AR-2 Decision: Option A)

**[AR-2] Decision: Option A — `RecommendationContext` is retained as the engine input model for the party → table direction.**

**Rationale:** The engine's single-table algorithm (§6.2) requires 6 inputs — `partySize`, `waitingMinutes`, `queuePosition`, `customerPreferences`, `availableTables`, `partiallyOccupiedTables`. Passing these as individual parameters couples the engine signature to the input structure. Using `RecommendationContext` as the input:
- Allows new inputs (e.g., time of day, section preference) to be added without changing the method signature.
- Moves the table-partition logic (Step 1 in the previous v1 algorithm) to the **provider layer**, which is the correct boundary — providers know about Firestore data; the engine should receive pre-processed inputs.
- Eliminates any ambiguity about what the engine receives vs what the provider owns.

`RecommendationContext` is **not used** for the table → party direction. That direction receives `RestaurantTable` + `List<QueueEntry>` directly (the table IS the context in that direction).

```dart
// lib/features/recommendation/domain/recommendation_context.dart

@immutable
class RecommendationContext {
  const RecommendationContext({
    required this.partySize,
    required this.waitingMinutes,
    required this.queuePosition,
    required this.availableTables,
    required this.partiallyOccupiedTables,
    this.customerPreferences = const CustomerPreferences.defaults(),
  });

  final int partySize;
  final int waitingMinutes;         // computed by provider as DateTime.now().difference(joinedAt).inMinutes
  final int queuePosition;
  final List<RestaurantTable> availableTables;           // status == available
  final List<RestaurantTable> partiallyOccupiedTables;  // status == occupied AND occupancy > 0 AND occupancy < capacity
  // reserved and blocked tables are excluded at the provider level
  final CustomerPreferences customerPreferences;
}
```

**Provider constructs `RecommendationContext`:**
```dart
// Inside partyRecommendationProvider (see §7.4):
final waitingMinutes = DateTime.now().difference(party.joinedAt).inMinutes;
final context = RecommendationContext(
  partySize: party.partySize,
  waitingMinutes: waitingMinutes,
  queuePosition: party.queuePosition,
  availableTables: tables.where((t) => t.status == TableStatus.available).toList(),
  partiallyOccupiedTables: tables.where((t) => t.isPartiallyOccupied).toList(),
  customerPreferences: party.customerPreferences ?? const CustomerPreferences.defaults(),
);
return engine.computeRecommendationsForParty(context: context);
```

### 4.7 `RecommendationFactors`

**[C-1] Floating-point equality assert replaced with epsilon comparison.**

```dart
// lib/features/recommendation/domain/recommendation_factors.dart

@immutable
class RecommendationFactors {
  const RecommendationFactors({
    this.capacityFitWeight = 0.40,
    this.occupancyWeight   = 0.25,
    this.waitTimeWeight    = 0.15,
    this.adjacencyWeight   = 0.15,
    this.fairnessWeight    = 0.05,
  }) : assert(
         // C-1: IEEE 754 double arithmetic cannot represent 0.40 + 0.25 + 0.15 + 0.15 + 0.05
         // as exactly 1.0. Using == 1.0 fails in debug mode even for the default values.
         // Epsilon comparison (tolerance 0.001) accepts any sum within rounding error.
         (capacityFitWeight + occupancyWeight + waitTimeWeight +
          adjacencyWeight + fairnessWeight - 1.0).abs() < 0.001,
         'Factor weights must sum to 1.0 (within floating-point tolerance)',
       );

  final double capacityFitWeight;
  final double occupancyWeight;
  final double waitTimeWeight;
  final double adjacencyWeight;
  final double fairnessWeight;

  // Future factors are added as new named parameters with default 0.0,
  // and other weights reduced proportionally. The scoring pipeline does not change.
}
```

### 4.8 `RecommendationResult` — Removed

**[SMP] `RecommendationResult` wrapper removed.**

The wrapper carried `sourceId`, `sourceType`, and `computedAt` — none of which are consumed by any provider, highlight map, or widget. It added an indirection layer with no benefit.

**Replacement:**
- `partyRecommendationProvider` returns `List<TableRecommendation>?` directly.
- `tableRecommendationProvider` returns `List<QueuePartyRecommendation>?` directly.
- Both return `null` when no selection is active.

### 4.9 `highlight_models.dart` — merged highlight types

**[SMP] `TableHighlight` and `QueueHighlight` combined in a single file.**

```dart
// lib/features/recommendation/domain/highlight_models.dart

@immutable
class TableHighlight {
  const TableHighlight({
    required this.type,
    required this.score,
    required this.reason,
    this.combinedPartnerIds = const [],
  });

  final RecommendationType type;
  final int score;
  final String reason;
  final List<String> combinedPartnerIds; // Firestore doc IDs of partner tables in a combo

  bool get isGreen  => type == RecommendationType.exactMatch;
  bool get isOrange => type == RecommendationType.sharedMatch;
  bool get isYellow => type == RecommendationType.largerAlternative;
  bool get isBlue   => type == RecommendationType.combinedTable;
}

@immutable
class QueueHighlight {
  const QueueHighlight({
    required this.type,
    required this.score,
    required this.reason,
  });

  final RecommendationType type;
  final int score;
  final String reason;

  bool get isGreen  => type == RecommendationType.exactMatch;
  bool get isYellow => type == RecommendationType.largerAlternative;
}
```

**[C-6] `TableHighlight` is only ever created for non-suppressed recommendations.** The `tableHighlightMapProvider` (§7.5) filters out suppressed entries before building the map. There is no `isSuppressed` field on `TableHighlight` because suppressed entries never reach the highlight layer.

### 4.10 `RestaurantTable` Extended Fields

**Add to existing `RestaurantTable` class:**
```dart
final String floorId;                  // default: 'F1'
final List<String> adjacentTableIds;   // default: [] — Firestore doc IDs only
final int x;                           // default: 0
final int y;                           // default: 0
final int occupancy;                   // default: 0 — actual seated guest count, CF-written only
```

**Add to `fromMap`:**
```dart
floorId: data['floorId'] as String? ?? 'F1',
adjacentTableIds: List<String>.from(data['adjacentTableIds'] as List? ?? []),
x: data['x'] as int? ?? 0,
y: data['y'] as int? ?? 0,
occupancy: data['occupancy'] as int? ?? 0,
```

**Add to `toMap`:**
```dart
'floorId': floorId,
'adjacentTableIds': adjacentTableIds,
'x': x,
'y': y,
'occupancy': occupancy,
```

**Computed getters (replace `occupiedCountFor` lambda in the dashboard):**
```dart
int get remainingSeats => capacity - occupancy;
bool get isPartiallyOccupied =>
    status == TableStatus.occupied && occupancy > 0 && occupancy < capacity;
```

### 4.11 `QueueEntry` Extended Field

**Add to existing `QueueEntry` class:**
```dart
final CustomerPreferences? customerPreferences;  // null = anyAvailable
```

**Add to `fromMap`:**
```dart
customerPreferences: data['customerPreferences'] != null
    ? CustomerPreferences.fromMap(
        data['customerPreferences'] as Map<String, dynamic>)
    : null,
```

**Add to `toMap`:**
```dart
'customerPreferences': customerPreferences?.toMap(),
```

**Computed getter:**
```dart
bool get prefersEmptyTableOnly =>
    customerPreferences?.seatingPreference == SeatingPreference.emptyTableOnly;
```

---

## 5. Repository Layer Design

### 5.1 `TableRepository` — No New Methods Required

The existing `watchTables()` stream returns all tables for the branch. After `RestaurantTable` is extended with `floorId`, `adjacentTableIds`, and `occupancy`, the engine has all it needs from the same stream.

**Do not add a separate `watchAdjacentTables()` method.** The adjacency graph is derived from `adjacentTableIds` fields in the existing stream.

### 5.2 `QueueRepository` — No New Methods Required

The existing `watchTodayQueue()` returns all entries. The engine filters to `waiting` entries internally via the `RecommendationContext` which the provider builds.

### 5.3 Removing Mock Repositories

**`MockTableRepository`** (lines 225–307 in `table_repository.dart`): **Remove entirely.**

**`MockQueueRepository`** (lines 80–134 in `queue_repository.dart`): **Remove entirely.**

**`tableRepositoryProvider`** (line 301): Change to always return `FirebaseTableRepository()`.

```dart
// Before:
final tableRepositoryProvider = Provider<TableRepository>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) return FirebaseTableRepository();
  return MockTableRepository();
});

// After:
final tableRepositoryProvider = Provider<TableRepository>((ref) {
  return FirebaseTableRepository();
});
```

Same change for `queueRepositoryProvider`. After this change, all developers must run Firebase Emulator or use the EZQ dev project.

---

## 6. `TableRecommendationEngine` Architecture

### 6.1 Class Interface

**[AR-2] Engine accepts `RecommendationContext` for the party direction.**
**[SMP] Return types are direct lists — no `RecommendationResult` wrapper.**

```dart
// lib/features/recommendation/domain/table_recommendation_engine.dart

class TableRecommendationEngine {
  const TableRecommendationEngine({
    this.factors = const RecommendationFactors(),
  });

  final RecommendationFactors factors;

  /// Direction: queue party selected → table recommendations.
  /// Input: RecommendationContext (built by provider from QueueEntry + live table stream).
  /// Output: ranked list — EXACT_MATCH first, then SHARED_MATCH (non-suppressed, then suppressed),
  ///         then LARGER_ALTERNATIVE, then COMBINED_TABLE.
  /// Never returns an empty list (fallback entry guaranteed).
  List<TableRecommendation> computeRecommendationsForParty({
    required RecommendationContext context,
  });

  /// Direction: table selected → queue party recommendations.
  /// Input: the selected RestaurantTable + all waiting QueueEntries.
  /// Output: ranked list — EXACT_MATCH first, then LARGER_ALTERNATIVE.
  /// Returns empty list when no waiting party fits the table.
  List<QueuePartyRecommendation> computeRecommendationsForTable({
    required RestaurantTable table,
    required List<QueueEntry> waitingParties,
  });

  /// F4: combined table search.
  /// Called internally by computeRecommendationsForParty when no single-table candidates exist.
  /// Also callable directly for isolated testing.
  List<CombinedTableRecommendation> computeCombinedTableOptions({
    required int partySize,
    required List<RestaurantTable> availableTables,
  });
}
```

**Engine is stateless.** No side effects. Safe to provide as a Riverpod `Provider` singleton.

### 6.2 Party → Table Algorithm (F3)

The provider pre-partitions tables into `context.availableTables` and `context.partiallyOccupiedTables` before calling the engine. The engine does not read `allTables` directly.

**Step 1 — Classify and score available tables:**
```
for each table in context.availableTables:
  if table.capacity == context.partySize → type = exactMatch
  if table.capacity >  context.partySize → type = largerAlternative
  // table.capacity < context.partySize → skip (cannot fit)

  capacityFitScore  = max(0, 100 - (table.capacity - context.partySize) * 15)
    // 100 for exact fit; -15 per extra seat
  occupancyScore    = 100   // empty table
  waitTimeScore     = min(100, context.waitingMinutes * 3)
    // 3 pts per minute, capped at 100 (≈33 min wait = max score)
  adjacencyScore    = 0     // not applicable for single-table
  fairnessScore     = max(0, 100 - (context.queuePosition - 1) * 10)
    // 100 for position 1; -10 per position

  score = round(
    capacityFitScore  * factors.capacityFitWeight  +
    occupancyScore    * factors.occupancyWeight     +
    waitTimeScore     * factors.waitTimeWeight      +
    adjacencyScore    * factors.adjacencyWeight     +
    fairnessScore     * factors.fairnessWeight
  )
```

**Step 2 — Classify and score partially occupied tables:**

Tables in `context.partiallyOccupiedTables` already satisfy `status == occupied AND occupancy > 0 AND occupancy < capacity`.

```
for each table in context.partiallyOccupiedTables:
  remainingSeats = table.capacity - table.occupancy
  if remainingSeats < context.partySize → skip (cannot fit)
  type = sharedMatch

  capacityFitScore  = max(0, 100 - (remainingSeats - context.partySize) * 20)
    // 100 if remaining == partySize; -20 per extra seat beyond need
  occupancyScore    = (remainingSeats == context.partySize) ? 80 : 60
  waitTimeScore     = min(100, context.waitingMinutes * 3)
  adjacencyScore    = 0
  fairnessScore     = max(0, 100 - (context.queuePosition - 1) * 10)

  score = round(same formula)

  // [C-6] Suppression check:
  isSuppressed = context.customerPreferences.seatingPreference == SeatingPreference.emptyTableOnly
  reason = isSuppressed
      ? "Not Recommended — Customer Prefers Exclusive Table Seating"
      : (remainingSeats == context.partySize
          ? "Best Shared Seating — ${remainingSeats} Seats Available"
          : "Can Accommodate Party — ${remainingSeats} Seats Available")
```

**Step 3 — Sort within type groups:**
```
exactMatch entries         → sort by score desc
sharedMatch entries:
  non-suppressed entries   → sort by score desc
  suppressed entries       → sort by score desc, appended after non-suppressed
largerAlternative entries  → sort by score desc, then capacity asc (tiebreak)
```

**Step 4 — [C-5] Trigger F4 combined table search (corrected condition):**

```
validSharedMatch = sharedMatch entries where isSuppressed == false

if exactMatch.isEmpty AND validSharedMatch.isEmpty AND largerAlternative.isEmpty:
  combinedOptions = computeCombinedTableOptions(context.partySize, context.availableTables)
  // Convert each CombinedTableRecommendation → one TableRecommendation per constituent table
  // isSuppressed = false on all combined entries (customer preference applies only to sharedMatch)
```

**Why `validSharedMatch` is required in the trigger:**
Without it, a party with a valid shared-match table (but no empty tables) would incorrectly trigger F4, showing both an orange sharedMatch tile AND blue combined tiles. The corrected condition ensures F4 only activates when no single-table option of any type can seat the party.

**Step 5 — Build final ordered output:**
```
output = [
  ...exactMatch (sorted),
  ...sharedMatch non-suppressed (sorted by score desc),
  ...sharedMatch suppressed (sorted by score desc),
  ...largerAlternative (sorted),
  ...combinedTable (sorted by score),
]
```

**Step 6 — Fallback invariant:**

If `output` is empty (no tables exist in Firestore at all), the engine must return exactly one entry:
```
TableRecommendation(
  tableId: '',
  tableNumber: '—',
  recommendationType: largerAlternative,
  recommendationScore: 0,
  recommendationReason: "No Available Table — Notify Manager",
  availableSeats: 0, occupancy: 0, capacity: 0,
  isSuppressed: false,
)
```

### 6.3 Table → Party Algorithm (F3)

**Inputs from `RestaurantTable`:** `capacity`, `occupancy`, `remainingSeats`.

**Step 1 — Filter waiting parties:**
```
eligible = waitingParties where party.partySize <= table.remainingSeats
```

**Step 2 — Classify:**
```
for each party in eligible:
  if party.partySize == table.remainingSeats → exactMatch
  if party.partySize <  table.remainingSeats → largerAlternative
```

**Step 3 — Score:**
```
capacityFitScore  = max(0, 100 - (table.remainingSeats - party.partySize) * 15)
occupancyScore    = (party.partySize == table.remainingSeats) ? 100 : 70
waitTimeScore     = min(100, party.waitingMinutes * 3)
adjacencyScore    = 0
fairnessScore     = max(0, 100 - (party.queuePosition - 1) * 10)

score = round(weighted sum)
```

**Step 4 — Sort:**
```
exactMatch → score desc
largerAlternative → score desc
```

**Note on `party.waitingMinutes`:** the provider computes this before calling the engine, or the engine computes it inline from `party.joinedAt`. Either approach is acceptable — the key constraint is that `DateTime.now()` is called once per engine invocation, not once per party in the loop.

**Return invariant:** if 2+ parties are eligible, output contains at least 2 entries. If exactly 1 is eligible, it is returned alone.

### 6.4 F4 Combined Table Algorithm

**Trigger condition (corrected — §6.2 Step 4):** called only when no single-table option (exactMatch, valid sharedMatch, largerAlternative) can seat the party.

**[C-3] Adjacency graph uses Firestore document IDs.**

**Step 1 — Build adjacency graph from live Firestore data:**
```
graph: Map<String, Set<String>>
  // key = Firestore document ID (table.id)
  // value = Set of adjacent Firestore document IDs

for each table in availableTables:
  validNeighborIds = table.adjacentTableIds
      .where((id) => availableTables.any((t) => t.id == id))
      // filters to only available-status neighbours; ignores reserved/occupied/blocked
  graph[table.id] = validNeighborIds.toSet()
```

**Step 2 — Find qualifying pairs (2-table combinations):**
```
pairs = []
for each table T1 in availableTables:
  for each neighborId in graph[T1.id]:
    T2 = availableTables.firstWhere((t) => t.id == neighborId)
    if T1.id < T2.id:  // canonical order avoids duplicates
      combinedCapacity = T1.capacity + T2.capacity
      if combinedCapacity >= partySize:
        pairs.add([T1, T2])
```

**Step 3 — Find qualifying triples (3-table combinations, only if no pairs qualify):**
```
if pairs.isEmpty:
  triples = []
  for each table T1:
    for each neighborId of T1 (T2):
      for each neighborId of T2 (T3, where T3 != T1):
        if unique triple (canonical order) AND combinedCapacity >= partySize:
          triples.add([T1, T2, T3])
  // 4+ table combinations not generated in MVP
  // Guard: if availableTables.length > 25, skip triple search
```

**Step 4 — Score each combination:**
```
for each combo [T1, T2, ...]:
  combinedCapacity = sum of capacities

  allMutuallyAdjacent = every pair (Ti, Tj) in combo satisfies Ti.adjacentTableIds.contains(Tj.id)
  adjacencyScore      = allMutuallyAdjacent ? 100 : 70

  waste               = combinedCapacity - partySize
  capacityWasteScore  = max(0, 100 - waste * 15)

  tablesConsumedScore = combo.length == 2 ? 100 : 60

  smallTablePenalty   = combo consumes the only available small table? -20 : 0
  fairnessBase        = max(0, 50 + smallTablePenalty)

  score = round(
    adjacencyScore     * factors.adjacencyWeight     +
    capacityWasteScore * factors.capacityFitWeight   +
    tablesConsumedScore* factors.occupancyWeight      +
    0                  * factors.waitTimeWeight       +
    fairnessBase       * factors.fairnessWeight
  )
  // Clamp to [0, 100]
```

**Step 5 — Rank and limit:**
```
Sort by score desc
Return top 3 combinations
```

**Step 6 — Convert to `TableRecommendation` entries:**
```
for each CombinedTableRecommendation combo:
  tableNumbers = combo.tableIds.map((id) → table.tableNumber for that id).join(' + ')
  reason = "Combined Tables ${tableNumbers} — Capacity ${combo.combinedCapacity}"
  for each tableId in combo.tableIds:
    emit TableRecommendation(
      tableId: tableId,
      recommendationType: combinedTable,
      combinedTableIds: combo.tableIds,   // all Firestore doc IDs in the set
      recommendationReason: reason,
      isSuppressed: false,
      ...
    )
```

All tiles in the same combination share the same `recommendationReason` and `combinedTableIds`. The UI identifies combination groups via `combinedTableIds` equality.

---

## 7. Riverpod Provider Architecture

### 7.1 Selection State Providers

```dart
// lib/features/recommendation/providers/selection_providers.dart

/// ID of the currently selected queue party. null = no selection.
final selectedQueueEntryIdProvider = StateProvider<String?>((ref) => null);

/// ID of the currently selected table. null = no selection.
final selectedTableIdProvider = StateProvider<String?>((ref) => null);
```

**Mutual exclusion rule:** when setting one, always clear the other in the same write batch. Enforced in the action handler (UI widget), not in the provider itself.

```dart
// Pattern for queue party selection (in widget):
void _onQueuePartyTapped(String entryId) {
  final isDeselecting = ref.read(selectedQueueEntryIdProvider) == entryId;
  ref.read(selectedQueueEntryIdProvider.notifier).state =
      isDeselecting ? null : entryId;
  ref.read(selectedTableIdProvider.notifier).state = null;
}

// Pattern for table selection (in widget):
void _onTableTapped(String tableId) {
  final isDeselecting = ref.read(selectedTableIdProvider) == tableId;
  ref.read(selectedTableIdProvider.notifier).state =
      isDeselecting ? null : tableId;
  ref.read(selectedQueueEntryIdProvider.notifier).state = null;
}
```

### 7.2 Stream Providers

These replace the current `StreamBuilder` calls in `AdminDashboardScreen`.

```dart
// Value class for family key — == and hashCode required to prevent stream restarts:
@immutable
class BranchRef {
  const BranchRef({required this.restaurantId, required this.branchId});
  final String restaurantId;
  final String branchId;

  @override
  bool operator ==(Object other) =>
      other is BranchRef &&
      other.restaurantId == restaurantId &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(restaurantId, branchId);
}

// Cache BranchRef as a final field in widget state — never construct inline in build():
// late final _branch = BranchRef(restaurantId: widget.restaurantId, branchId: widget.branchId);

final tablesStreamProvider =
    StreamProvider.autoDispose.family<List<RestaurantTable>, BranchRef>(
  (ref, branch) => ref.read(tableRepositoryProvider).watchTables(
    restaurantId: branch.restaurantId,
    branchId: branch.branchId,
  ),
);

final queueStreamProvider =
    StreamProvider.autoDispose.family<List<QueueEntry>, BranchRef>(
  (ref, branch) => ref.read(queueRepositoryProvider).watchTodayQueue(
    restaurantId: branch.restaurantId,
    branchId: branch.branchId,
  ),
);
```

**Warning:** constructing `BranchRef(...)` inline in `build()` without caching creates a new object every rebuild. Even with `==`/`hashCode` implemented, Riverpod family key comparison occurs before provider lookup. Cache `_branch` as a `late final` in `initState` or as a widget field.

### 7.3 Recommendation Engine Provider

```dart
final recommendationEngineProvider = Provider<TableRecommendationEngine>((ref) {
  return const TableRecommendationEngine();
  // Stateless singleton. Factors use defaults.
});
```

### 7.4 Recommendation Providers

**[C-2] No state mutation inside any provider. Auto-clear logic lives in `AdminDashboardScreen` via `ref.listen` (§8.3).**
**[SMP] Return types are direct lists — no `RecommendationResult` wrapper.**

```dart
// lib/features/recommendation/providers/recommendation_providers.dart

/// Active when a queue party is selected. null when no selection.
/// Returns null (not empty list) when streams are loading.
final partyRecommendationProvider =
    Provider.autoDispose.family<List<TableRecommendation>?, BranchRef>((ref, branch) {
  final selectedId = ref.watch(selectedQueueEntryIdProvider);
  if (selectedId == null) return null;

  final tablesAsync = ref.watch(tablesStreamProvider(branch));
  final queueAsync  = ref.watch(queueStreamProvider(branch));
  final engine      = ref.read(recommendationEngineProvider);

  final tables = tablesAsync.valueOrNull;
  final queue  = queueAsync.valueOrNull;
  if (tables == null || queue == null) return null;

  final party = queue.firstWhereOrNull(
      (e) => e.id == selectedId && e.status == QueueStatus.waiting);
  if (party == null) return null;
  // [C-2] Party not found = do NOT mutate selectedQueueEntryIdProvider here.
  // Auto-clear is handled by ref.listen in AdminDashboardScreen (see §8.3).

  final waitingMinutes = DateTime.now().difference(party.joinedAt).inMinutes;
  final context = RecommendationContext(
    partySize: party.partySize,
    waitingMinutes: waitingMinutes,
    queuePosition: party.queuePosition,
    availableTables: tables
        .where((t) => t.status == TableStatus.available).toList(),
    partiallyOccupiedTables: tables
        .where((t) => t.isPartiallyOccupied).toList(),
    customerPreferences:
        party.customerPreferences ?? const CustomerPreferences.defaults(),
  );

  return engine.computeRecommendationsForParty(context: context);
});

/// Active when a table is selected. null when no selection.
final tableRecommendationProvider =
    Provider.autoDispose.family<List<QueuePartyRecommendation>?, BranchRef>((ref, branch) {
  final selectedId = ref.watch(selectedTableIdProvider);
  if (selectedId == null) return null;

  final tablesAsync = ref.watch(tablesStreamProvider(branch));
  final queueAsync  = ref.watch(queueStreamProvider(branch));
  final engine      = ref.read(recommendationEngineProvider);

  final tables = tablesAsync.valueOrNull;
  final queue  = queueAsync.valueOrNull;
  if (tables == null || queue == null) return null;

  final table = tables.firstWhereOrNull((t) => t.id == selectedId);
  if (table == null) return null;
  // [C-2] Table not found = do NOT mutate selectedTableIdProvider here.
  // Auto-clear handled by ref.listen in AdminDashboardScreen.

  final waitingParties =
      queue.where((e) => e.status == QueueStatus.waiting).toList();
  return engine.computeRecommendationsForTable(
    table: table,
    waitingParties: waitingParties,
  );
});
```

### 7.5 Highlight Map Providers

**[C-6] Suppressed entries are excluded from both highlight maps. They appear only in the Reserve dropdown (§9.3).**

```dart
/// Map of tableId → TableHighlight.
/// Consumed by TableGrid / TableTile widgets.
/// Empty map when no queue party is selected or streams are loading.
/// [C-6] Only non-suppressed entries create map entries.
final tableHighlightMapProvider =
    Provider.autoDispose.family<Map<String, TableHighlight>, BranchRef>((ref, branch) {
  final recs = ref.watch(partyRecommendationProvider(branch));
  if (recs == null) return const {};

  final map = <String, TableHighlight>{};
  for (final rec in recs.where((r) => !r.isSuppressed)) {
    map[rec.tableId] = TableHighlight(
      type: rec.recommendationType,
      score: rec.recommendationScore,
      reason: rec.recommendationReason,
      combinedPartnerIds: rec.combinedTableIds
              ?.where((id) => id != rec.tableId)
              .toList() ??
          [],
    );
  }
  return map;
});

/// Map of queueEntryId → QueueHighlight.
/// Consumed by QueuePanel / QueueCard widgets.
/// Empty map when no table is selected or streams are loading.
final queueHighlightMapProvider =
    Provider.autoDispose.family<Map<String, QueueHighlight>, BranchRef>((ref, branch) {
  final recs = ref.watch(tableRecommendationProvider(branch));
  if (recs == null) return const {};

  return {
    for (final rec in recs)
      rec.queueEntryId: QueueHighlight(
        type: rec.recommendationType,
        score: rec.recommendationScore,
        reason: rec.recommendationReason,
      ),
  };
});
```

### 7.6 Reserve Dropdown — No Dedicated Provider

**[SMP] `reserveDropdownProvider` removed.** The `ReserveTableDialog` widget reads `partyRecommendationProvider(branch)` directly and renders the list in engine output order.

- Non-suppressed entries: selectable, display emoji tag + reason.
- Suppressed entries: **disabled, greyed-out, non-interactive**, display reason "Customer Prefers Exclusive Table Seating". Appear below a visual separator.

The engine output order is the canonical dropdown order. No widget-level re-sort is permitted.

### 7.7 Provider Dependency Graph

```
Firestore
  │
  ├── tablesStreamProvider(branch)  ──────────────────────────────────────────┐
  │                                                                            │
  └── queueStreamProvider(branch)  ──────────────────────────────────────────┤
                                                                               │
selectedQueueEntryIdProvider ──────► partyRecommendationProvider(branch) ─────┤──► tableHighlightMapProvider(branch)
                                     [List<TableRecommendation>? or null]     │         consumed by: TableGrid, TableTile
                                                                               │    ──► ReserveTableDialog (reads directly)
selectedTableIdProvider ────────────► tableRecommendationProvider(branch) ────┘──► queueHighlightMapProvider(branch)
                                     [List<QueuePartyRecommendation>? or null]         consumed by: QueuePanel, QueueCard

recommendationEngineProvider ────────► both recommendation providers

AdminDashboardScreen ──────────────── ref.listen(queueStreamProvider)  ──► auto-clear selectedQueueEntryIdProvider
                     └───────────── ref.listen(tablesStreamProvider)   ──► auto-clear selectedTableIdProvider
```

**Key properties:**
- Both recommendation providers return `null` immediately when the selection is `null`. The engine is never called when nothing is selected.
- `tableHighlightMapProvider` skips suppressed entries — no orange border for preference-blocked tables.
- `reserveDropdownProvider` does not exist — dialogs read `partyRecommendationProvider` directly.
- Auto-clear lives in `AdminDashboardScreen`, not in the providers (C-2 fix).

---

## 8. Firebase Stream Design

### 8.1 How Table Updates Propagate

```
Manager seats party at T4 → confirmSeated Cloud Function runs
  → Firestore writes: T4.status = 'occupied', T4.occupancy = partySize
  → tablesStreamProvider emits new List<RestaurantTable>
    → partyRecommendationProvider recomputes (if party selected):
        T4 was EXACT_MATCH (available) → now occupied → removed from availableTables
        tableHighlightMapProvider: T4 entry removed from map
        TableGrid rebuilds: T4 tile loses green highlight, shows occupied state
    → tableRecommendationProvider recomputes (if table selected):
        T4 still exists in stream with new status/occupancy
        Recommendations update for matched parties
    → ReserveTableDialog (if open): T4 removed from list (occupied, not available)
```

### 8.2 How Queue Updates Propagate

```
Party A joins queue → joinQueue Cloud Function creates new queueEntry
  → queueStreamProvider emits updated List<QueueEntry>
    → If Party B (size 4) was selected:
        partyRecommendationProvider rebuilds context with updated queue data
        B's queuePosition may have changed → fairnessScore changes
        tableHighlightMapProvider may update
    → If a table is selected:
        tableRecommendationProvider rebuilds — Party A now appears in candidates
        queueHighlightMapProvider may add Party A with appropriate highlight
```

### 8.3 Selection Auto-Clear — `ref.listen` in `AdminDashboardScreen`

**[C-2] Providers do not mutate selection state. Auto-clear is centralised in `AdminDashboardScreen`.**

```dart
// In AdminDashboardScreen build() or initState() — using ref.listen:

// Auto-clear party selection when the selected party leaves the waiting list:
ref.listen(queueStreamProvider(branch), (previous, next) {
  final selectedId = ref.read(selectedQueueEntryIdProvider);
  if (selectedId == null) return;
  final queue = next.valueOrNull;
  if (queue == null) return;
  final stillActive = queue.any(
      (e) => e.id == selectedId && e.status == QueueStatus.waiting);
  if (!stillActive) {
    ref.read(selectedQueueEntryIdProvider.notifier).state = null;
  }
});

// Auto-clear table selection when the selected table is removed from the stream:
ref.listen(tablesStreamProvider(branch), (previous, next) {
  final selectedId = ref.read(selectedTableIdProvider);
  if (selectedId == null) return;
  final tables = next.valueOrNull;
  if (tables == null) return;
  final stillPresent = tables.any((t) => t.id == selectedId);
  if (!stillPresent) {
    ref.read(selectedTableIdProvider.notifier).state = null;
  }
});
```

**Why `ref.listen` in the widget, not inside the provider:**
Riverpod 2.x prohibits providers from mutating other providers during their synchronous build function. `ref.listen` in a `ConsumerWidget` runs asynchronously after the build phase, which is a legal side-effect site. This pattern is the idiomatic Riverpod approach for cross-provider reactions.

### 8.4 Preventing Unnecessary Recomputation

**Guard 1 — Early null return:** Both recommendation providers return `null` immediately when the selected ID is `null`. Engine is never called when nothing is selected.

**Guard 2 — `autoDispose`:** All recommendation and highlight providers dispose when the dashboard is not in the widget tree. No background computation during navigation.

**Guard 3 — Engine is O(n log n).** For a typical restaurant (10–30 tables, 10–30 waiting parties), each recomputation completes in < 1ms. No debouncing or memoization required for MVP.

**Guard 4 — `BranchRef` equality prevents stream restart.** If `BranchRef` is cached (not constructed inline in `build()`), the family provider key is stable. The stream is not restarted on widget rebuilds.

### 8.5 Stream Lifecycle

`StreamProvider.autoDispose.family` ensures:
- Stream starts when `AdminDashboardScreen` enters the tree.
- Stream stops (Firestore listener cancelled) when `AdminDashboardScreen` leaves the tree.
- Keyed by `BranchRef` — multiple branches do not share streams.

---

## 9. UI Interaction Flows

No UI code. Architecture only.

### 9.1 Table Card Click Flow

```
[Manager taps table card T4]
  → _onTableTapped(T4.id) called in TableGrid widget:
      isDeselecting = (selectedTableIdProvider == T4.id)
      selectedTableIdProvider.notifier.state = isDeselecting ? null : T4.id
      selectedQueueEntryIdProvider.notifier.state = null

  → tableRecommendationProvider(branch) recomputes:
      table = T4 (from tablesStreamProvider)
      waitingParties = waiting entries from queueStreamProvider
      engine.computeRecommendationsForTable(T4, waitingParties)
      → [Party A (exactMatch, score 92), Party B (largerAlternative, score 71)]

  → queueHighlightMapProvider(branch) recomputes:
      { 'partyA_id': QueueHighlight(exactMatch, 92, ...), 'partyB_id': QueueHighlight(largerAlternative, 71, ...) }

  → QueuePanel rebuilds:
      Party A card: green border + green glow
      Party B card: yellow border
      All other party cards: no highlight

  → tableHighlightMapProvider(branch): empty (no party selected)
  → ReserveTableDialog: not applicable (no party selected)
  → T4 tile: shows "selected" state (e.g., distinct teal border)
```

### 9.2 Queue Party Card Click Flow

```
[Manager taps queue party card for Party A (partySize=4, anyAvailable preference)]
  → _onQueuePartyTapped(A.id) in QueuePanel:
      selectedQueueEntryIdProvider.notifier.state = A.id
      selectedTableIdProvider.notifier.state = null

  → partyRecommendationProvider(branch) recomputes:
      Provider builds RecommendationContext for Party A:
        availableTables    = [T2 (cap4), T4 (cap6)]
        partiallyOccupied  = [T3 (cap4, occ2, remaining2 < 4 → skipped in engine)]
      engine.computeRecommendationsForParty(context)
      → [T2(exactMatch, score88, isSuppressed:false),
         T4(largerAlternative, score65, isSuppressed:false)]

  → tableHighlightMapProvider: { 'T2': green, 'T4': yellow }
  → TableGrid: T2 green highlight, T4 yellow highlight, T1/T3 none
  → ReserveTableDialog data: [T2 🟢, T4 🟡]  (read from partyRecommendationProvider)
```

### 9.3 Queue Party Click — EMPTY_TABLE_ONLY Preference

```
[Manager taps party card for Party B (partySize=2, EMPTY_TABLE_ONLY preference)]
  → partyRecommendationProvider recomputes:
      availableTables   = [T1 (cap2, avail)]
      partiallyOccupied = [T3 (cap4, occ2, remaining2)]
      engine processes T1 → exactMatch, isSuppressed:false
      engine processes T3 → sharedMatch, isSuppressed:true
        reason = "Not Recommended — Customer Prefers Exclusive Table Seating"
      output = [T1(exactMatch, isSuppressed:false), T3(sharedMatch, isSuppressed:true)]

  → tableHighlightMapProvider: [C-6] only non-suppressed entries:
      { 'T1': green }        ← T3 excluded from highlight map
  → TableGrid: T1 green. T3 NO orange highlight (not in map).

  → ReserveTableDialog reads partyRecommendationProvider directly:
      SELECTABLE:  T1 🟢 Exact Capacity Match
      ── separator ──
      DISABLED:    T3 ⬜ Customer Prefers Exclusive Table Seating
```

### 9.4 Reserve Dropdown Flow

```
[Manager opens ReserveTableDialog for Party A (T2 green, T4 yellow in highlights)]
  → Dialog reads partyRecommendationProvider(branch) directly (no separate provider)
  → Non-suppressed entries rendered in engine order: T2 (🟢), T4 (🟡)
  → Suppressed entries (if any) rendered as disabled below separator
  → Each selectable item: "${tableNumber} · ${capacity} cap · ${occupancy} occ · ${emoji} ${typeLabel}"

[Manager selects T2]
  → tableRepositoryProvider.reserveTable(restaurantId, branchId, A.id, T2.id) called
  → On success:
      selectedQueueEntryIdProvider.notifier.state = null  (cleared in success handler)
      tableHighlightMapProvider → empty map → all highlights clear
  → Firestore update propagates: T2 and A status update
  → Streams emit → TableGrid and QueuePanel rebuild automatically
```

### 9.5 Combined Table Flow (F4)

```
[Manager taps Party X (partySize=8). All single tables cap 4, no cap 6+.]
  → partyRecommendationProvider recomputes:
      availableTables = [T3(cap4), T4(cap4), T5(cap4), T6(cap4)]
      Step 1: no table.capacity >= 8 → no exactMatch, no largerAlternative
      partiallyOccupied = [] (all occupied tables full)
      validSharedMatch = []
      [C-5] trigger: exactMatch.isEmpty AND validSharedMatch.isEmpty AND largerAlternative.isEmpty
        → computeCombinedTableOptions(8, availableTables) called
        → graph built from adjacentTableIds (Firestore doc IDs) [C-3]
        → T3+T4 (4+4=8, adjacent, score 85), T5+T6 (4+4=8, adjacent, score 72) found
        → Emitted as 4 TableRecommendation entries:
            T3: (combinedTable, 85, isSuppressed:false, combinedTableIds:[T3.id, T4.id])
            T4: (combinedTable, 85, isSuppressed:false, combinedTableIds:[T3.id, T4.id])
            T5: (combinedTable, 72, isSuppressed:false, combinedTableIds:[T5.id, T6.id])
            T6: (combinedTable, 72, isSuppressed:false, combinedTableIds:[T5.id, T6.id])

  → tableHighlightMapProvider: all 4 entries in map (none suppressed)
      T3, T4: blue border + blue glow (score 85)
      T5, T6: blue border + blue glow (score 72)

  → ReserveTableDialog data:
      [🔵 T3 + T4 — Combined (cap 8), 🔵 T5 + T6 — Combined (cap 8)]

  → MVP: combined-table dropdown entry is informational.
    Actual reservation requires two sequential calls: reserveTable(T3), reserveTable(T4).
    The ReserveTableDialog must show a confirmation step:
    "Reserve T3 and T4 together for Party X? (two tables will be reserved)"
    The button is enabled but documented as non-atomic.
```

### 9.6 Mid-Session Firestore Update

```
[Party A (size 4) selected → T2 highlighted green]
[Another session reserves T2 via Firestore]

  → tablesStreamProvider emits: T2.status = 'reserved'
  → partyRecommendationProvider recomputes:
      T2 no longer in availableTables (status = reserved)
      Output: [T4 (largerAlternative, score 65)]
  → tableHighlightMapProvider: { 'T4': yellow } — T2 removed
  → TableGrid: T2 loses green highlight, shows reserved state
  → ReserveTableDialog (if open): T2 removed from selectable list
  → No manual refresh. Automatic.
```

### 9.7 Deselection Conditions

| Trigger | Action |
|---|---|
| Re-tap currently selected card | Set selection provider to null → highlights clear |
| Successful reserve action | Set `selectedQueueEntryIdProvider` to null in success handler |
| Selected party's status changes (leaves `waiting`) | `ref.listen` in `AdminDashboardScreen` auto-clears (§8.3) |
| Selected table removed from Firestore stream | `ref.listen` auto-clears `selectedTableIdProvider` |
| Navigation away from dashboard | `autoDispose` cleans all providers |

---

## 10. Test Scenarios

All scenarios use Firebase Emulator or EZQ development project. No mock data.

### Emulator Seed Prerequisites

Before running any test:
1. All table documents must have `floorId`, `adjacentTableIds`, `x`, `y`, `occupancy` fields.
2. `adjacentTableIds` must contain **Firestore document IDs**, not `tableNumber` strings.
3. `adjacentTableIds` must be bidirectional: if T4.adjacentTableIds contains T5.id, then T5.adjacentTableIds must contain T4.id.
4. At least one restaurant + branch must exist with tables seeded.
5. For SHARED_MATCH tests: `confirmSeated` Cloud Function must write `occupancy`. Verify this before running F3-03, F3-04, F3-09, F3-10.

---

### F3 Test Scenarios

**F3-01 — Exact match, single table**
- Seed: Party size 4 (anyAvailable). T1 (cap 4, status available, occupancy 0). T2 (cap 6, status available, occupancy 0).
- Action: Tap Party card.
- Expected: `tableHighlightMapProvider` has T1 (green) and T2 (yellow). Exactly 2 entries.
- Verify: No suppressed entries. No combined table entries.

**F3-02 — Exact match, multiple tables same capacity**
- Seed: Party size 2 (qpos 1, joinedAt 20min ago). T1 (cap 2, avail). T2 (cap 2, avail).
- Expected: Both T1 and T2 green (exactMatch). Dropdown shows both. Ranked by score — verify scores match formula: T1 and T2 have identical capacityFit, occupancy, wait, adjacency scores; fairnessScore differs only if sortOrder differs. Score tie acceptable.

**F3-03 — Shared seating, remaining equals party size**
- Prerequisite: `confirmSeated` Cloud Function writes `occupancy`. (§3.4)
- Seed: Party size 2 (anyAvailable). T1 (cap 4, occupied, occupancy 2 → remaining 2). T2 (cap 2, avail, occupancy 0).
- Expected: T2 → green (exactMatch). T1 → orange (sharedMatch, reason "Best Shared Seating — 2 Seats Available"). `tableHighlightMapProvider` has 2 entries, both non-suppressed.

**F3-04 — Customer prefers empty table — shared seating suppressed from highlights**
- Seed: Party size 2, seatingPreference = EMPTY_TABLE_ONLY. T1 (cap 4, occupied, occupancy 2, remaining 2). T2 (cap 2, avail).
- Expected:
  - `tableHighlightMapProvider` has **1 entry**: T2 (green). T1 is **not in the map** — no orange border.
  - `partyRecommendationProvider` output has **2 entries**: T2 (isSuppressed:false), T1 (isSuppressed:true).
  - ReserveTableDialog: T2 selectable (🟢). Separator. T1 disabled (reason: "Customer Prefers Exclusive Table Seating").
- Verify: T1 tile receives no highlight in TableGrid.

**F3-05 — Only larger empty tables available**
- Seed: Party size 2. T1 (cap 4, avail). T2 (cap 6, avail).
- Expected: T1 yellow (capacityFitScore higher, waste=2). T2 yellow (lower score, waste=4). T1 ranked first in dropdown.

**F3-06 — [C-5] Valid shared match prevents combined table trigger**
- Seed: Party size 4. T1 (cap 4, occupied, occupancy 0 — ← invalid, occupancy must be > 0 for partial). T2 (cap 4, occupied, occupancy 2, remaining 2 — can fit 2 not 4, skipped). T3 (cap 6, occupied, occupancy 2, remaining 4 — fits exactly 4). No empty tables.
- Expected: T3 is valid sharedMatch (remaining 4 == partySize 4, isSuppressed false). `validSharedMatch.isEmpty` is false. Combined table search NOT triggered. Output: [T3 (orange)]. No blue highlights.
- Contrast: If T3 were unavailable, combined table search would trigger.

**F3-07 — No eligible tables at all**
- Seed: Party size 4. All tables occupied with full occupancy (occupancy == capacity). No adjacency.
- Expected: Engine returns 1 fallback entry: reason "No Available Table — Notify Manager", score 0, isSuppressed false, type largerAlternative. Zero highlights. ReserveTableDialog shows message entry (non-selectable).

**F3-08 — Table click: exact match in queue**
- Seed: T1 (cap 4, available). Queue: Party A (size 4, waiting, qpos 1). Party B (size 2, waiting, qpos 2).
- Action: Tap T1 table card.
- Expected: `queueHighlightMapProvider` has 2 entries. Party A: green (exactMatch — size 4 == remaining 4). Party B: yellow (largerAlternative — size 2 < remaining 4). T1 shows "selected" state.

**F3-09 — Table click: multiple exact matches, ranked by wait time**
- Seed: T1 (cap 4, avail). Party A (size 4, wait 30min, qpos 2). Party B (size 4, wait 10min, qpos 1).
- Expected: Both green. Compute scores using formula — Party A has higher waitTimeScore (90 vs 30), Party B has higher fairnessScore (90 vs 80). Net result: Party A ranks first if waitTimeScore contribution (0.15 * 60-point gap = 9 points) outweighs fairnessScore contribution (0.05 * 10-point gap = 0.5 points). Party A ranks first. Verify.

**F3-10 — Table click: partially occupied table**
- Seed: T1 (cap 4, occupied, occupancy 2, remaining 2). Queue: Party X (size 2, waiting). Party Y (size 3, waiting).
- Action: Tap T1.
- Expected: Party X highlighted (size 2 ≤ remaining 2). Party Y not highlighted (3 > 2). Only Party X in queue highlight map.

**F3-11 — Reserve dropdown order matches table highlights**
- Seed: Party size 2 (anyAvailable). T1 (cap 2, avail). T2 (cap 4, occ 2, remaining 2). T3 (cap 4, avail).
- Expected highlights: T1 green, T2 orange, T3 yellow.
- Expected dropdown: T1 (🟢 first), T2 (🟠 second), T3 (🟡 third). No re-sort.

**F3-12 — Firestore status change removes stale highlight**
- Seed: Party A selected. T2 highlighted green (exactMatch, available).
- Action: Set T2.status = 'reserved' in emulator.
- Expected: Within 1 Firestore stream cycle (< 2s): T2 loses green highlight automatically. T2 tile shows reserved state. No manual refresh.

**F3-13 — ref.listen auto-clears party selection on status change**
- Seed: Party A selected (waiting). Set A.status = 'seated' in emulator.
- Expected: `ref.listen` in AdminDashboardScreen fires. `selectedQueueEntryIdProvider` set to null. All table highlights clear. `partyRecommendationProvider` returns null.

**F3-14 — Switch from table selection to party selection**
- Action: Tap T1 (queue highlights appear). Then tap Party A.
- Expected: Queue highlights from T1 clear immediately. Table highlights from Party A appear. No leftover highlights from T1.

**F3-15 — Switch from party selection to table selection**
- Action: Tap Party A (table highlights appear). Then tap T2.
- Expected: Table highlights from Party A clear. Queue highlights from T2 appear. No leftover highlights from Party A.

**F3-16 — Deselect by re-tapping**
- Action: Tap Party A. Tap Party A again.
- Expected: `selectedQueueEntryIdProvider` = null. All highlights clear. ReserveTableDialog data = null.

**F3-17 — Reserve completes — highlights clear and state updates**
- Seed: Party A selected. T2 in dropdown. Reserve succeeds.
- Expected: `selectedQueueEntryIdProvider` cleared. T2 tile updates to occupied state. Party A removed from queue panel. All highlights clear.

**F3-18 — Reserved and blocked tables excluded from recommendations**
- Seed: Party size 4. T1 (cap 4, reserved). T2 (cap 4, blocked). T3 (cap 4, available).
- Expected: T1 and T2 not in engine output. T3 green (exactMatch). T1 and T2 tiles show their respective states but no highlight border.

**F3-19 — Score formula correctness (unit test)**
- Inputs: partySize=2, capacity=2 (exactMatch), wait=20min, qpos=1.
- capacityFitScore=100, occupancyScore=100, waitTimeScore=min(100,60)=60, adjacencyScore=0, fairnessScore=100.
- Expected score = round(100*0.40 + 100*0.25 + 60*0.15 + 0*0.15 + 100*0.05) = round(40+25+9+0+5) = 79.
- Verify engine output score == 79 for this input.

**F3-20 — Reason string always non-empty**
- For every engine output in every test above: assert `recommendationReason.isNotEmpty` for every `TableRecommendation` and `QueuePartyRecommendation` in the output list. Implement as a post-condition assert in the engine itself.

---

### F4 Test Scenarios

All F4 tests require `adjacentTableIds` to contain **Firestore document IDs**. Run the bidirectionality validator (F4-18) before any other F4 test.

**F4-01 — Basic 2-table combination**
- Seed: Party size 6. T1 (cap 4, avail, adjacentTableIds:[T2.id]). T2 (cap 4, avail, adjacentTableIds:[T1.id]). T3 (cap 4, avail, adjacentTableIds:[]).
- Expected: T1+T2 recommended (combinedCap=8). Blue border on T1 and T2. T3 not highlighted (not in any adjacency). Dropdown: 🔵 "T1 + T2 — Capacity 8".

**F4-02 — Prefer smallest capacity waste**
- Seed: Party size 6. T1 (cap 4, adj T2.id), T2 (cap 4, adj T1.id) — waste=2. T3 (cap 4, adj T4.id), T4 (cap 6, adj T3.id) — waste=4. All available.
- Expected: T1+T2 ranked first (less waste → higher capacityWasteScore). T3+T4 second.

**F4-03 — Prefer fewer tables consumed**
- Seed: Party size 8. T1 (cap 4, adj T2.id), T2 (cap 4, adj T1.id) — 2 tables. T3 (cap 3, adj T4.id, T5.id), T4 (cap 3, adj T3.id, T5.id), T5 (cap 3, adj T3.id, T4.id) — 3 tables, mutually adjacent. All available.
- Expected: T1+T2 ranked first (tablesConsumedScore 100 vs 60 for 3-table set). Score difference: 100*0.25 - 60*0.25 = 10 point advantage for pair.

**F4-04 — [C-5] Combined table does NOT trigger when valid sharedMatch exists**
- Seed: Party size 6. T1 (cap 4, adj T2.id), T2 (cap 4, adj T1.id) — would be combinedCap=8. T3 (cap 8, occupied, occupancy 2, remaining 6 — valid sharedMatch). Customer preference: anyAvailable.
- Expected: T3 is valid sharedMatch (remaining 6 == partySize 6). `validSharedMatch.isEmpty` is false. Combined table search NOT triggered. Output: [T3 (orange)]. T1, T2: no blue highlight.

**F4-05 — Non-adjacent tables not combined**
- Seed: Party size 8. T1 (cap 4, adjacentTableIds:[]). T2 (cap 4, adjacentTableIds:[]). No adjacency between them.
- Expected: Engine finds no valid pairs. No COMBINED_TABLE entries. Empty COMBINED_TABLE list returned. ReserveTableDialog shows "No Available Table — Notify Manager" fallback.

**F4-06 — Single table takes priority over combination**
- Seed: Party size 6. T1 (cap 6, avail). T2 (cap 4, avail, adj T3.id). T3 (cap 4, avail, adj T2.id).
- Expected: T1 returned as LARGER_ALTERNATIVE. Combined table search not triggered (largerAlternative.isNotEmpty). T2+T3 combination not shown.

**F4-07 — [C-3] Combination respects document-ID adjacency from Firestore**
- Seed: T4 (adjacentTableIds:[T5.id, T3.id]). T5 (adjacentTableIds:[T4.id]). T3 (adjacentTableIds:[T4.id]). All available. Party size 8.
- Expected: T4+T5 found (if T4.cap + T5.cap ≥ 8). T3+T4 found (if sum ≥ 8). Both shown if qualifying.
- Live validation: Modify T4.adjacentTableIds in emulator to remove T5.id. Verify T4+T5 combination disappears from highlights on next stream emit without app restart.

**F4-08 — Occupancy change removes combination**
- Seed: T1+T2 (4+4, both available, adj to each other, doc IDs). Party size 8 selected.
- Action: Set T1.status = 'occupied', T1.occupancy = 4 in emulator.
- Expected: T1 no longer in `availableTables` (not available status). T1+T2 combination disappears. If T3+T4 exist and adjacent, they surface instead.

**F4-09 — Blue highlight on ALL tiles in a combination**
- Seed: T4+T5 combination.
- Expected: Both T4 and T5 in `tableHighlightMapProvider` with type=combinedTable. Neither suppressed. Both show blue border + blue glow.
- Verify: `tableHighlightMapProvider['T4.id'].isBlue == true`. `tableHighlightMapProvider['T5.id'].isBlue == true`.

**F4-10 — Multiple combinations in dropdown, ranked**
- Seed: Party size 8. T1+T2 (4+4, adj, score 85). T3+T4 (4+4, adj, score 70). All available.
- Expected: Dropdown: [🔵 T1+T2 first, 🔵 T3+T4 second]. Both pairs blue in TableGrid.

**F4-11 — `combinedPartnerIds` populated correctly in `TableHighlight`**
- Seed: T4+T5 combination (doc IDs: "tbl_T4_docId", "tbl_T5_docId").
- Expected: `tableHighlightMapProvider["tbl_T4_docId"].combinedPartnerIds == ["tbl_T5_docId"]`.
           `tableHighlightMapProvider["tbl_T5_docId"].combinedPartnerIds == ["tbl_T4_docId"]`.

**F4-12 — 3-table combination when no 2-table option qualifies**
- Seed: Party size 10. T1 (cap4, adj T2.id). T2 (cap4, adj T1.id, T3.id). T3 (cap4, adj T2.id). All available.
- T1+T2=8 < 10. T2+T3=8 < 10. T1+T2+T3=12 ≥ 10.
- Expected: No qualifying pairs found. Engine tries 3-table search. T1+T2+T3 surfaces as COMBINED_TABLE.

**F4-13 — Mutual adjacency bonus: triangle vs linear chain**
- Seed: Party size 10. Set A: T1 adj T2, T2 adj T3, T1 NOT adj T3 (linear chain, adjacencyScore=70). Set B: T4 adj T5, T5 adj T6, T4 adj T6 (triangle, allMutuallyAdjacent=true, adjacencyScore=100). Both sets combinedCap=12.
- Expected: Set B ranks higher (100*0.15 vs 70*0.15 = 4.5 point advantage).

**F4-14 — Queue change triggers recommendation update**
- Seed: Party X (size 8) selected. T1+T2 (4+4) recommended as combination.
- Action: New party Y (size 4) joins queue — has no effect on combinations (Y's partySize doesn't change X's recommendations).
- Action: T3 (cap 8, available) added to emulator during session.
- Expected: T3 now in `availableTables`. It qualifies as LARGER_ALTERNATIVE. Combined search not triggered (largerAlternative.isNotEmpty). T1+T2 blue highlights clear. T3 yellow highlight appears.

**F4-15 — Fairness penalty for consuming only small table**
- Seed: Party size 6. T1 (cap4, adj T2.id, only available 4-top). T2 (cap4, adj T1.id). All other waiting parties: size 1–2. No other available tables.
- Expected: T1+T2 recommended (only option). Score reflects smallTablePenalty=-20 → fairnessBase=30 instead of 50.
- Verify engine still returns T1+T2 (mandatory to show something).

**F4-16 — Adjacency data absent: graceful empty result**
- Seed: All tables have `adjacentTableIds: []`. Party size 8, no single table.
- Expected: Pairs list empty. Triples list empty. No COMBINED_TABLE entries. Fallback entry: "No Available Table — Notify Manager". No crash.

**F4-17 — Score formula correctness (unit test)**
- Known inputs: partySize=8, combinedCap=8 (waste=0), 2 tables, mutually adjacent, smallTablePenalty=0.
- adjacencyScore=100, capacityWasteScore=100, tablesConsumedScore=100, waitTimeScore=0 (N/A), fairnessBase=50.
- Expected score = round(100*0.15 + 100*0.40 + 100*0.25 + 0*0.15 + 50*0.05) = round(15+40+25+0+2.5) = round(82.5) = 83.
- Verify engine output score == 83 for this input.

**F4-18 — [C-3] Bidirectionality and document-ID validation (run first)**
- Query all table documents in the test branch.
- For every document T, for every id in T.adjacentTableIds:
  - Fetch the document with that ID.
  - Assert the document exists (fails if a tableNumber string was accidentally stored).
  - Assert T.id ∈ that document's adjacentTableIds (bidirectionality check).
- If validation fails: halt, fix seed data, re-run.

**F4-19 — Rapid selection changes produce no phantom highlights**
- Action: Rapidly tap Party A → Party B → Party C in quick succession.
- Expected: Final state reflects only Party C's recommendations. `selectedQueueEntryIdProvider` == C.id. `tableHighlightMapProvider` shows only C's table recommendations. No highlights from A or B.

**F4-20 — Full combined flow: select → highlight → confirm → state clears**
- Seed: Party X (size 8) selected. T4+T5 combination recommended.
- Expected highlight: T4 and T5 blue.
- Action: Manager opens ReserveTableDialog. Sees 🔵 T4+T5. Confirmation dialog shown.
- Action: Manager confirms → two sequential `reserveTable()` calls (T4, T5).
- Expected after both succeed: `selectedQueueEntryIdProvider` = null. T4 and T5 update to occupied state. Blue highlights clear. Stream updates propagate. No stale UI.

---

## 11. Open Design Decisions

| # | Decision | Options | Status |
|---|---|---|---|
| 1 | **Combined table reservation atomicity** | (A) Two sequential calls for MVP — non-atomic. (B) `reserveCombinedTables` Cloud Function for full atomicity. | **A for MVP** — surface recommendation + require confirmation dialog; non-atomic is acceptable. Spec B for post-MVP. |
| 2 | **`occupancy` Cloud Function writes** | `confirmSeated` writes `occupancy = partySize`. `completeMeal` writes `occupancy = 0`. | **Must confirm with CF implementer before F3 coding.** SHARED_MATCH blocked on this. |
| 3 | **`customerPreferences` UI capture** | Seating preference added to Join Queue form in this sprint. | **Defer to Phase 2.** Engine handles null preference as anyAvailable. |
| 4 | **`BranchRef` construction** | Cache as `late final` in widget state vs construct in build(). | **Cache as `late final`.** Construct in build() causes stream restart. |
| 5 | **Combined table tile visual grouping** | Blue border only vs shared badge + linking indicator. | **Blue border only for MVP.** `combinedPartnerIds` available for future enhancement. |
| 6 | **`reserveTable` current behavior** | Writes Firestore directly (technical debt per §4.9). | **Do not change for F3/F4.** This feature only changes recommendation display, not the reservation transaction. |

---

## 12. Migration Notes

### 12.1 Removing `_bestFitTables` and `_tablesForParty`

After `TableRecommendationEngine` is implemented and wired:
1. Delete `_bestFitTables()` and `_tablesForParty()` from `admin_dashboard_screen.dart`.
2. Remove `_matchingTableIds()` from `_AdminDashboardScreenState`.
3. Remove `_selectedQueueEntry` state and `_handleQueueEntryTap()`.
4. `TableGrid` no longer receives `matchingTableIds: Set<String>`. It receives `highlightMap: Map<String, TableHighlight>` from `tableHighlightMapProvider`.
5. `QueuePanel` no longer calls `_handleQueueEntryTap`. It calls `onEntryTapped` → sets `selectedQueueEntryIdProvider`.
6. `_ReserveTableDialog` no longer calls `_tablesForParty`. It reads `partyRecommendationProvider(branch)` directly.
7. Add `ref.listen` calls for auto-clear (§8.3) in `AdminDashboardScreen`'s `build()` method.

### 12.2 `AdminDashboardScreen` State Migration

| Current | Replacement |
|---|---|
| `QueueEntry? _selectedQueueEntry` (setState) | `selectedQueueEntryIdProvider` (Riverpod) |
| Nested `StreamBuilder<tables>` + `StreamBuilder<queue>` | `ref.watch(tablesStreamProvider(branch))` + `ref.watch(queueStreamProvider(branch))` |
| `occupiedCountFor(table)` lambda | `table.occupancy` + `table.remainingSeats` (computed getter) |
| `allCandidateTables` list construction | Provider builds `RecommendationContext` from stream data |
| `_ReserveTableDialog(availableTables: availableTables)` | `_ReserveTableDialog` reads `partyRecommendationProvider(branch)` |
| — (auto-clear was inside non-existent provider logic) | `ref.listen` callbacks in `AdminDashboardScreen` |

### 12.3 Firestore Seed Scripts

- `tool/seed_partial_seat_scenario.mjs` — existing; extend to write `floorId`, `adjacentTableIds` (doc IDs), `x`, `y`, `occupancy`.
- `tool/seed_f4_adjacency_scenario.mjs` — new script; must populate `adjacentTableIds` using real Firestore document IDs fetched from the emulator after table creation (not hardcoded strings).

**Seed script pattern for adjacency (pseudocode):**
```js
const tableRefs = await createTables(branch, tableConfigs);
// tableRefs is Map<tableNumber, DocumentReference>
// adjacency is described as tableNumber pairs in seed config
for (const [fromNumber, toNumber] of adjacencyPairs) {
  const fromId = tableRefs[fromNumber].id;
  const toId   = tableRefs[toNumber].id;
  await tableRefs[fromNumber].update({ adjacentTableIds: FieldValue.arrayUnion([toId]) });
  await tableRefs[toNumber].update({ adjacentTableIds: FieldValue.arrayUnion([fromId]) });
}
```

### 12.4 Firestore Security Rules

The `occupancy` field is written by Cloud Functions only. The existing rule blocking direct client writes to `tables/{tableId}` covers this. No new rules required.

---

## 13. Critical Issue Resolution Status

| ID | Issue | Resolution | Status |
|---|---|---|---|
| **C-1** | Floating-point `== 1.0` assert crashes debug builds | Replaced with `(sum - 1.0).abs() < 0.001` in §4.7 | ✅ Resolved |
| **C-2** | `ref.read(notifier).state = null` inside provider build throws `StateError` | Removed from providers; moved to `ref.listen` in `AdminDashboardScreen` — documented in §7.4, §8.3 | ✅ Resolved |
| **C-3** | `adjacentTableIds` could contain tableNumber strings → F4 silent failure | Standardised to Firestore document IDs throughout §3.1, §6.4, §12.3, all F4 test scenarios; seed script contract updated | ✅ Resolved |
| **C-4** | `occupancy` write path undefined → SHARED_MATCH broken | Cloud Function contract formalised in §3.4; F3 SHARED_MATCH declared as dependent on CF update; prerequisite added to test scenarios | ✅ Resolved (prerequisite confirmed as open action) |
| **C-5** | F4 trigger condition missing `validSharedMatch.isEmpty` → combined tiles shown when one table suffices | Trigger condition corrected in §6.2 Step 4; test F3-06 and F4-04 cover the corrected behaviour | ✅ Resolved |
| **C-6** | Suppressed sharedMatch entries appeared in highlight map → orange border on preference-blocked tables | `isSuppressed` flag added to `TableRecommendation` (§4.3); `tableHighlightMapProvider` filters suppressed entries (§7.5); dropdown renders suppressed entries as disabled (§9.3); F3-04, F3-06, F4-04 updated | ✅ Resolved |
| **AR-2** | `RecommendationContext` defined but never used by engine | Option A chosen: engine now accepts `RecommendationContext` as input (§6.1, §6.2); provider constructs context (§7.4); table-partition Step 1 moved to provider layer | ✅ Resolved |
| **SMP** | `reserveDropdownProvider`, `RecommendationResult`, `CombinedTableRecommendation.recommendationId`, file fragmentation | All removed/merged per §2, §4.8, §4.5, §7.6 | ✅ Resolved |

### Remaining Open Actions (not design issues — require external confirmation)

| Action | Owner | Blocks |
|---|---|---|
| Confirm `confirmSeated` Cloud Function will write `occupancy = partySize` this sprint | Cloud Function implementer | F3 SHARED_MATCH testing |
| Confirm `completeMeal` Cloud Function will write `occupancy = 0` this sprint | Cloud Function implementer | F3 SHARED_MATCH testing |
| Smoke-test existing `reserveTable()` against Emulator before F3 coding begins | Flutter engineer | F3 reserve flow |
| Write `seed_f4_adjacency_scenario.mjs` using document IDs | Flutter engineer | F4 all tests |

---

*This document is the authoritative design for F3/F4 — v2 correction pass complete. Coding may begin once the four remaining open actions above are confirmed. All six critical design issues are resolved within this document.*
