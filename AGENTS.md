# AGENTS.md

Guidance for coding agents working in this repository.

## Project Overview

EZQ is a Flutter + Firebase restaurant queue management app.

- Customer web/mobile flow: join queue, view queue status, see remaining wait, open uploaded menu PDF, use support, and view waiting-time engagement content.
- Mobile app customer auth: iOS/Android app flow supports Firebase phone/OTP authentication at `/app/login`.
- Manager/admin flow: manage live queue, seat parties by assigning available tables, finish meals, and track table lifecycle timestamps.
- Firebase project: `ezq-dev-cubiquitous`.
- Main demo restaurant path: `the-spice-house/indiranagar`.

## Product Architecture

EZQ is organized as a feature-first Flutter app with Firebase as the backend.

- Routing is centralized in `lib/app/router.dart`.
- App-wide theme and color tokens live in `lib/app/theme.dart` and `lib/core/constants/app_colors.dart`.
- Firestore path helpers live in `lib/core/constants/firestore_paths.dart`.
- Feature data access is handled through repository classes, usually exposed with Riverpod providers.
- Domain models parse Firestore wire data into typed Dart objects.
- Presentation widgets stay inside each feature folder and should call repositories through providers rather than reaching into Firestore directly from UI widgets.

Current backend posture:

- The app is connected to Firebase Auth, Firestore, Hosting, and Cloud Functions source.
- Customer phone auth uses Firebase Auth phone verification and writes the signed-in user's own `customers/{uid}` profile.
- Firebase Hosting serves Flutter web from `build/web`.
- Firestore rules and indexes are deployed from `firestore.rules` and `firestore.indexes.json`.
- Cloud Functions source is in `functions/src/index.ts`, but full Functions deploy currently requires the Firebase project to be on Blaze because Cloud Build must be enabled.
- Some active Flutter flows use direct Firestore transactions. Keep Cloud Functions source aligned with app behavior so production hardening can migrate sensitive writes behind callable functions later.

## Firestore Shape

Primary demo path:

```text
restaurants/the-spice-house
restaurants/the-spice-house/branches/indiranagar
restaurants/the-spice-house/branches/indiranagar/tables/{tableId}
restaurants/the-spice-house/branches/indiranagar/queueEntries/{queueEntryId}
restaurants/the-spice-house/branches/indiranagar/dailyCounters/{businessDate}
```

Important table fields:

- `tableNumber`: display label such as `T12`.
- `capacity`: exact seat capacity used for grouping, sorting, and best-fit assignment.
- `status`: active app statuses are `available` and `occupied`; `reserved` is legacy/transitional and `cleaning` maps to `available`.
- `currentQueueEntryId` and `currentTokenCode`: active seated party linkage.
- `currentCycleStartAt`, `lastCycleStartAt`, `lastCycleEndAt`: table-cycle timing.
- `lastCompletedPartySize`: manager-confirmed completed guest count.

Important queue entry fields:

- `tokenCode`, `customerName`, `phone`, `partySize`, `notes`.
- `status`: active queue values include `waiting`, `seated`, `completed`, `skipped`, and `cancelled`; `reserved` and `on_the_way` are legacy-compatible.
- `assignedTableId` and `assignedTableNumber`: shown to the customer after seating.
- `reservedAt` is retained as the assignment timestamp for audit/history; `seatedAt` is set at the same time in the current simplified flow.
- `completedPartySize`, `tableCycleStartAt`, and `tableCycleEndAt` support reporting.

## Current Business Flow

Customer flow:

1. Customer scans/opens the restaurant branch URL.
2. Customer joins as a guest with name, phone, exact party size, and optional notes.
3. Customer status screen shows token, queue position, remaining wait, menu, support, ad space, and waiting-game placeholder.
4. When the manager seats the party, customer status changes to the seated/table-assigned state.
5. Customer can view the uploaded menu PDF from branch config.

Mobile app auth flow:

1. Customer opens `/app/login`.
2. Customer enters an India mobile number and requests an OTP.
3. Firebase Auth verifies the SMS code or completes auto-verification on supported devices.
4. App creates/updates `customers/{uid}` with phone auth profile metadata.
5. Customer lands on `/app/home` and can continue into the queue flow.

Manager flow:

1. Manager logs in with Firebase email/password auth.
2. Dashboard shows tables grouped by capacity and a live queue of waiting entries.
3. Manager clicks `Reserve` on a waiting queue entry.
4. Manager picks from a list of only available tables that can fit the party.
5. Confirming `Seat now` immediately sets table `occupied` and queue entry `seated`; there is no separate mark-seated step.
6. Occupied table tiles show an action to finish the meal.
7. Manager confirms how many guests finished; table returns to `available`, queue entry becomes `completed`, and cycle timestamps are recorded.

Table color coding:

- Available tables use the brand aqua/cyan treatment.
- Partially occupied tables use warning/amber.
- Fully occupied tables use red.

## Built Feature Snapshot

Customer-facing features currently documented as built:

- Guest queue join from `/customer/:restaurantSlug/:branchSlug`.
- Join form with name, phone, exact party size, and optional notes.
- Live queue status with token, party size, queue position, and remaining wait.
- Customer seated/table-assigned status after manager seating.
- Customer cancellation while waiting.
- Menu PDF viewing from branch configuration.
- Customer support screen.
- Customer shell with EZQ header, app install shortcut, bottom tabs, powered-by branding, sponsored ad slot, and waiting-game placeholder.

Manager/admin features currently documented as built:

- Firebase email/password manager login.
- Branch dashboard with live Firestore-backed tables and queue.
- Tables grouped/sorted by capacity with capacity, occupied count, status, and token display.
- Queue cards with token, customer, party size, wait duration, joined time, reserve, and skip actions.
- Reserve flow with fitting available-table picker and direct queue `seated` / table `occupied` update.
- Occupied table finish-meal flow with completed party size capture and lifecycle timestamp recording.
- Walk-in queue entry dialog.
- Daily summary/report entry point from the dashboard.

Platform/backend features currently documented as built:

- Firebase Hosting, Auth, Firestore rules, indexes, and Cloud Functions source are present.
- Demo seed data and Firestore smoke test scripts live in `tool/`.
- Cloud Functions remain the production-hardening path even where current app flows use direct Firestore transactions.

## Repository Shape

- `lib/`: Flutter app source.
- `lib/app/`: app shell, routing, and theme.
- `lib/features/customer/`: customer screens, queue join/status/menu/support flows.
- `lib/features/admin/`: admin login, branch selection, and dashboard.
- `lib/features/tables/`: table domain, repository, and table grid UI.
- `lib/features/queue/`: queue domain, data access, and queue panel UI.
- `lib/features/reports/`: daily summary/reporting surfaces.
- `functions/`: Firebase Cloud Functions TypeScript source.
- `tool/`: local scripts for seeding, smoke tests, PDF generation, and local SPA serving.
- `web/`: Flutter web shell and public web assets.
- `assets/brand/`: bundled brand assets.
- `docs/EZQ_UI_DESIGN_HANDOUT.md`: current product/UI handout source, including built features, functional requirements, and user stories.
- `docs/EZQ_UI_DESIGN_HANDOUT.pdf`: generated shareable version of the handout.

## Common Commands

Run these from the repository root.

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --pwa-strategy=none --dart-define=USE_FIREBASE=true
```

Firebase deploy:

```sh
npx --yes firebase-tools deploy --project ezq-dev-cubiquitous
```

Seed Firestore demo data:

```sh
node tool/seed_firestore.mjs ezq-dev-cubiquitous
```

Run Firestore smoke test:

```sh
node tool/e2e_firestore_smoke.mjs ezq-dev-cubiquitous
```

Regenerate the UI design handout PDF after editing `docs/EZQ_UI_DESIGN_HANDOUT.md`:

```sh
python3 tool/generate_ui_design_handout_pdf.py
```

When working inside Codex desktop, prefer the bundled Python runtime if local Python is missing PDF dependencies.

## Product Documentation Notes

- Keep `docs/EZQ_UI_DESIGN_HANDOUT.md` aligned with implemented behavior when changing customer, manager, routing, table lifecycle, or reporting behavior.
- The handout includes the current feature list, functional requirements, and user stories; update those sections when adding or removing meaningful product capabilities.
- Regenerate `docs/EZQ_UI_DESIGN_HANDOUT.pdf` from the Markdown source after handout edits.
- The PDF generator is `tool/generate_ui_design_handout_pdf.py` and uses ReportLab plus screenshot assets under `docs/screenshots/`.
- Do not hand-edit generated PDF bytes; change the Markdown and rerun the generator.

## Local App Notes

- Customer URL pattern: `/customer/:restaurantSlug/:branchSlug`.
- Admin URL pattern: `/admin/:restaurantSlug/:branchSlug/dashboard`.
- For local web testing, prefer Flutter web or the local SPA helper in `tool/spa_server.py`.
- For iOS simulator testing, use Flutter commands and keep safe-area layout in mind; avoid UI overlapping the iOS status bar or bottom home indicator.

## Firebase/Data Notes

- Customer web app does not require customer email authentication.
- Customer mobile app sign-in uses Firebase phone/OTP authentication; keep guest web join available.
- Firestore rules allow authenticated phone users to create/update only their own `customers/{uid}` profile.
- Manager login uses Firebase email/password auth.
- Firestore table statuses actively used by the app are `available` and `occupied`; `reserved` exists for compatibility with older data.
- Legacy `cleaning` table status should be treated as `available`; do not reintroduce a cleaning flow unless explicitly requested.
- Table tiles should expose capacity and occupied count. Admin tables are grouped/sorted by capacity for easier table assignment.
- Reserving a queue entry should ask the manager to pick a table from available tables, not type a table number manually.
- Reserving a queue entry should immediately update the table to occupied and the queue entry to seated; there is no separate mark-seated step.
- Finishing a meal should capture completed party size and record lifecycle timestamps.

## UI/UX Direction

- Follow the existing Apple/iOS-inspired visual direction: compact hierarchy, generous but not wasteful spacing, soft surfaces, clear controls, and safe-area aware layouts.
- Use Cubiquitous/Tracura palette tokens from `AppColors`: mint/aqua/sky for surfaces and calm states, purple/cyan gradients for brand moments, and restrained red/amber for operational states.
- Keep customer flows simple and guest-friendly.
- Keep admin flows dense enough for repeated operational use.
- Admin dashboard must work across Android phones, iPhones, iPads, and Android tablets. Preserve safe areas, avoid fixed desktop-only widths, and verify compact/tablet/desktop breakpoints when changing layout.
- Do not add marketing landing pages where a functional app screen is expected.
- Use existing widgets and patterns before creating new abstractions.

## Generated/Local Files

Do not commit generated or bulky local output:

- `build/`
- `.dart_tool/`
- `.firebase/`
- `functions/node_modules/`
- `functions/lib/`
- `tmp/`
- `output/`

These are already covered by `.gitignore`; keep that behavior intact.

## Git Hygiene

- Check `git status --short` before editing.
- Do not revert user changes unless explicitly asked.
- Keep commits focused and avoid committing secrets or local machine state.
- Firebase client config files contain public Firebase app identifiers; do not place private service account keys in the repo.
