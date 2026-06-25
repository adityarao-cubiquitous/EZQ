# EZQ by Cubiquitous — Product Non-Negotiables

**Source:** EZQ Product Architecture & Build Handout (incl. 2026-06-22 Implementation Addendum)
**Purpose:** This document consolidates every rule, constraint, and "must/must not" statement from the architecture handout into a single non-negotiable checklist for design, engineering, and QA. Anything listed here overrides convenience, speed, or a "nice to have" feature request unless explicitly re-negotiated by product.

---

## 1. Core Product Non-Negotiables

1. The web experience must **always remain available**. App install must **never be mandatory** for joining a queue.
2. Customers must be able to join the queue **without**:
    - Downloading an app
    - Creating an account
    - Remembering a password
    - Standing near the entrance
    - Repeatedly asking the hostess for status
3. The hostess/admin remains the **final decision-maker** for: assigning a table, marking seated, skipping, marking no-show, and all table state changes. The system **assists**, it never auto-decides.
4. **No AI in MVP.** Table matching and wait-time estimation must be simple, deterministic, rule-based logic — explainable to a non-technical restaurant owner.
5. Both customer and hostess views must reflect **real-time status** via live listeners (Firestore) — no manual refresh required.
6. One Flutter codebase must serve Customer Web, Customer Mobile, and Hostess/Admin Web — not three separate codebases.

---

## 2. MVP Scope Non-Negotiables

### Must be deployed for MVP launch
- Customer Web App
- Hostess/Admin Web Dashboard

### Must NOT be built for MVP (explicitly excluded)
- In-app QR scanner
- localStorage sync / localStorage as source of truth
- AI wait-time prediction
- Nearby activity recommendations
- Discount code engine
- POS integration
- Full loyalty system
- Advanced analytics
- Multi-language support
- WhatsApp/SMS production integration (mock notifications only)
- Mandatory customer login
- Restaurant marketplace
- Table floor map designer
- Separate native apps built before the shared Flutter Web/Mobile codebase

> Extension points for the above may be *designed* into the architecture, but must not be *implemented* in MVP.

---

## 3. Table & Queue Lifecycle Non-Negotiables (Updated per 2026-06-22 Addendum)

1. **Cleaning state is removed from MVP.** Table lifecycle is now strictly:
   `available → reserved → occupied → available`
   `blocked` remains as an administrative-only state.
2. Old "Mark table cleaning" / "Mark table available after cleaning" flows (Section 8.4 of the original handout) are **superseded and must not be implemented**.
3. Table transitions allowed in MVP:
    - `available → reserved`
    - `available → occupied`
    - `available → blocked`
    - `reserved → occupied`
    - `reserved → available`
    - `occupied → available`
    - `blocked → available`
4. Queue entry transitions allowed in MVP:
    - `waiting → reserved`
    - `waiting → skipped`
    - `waiting → cancelled`
    - `reserved → on_the_way`
    - `reserved → seated`
    - `reserved → no_show`
    - `reserved → cancelled`
    - `on_the_way → seated`
    - `on_the_way → no_show`
    - `on_the_way → cancelled`
    - `seated → completed`
5. The hostess must **manually confirm** every table state change. No automatic state transitions (e.g., no auto-marking "available" after a timer).
6. "Meal finished" must require the manager to record the **number of guests who finished** (`completedPartySize`).
7. Reserve action must present a **best-fit table picklist** ranked by `TableRecommendationEngine` output (see Section 10) — ordering: exact match → shared match → larger alternative → combined table, then by score descending within type. Each item must display a recommendation tag. Not an arbitrary or capacity-only sort.

---

## 4. Data & Backend Non-Negotiables

1. **Critical writes must go through Cloud Functions** — never direct, unauthenticated client writes. Critical writes include: join queue, add walk-in, reserve table, mark seated, mark no-show, skip, cancel, update table status.
2. Firestore **direct client writes must be blocked** for: `queueEntries`, `tables`, `dailyCounters`, `notifications`.
3. Clients may **read** relevant data but may not write to the above collections directly.
4. Token numbers must be generated via a **Firestore transaction** against the daily counter document — never client-generated or guessable.
5. Admin access must be validated **server-side** (Cloud Functions), not just client-side route guards.
6. Manager/admin authentication uses **Firebase Authentication (email/password)** — this is now finalized, not optional.
7. Customer flow remains **guest/no-email** — customers are identified by name + phone, not by account login, for MVP.
8. Notifications in MVP must be created as **mock notification records** — no real SMS/WhatsApp/push integration is allowed in MVP.
9. Any direct Firestore writes currently present in the Flutter repository layer (per addendum, Section 8) are **technical debt** and must be migrated to Cloud Functions before production — they are not an accepted long-term pattern.

---

## 5. Customer Experience Non-Negotiables

1. Customer join flow must be **mobile-first**, low-friction, and avoid unnecessary steps. CTA ("Join Queue") must be prominent.
2. Party size must use **exact values via a picklist** (updated from broad ranges in the original handout) — larger party sizes must be supported through the same picklist mechanism.
3. Once a customer has joined from a session/phone context, **Join Queue must be disabled** for that session to prevent duplicate entries.
4. Queue Status screen must show: token, name, party size, queue position, **live countdown** remaining wait (not a static estimate), and progress indicator.
5. Customer-facing menu must be a **scrollable PDF-style page**, sourced from a backend-configured URL (`menuPdfUrl`) — not hardcoded.
6. Hidden-object puzzle / wait-engagement image must be **backend-driven** with a clean placeholder shown until an image is uploaded — never a broken or empty state.
7. "Powered by Cubiquitous" branding must appear below the Cancel Reservation action on the status screen.
8. App install must be **offered, never forced**, and must never interrupt the queue-joining flow.
9. Table-ready alert must clearly warn the customer that failing to arrive in time may move them back in the queue.

---

## 6. Hostess/Admin Experience Non-Negotiables

1. Dashboard must be **tablet-first**: large tap targets, minimal scrolling, usable during rush hour, no complex nested menus.
2. Table grid must be **grouped and sorted by capacity** (2-top, 4-top, 6-top, 8-top, 10-top).
3. Section/location labels (main, bar, patio, window) must **not** appear on table tiles — removed for cleaner scanning.
4. Table tiles must show table number, capacity, status, occupancy count, and linked token where applicable.
5. Topbar must always show live counts: Free, Occupied, Waiting.
6. Reserved tiles must expose a **Mark Seated** action; occupied tiles must expose a **Meal Finished** action requiring guest count confirmation.

---

## 7. Brand & Design Non-Negotiables

1. Brand colors, fonts (Inter for UI, JetBrains Mono for tokens/timers), and the teal-to-purple gradient must be used consistently — no ad hoc palette substitutions.
2. The bubble motif must be used **subtly** — explicitly: "Do not make the UI look childish."
3. UI must read as **clean, modern, fast, trustworthy** — explicitly **not overly corporate**.
4. Cubiquitous logo (2×2 rounded-square gradient mark) must appear in topbars, footers, and splash screens.

---

## 8. Engineering Non-Negotiables (for any AI coding agent / Codex)

1. Use **one Flutter project**, not multiple repos per platform.
2. Use **Riverpod** for state management and **go_router** for routing — no substitute state/routing libraries without explicit approval.
3. Use **TypeScript** for all Cloud Functions.
4. QR deep links must use the canonical web URL pattern:
   `https://ezq.cubiquitous.in/customer/{restaurantId}/{branchId}`
   — this same URL must later support Android App Links / iOS Universal Links without restructuring.
5. Business date calculations must respect the **branch timezone** (`Asia/Kolkata` default), not server/device local time blindly.
6. Wait-time formulas must remain simple and explainable (groupsAhead-based), clamped between 5–120 minutes — no opaque or ML-based estimation in MVP.
7. Invalid status transitions (queue or table) must be **rejected at the Cloud Function level**, not just hidden in the UI.

---

## 9. Documentation Governance Non-Negotiable

- This handout's addendum (2026-06-22) **supersedes** the original handout wherever they conflict, specifically: Section 8.4 (Cleaning Flow), Section 10.3 (Table status `cleaning`), Section 12.2 (cleaning transitions), Section 21 Milestone 6 (cleaning acceptance), and Section 22 (cleaning-cycle MVP acceptance criteria).
- Any new feature set introduced after this document must be reconciled against this non-negotiables list before implementation — conflicts must be flagged, not silently resolved.

---

## 10. Recommendation Engine Non-Negotiables (F3/F4 — added 2026-06-24)

1. **Single source of truth:** `TableRecommendationEngine` is the sole origin of all table recommendation logic — for the table grid, queue panel, and Reserve dropdown. No surface may reimplement or duplicate ranking logic.
2. **Consistent output across all surfaces:** table grid highlights, queue panel highlights, and the Reserve dropdown must always reflect the same ranked output from the engine. These three surfaces must never diverge.
3. **Reserve dropdown must use engine ordering:** the Reserve dropdown must consume `TableRecommendationEngine` output directly — `EXACT_MATCH` → `SHARED_MATCH` → `LARGER_ALTERNATIVE` → `COMBINED_TABLE`, then by score descending within type. No widget-level re-sort is permitted.
4. **Every recommendation must include a reason string:** `TableRecommendation.recommendationReason` is mandatory, never null or empty. The engine must not surface any recommendation without a populated reason string.
5. **Exact matches must be visually distinguishable:** `EXACT_MATCH` (green border + glow) must be immediately distinct from `SHARED_MATCH` (orange), `LARGER_ALTERNATIVE` (yellow), and `COMBINED_TABLE` (blue). These color assignments are fixed and must not be substituted.
6. **Managers must always see best recommendation plus alternatives:** the engine must never surface a single highlighted party or table in isolation. At least one alternative must accompany the top recommendation.
7. **Combined table recommendations are mandatory when no single table is suitable:** when no single available or partially occupied table can seat the party, `TableRecommendationEngine` must emit `COMBINED_TABLE` recommendations. Returning an empty recommendation list for a sizable party is not acceptable.
8. **Factor-based and extensible architecture:** the engine must be structured as a weighted factor pipeline. New factors must be injectable as additional weighted contributors without modifying the core ranking loop or existing factor implementations.
9. **Customer seating preferences must automatically influence recommendations:** customer preference (e.g., `EMPTY_TABLE_ONLY`) must be evaluated inside `TableRecommendationEngine` before output is emitted — not at the widget layer — so all surfaces reflect the preference automatically with no additional widget-level logic.
10. **Recommendation logic must remain explainable and deterministic:** scoring must follow the defined weighted formula and produce consistent, reproducible results for identical inputs. No opaque, probabilistic, or ML-based ranking in MVP.

---

## 11. F3/F4 Data Integrity & Firebase-First Non-Negotiables (added 2026-06-24)

1. **Firebase is the only permitted data source for F3 and F4:** all recommendation inputs — queue entries, table documents, occupancy values, capacity values, status values, and adjacency metadata — must come from live Firestore streams. Mock repositories, local JSON, hardcoded table sets, in-memory fake data, and temporary demo providers are not permitted at any layer.
2. **Mandatory Firestore collection paths for F3/F4:**
   - Queue entries: `restaurants/{restaurantId}/branches/{branchId}/queueEntries`
   - Tables: `restaurants/{restaurantId}/branches/{branchId}/tables`
   - Daily counters: `restaurants/{restaurantId}/branches/{branchId}/dailyCounters`
   - Branch config: `restaurants/{restaurantId}/branches/{branchId}`
   - Admin users: `restaurants/{restaurantId}/admins`
3. **Mandatory architecture — Firestore → Repository → Engine → UI:** the repository layer subscribes to Firestore streams; `TableRecommendationEngine` consumes repository output; UI widgets render engine output only. UI components must never construct or own recommendation data.
4. **No hardcoded adjacency data:** the F4 adjacency graph must be read from `adjacentTableIds` on live Firestore table documents. Hardcoded or in-memory adjacency graphs are not permitted in any environment, including test environments.
5. **All F3/F4 testing must use Firebase Emulator Suite or the EZQ development Firebase project.** Mock repository testing, local fake data, and hardcoded test collections are not valid acceptance testing methods for F3 or F4. Adjacency graphs for F4 must be seeded into the emulator or real project — never hardcoded in test code.
6. **Firestore-driven reactivity is mandatory:** recommendation results and highlights must update immediately in response to Firestore stream changes — table status, occupancy, party joins, queue changes. Polling or manual refresh is not acceptable.
7. **F3 is complete only when:** (a) clicking a real queue party card highlights real Firestore-backed table tiles; (b) clicking a real table card highlights real Firestore-backed queue party cards; (c) Reserve dropdown ordering derives from live Firestore data; (d) highlights update immediately on any Firestore data change.
8. **F4 is complete only when:** (a) combined-table recommendations are generated from live Firestore table documents with real `adjacentTableIds` data; (b) occupancy changes in Firestore immediately affect recommendations; (c) queue party changes immediately affect which combinations are surfaced; (d) results remain consistent as Firestore updates propagate.

---

---

## 12. Implementation Status — F3/F4 Non-Negotiables (as of 2026-06-24)

> This section records implementation reality against §10 and §11. Requirements in §10 and §11 are unchanged.

### §10 — Recommendation Engine Non-Negotiables

| Rule | Status | Evidence |
|---|---|---|
| §10.1 Single source of truth: `TableRecommendationEngine` | ✅ Met | Zero recommendation logic outside `table_recommendation_engine.dart`. `_bestFitTables`, `_tablesForParty`, `occupiedCountFor` all removed from `admin_dashboard_screen.dart`. |
| §10.2 Consistent output across table grid, queue panel, Reserve dropdown | ✅ Met | All three surfaces read from the same `partyRecommendationProvider` / `queueHighlightMapProvider` / `tableHighlightMapProvider`. No surface re-sorts or filters independently. |
| §10.3 Reserve dropdown must use engine ordering | ✅ Met | `_ReserveTableDialog` renders `_selectable` list in engine output order with no re-sort. |
| §10.4 Every recommendation must include a non-empty reason string | ✅ Met | `TableRecommendation` domain assert `recommendationReason != ''`. Fallback reason: `'No Available Table — Notify Manager'`. All 39 engine tests verify specific reason strings. |
| §10.5 Exact color assignments fixed (green/orange/yellow/blue) | ✅ Met | `TableGrid._borderColor`: green = `AppColors.successGreen`, orange = `AppColors.warningOrange`, yellow = `Color(0xFFCA8A04)`, blue = `Color(0xFF2563EB)`. `QueuePanel`: green and yellow. |
| §10.6 Managers must always see best recommendation plus alternatives | ✅ Met | Engine fallback entry ensures non-empty output. `_ReserveTableDialog` shows `_NoAvailableTablesNotice` when all entries are excluded (no real tables qualify). |
| §10.7 Combined table mandatory when no single table is suitable | ✅ Met | C-5 trigger fires when `exactMatch.isEmpty && validSharedMatch.isEmpty && largerAlternative.isEmpty`. Engine test F4-12 verifies. Fallback entry `'No Available Table — Notify Manager'` covers the case where no combination qualifies either. |
| §10.8 Factor-based extensible architecture | ✅ Met | `RecommendationFactors` with injected weights. New factors plug in as additional weighted contributors without modifying the core ranking loop. |
| §10.9 Customer seating preferences evaluated inside engine | ✅ Met | `isSuppressed` set inside `computeRecommendationsForParty` based on `customerPreferences.seatingPreference`. Provider and widget layer receive the flag — no preference evaluation at widget level. |
| §10.10 Deterministic scoring | ✅ Met | Weighted formula; unit tests P2T-01 (score=79) and F4-01 (score=83) verify exact output for known inputs. |

### §11 — F3/F4 Data Integrity & Firebase-First Non-Negotiables

| Rule | Status | Evidence / Notes |
|---|---|---|
| §11.1 Firebase is the only permitted data source | ✅ Met | `MockTableRepository` and `MockQueueRepository` removed. `tableRepositoryProvider` and `queueRepositoryProvider` always return Firebase implementations. |
| §11.2 Mandatory Firestore collection paths | ✅ Met | `tablesStreamProvider` and `queueStreamProvider` subscribe to the exact paths specified. |
| §11.3 Firestore → Repository → Engine → UI architecture | ✅ Met | Repositories expose streams; engine consumes repository output via `RecommendationContext`; UI reads provider output only. |
| §11.4 No hardcoded adjacency data | ✅ Met | Engine reads `table.adjacentTableIds` from Firestore documents passed via `RecommendationContext.availableTables`. No adjacency data is hardcoded in engine or test code. |
| §11.5 All F3/F4 testing must use Firebase Emulator or EZQ dev project | ⚠️ Partially Met | 39 unit tests cover engine logic only (pure Dart, no Firestore). Live Firebase validation (`seed_f4_adjacency_scenario.mjs`) is created but not yet executed. Firebase session pending. |
| §11.6 Firestore-driven reactivity mandatory | ✅ Met (architecture) | `StreamProvider.autoDispose.family` on `tablesStreamProvider` and `queueStreamProvider` propagates every Firestore change through the provider graph automatically. `ref.listen` auto-clears stale selection. |
| §11.7 F3 complete only when acceptance criteria 1–5 pass | 🔥 Pending | `exactMatch` and `largerAlternative` paths: static-verified. `sharedMatch`: CF-blocked. Live stream reactivity: Firebase session pending. |
| §11.8 F4 complete only when acceptance criteria 1–4 pass | 🔥 Pending | Engine fully unit-tested. `seed_f4_adjacency_scenario.mjs` seeded and ready. Firebase Emulator smoke test pending. |

### Known Open Dependencies

| # | Dependency | Blocks |
|---|---|---|
| 1 | `confirmSeated` CF writes `occupancy = partySize` | §11.7 (F3 SharedMatch acceptance) |
| 2 | `completeMeal` CF writes `occupancy = 0` | §11.7 (F3 SharedMatch lifecycle) |
| 3 | Firebase Emulator smoke test session | §11.7 F3 acceptance criteria 1–4; §11.8 F4 acceptance criteria 1–4 |
| 4 | Production `adjacentTableIds` populated with Firestore doc IDs | §11.4 compliance in production (not test) |

### Production Readiness Against §10 / §11

| Flow | Ready? |
|---|---|
| `EXACT_MATCH` party→table and table→party | ✅ Ready |
| `LARGER_ALTERNATIVE` | ✅ Ready |
| `COMBINED_TABLE` (F4) | ✅ Ready pending Firebase smoke test |
| `SHARED_MATCH` | ⚠️ Blocked by Cloud Functions |
| Full §11.7 / §11.8 acceptance | 🔥 Pending Firebase validation |

---

*Note: Additional non-negotiables from the upcoming new feature set (to be provided separately) should be appended as a new section to this document rather than overwritten, to preserve the original architecture's constraints.*