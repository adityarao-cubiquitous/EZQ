# AGENTS.md

Guidance for coding agents working in this repository.

## Project Overview

EZQ is a Flutter + Firebase restaurant queue management app.

- Customer web/mobile flow: join queue, view queue status, see remaining wait, open uploaded menu PDF, use support, and view waiting-time engagement content.
- Manager/admin flow: manage live queue, reserve tables, mark guests seated, finish meals, and track table lifecycle timestamps.
- Firebase project: `ezq-dev-cubiquitous`.
- Main demo restaurant path: `the-spice-house/indiranagar`.

## Repository Shape

- `lib/`: Flutter app source.
- `lib/app/`: app shell, routing, and theme.
- `lib/features/customer/`: customer screens, queue join/status/menu/support flows.
- `lib/features/admin/`: admin login, branch selection, and dashboard.
- `lib/features/tables/`: table domain, repository, and table grid UI.
- `lib/features/queue/`: queue domain, data access, and queue panel UI.
- `functions/`: Firebase Cloud Functions TypeScript source.
- `tool/`: local scripts for seeding, smoke tests, PDF generation, and local SPA serving.
- `web/`: Flutter web shell and public web assets.
- `assets/brand/`: bundled brand assets.

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

## Local App Notes

- Customer URL pattern: `/customer/:restaurantSlug/:branchSlug`.
- Admin URL pattern: `/admin/:restaurantSlug/:branchSlug/dashboard`.
- For local web testing, prefer Flutter web or the local SPA helper in `tool/spa_server.py`.
- For iOS simulator testing, use Flutter commands and keep safe-area layout in mind; avoid UI overlapping the iOS status bar or bottom home indicator.

## Firebase/Data Notes

- Customer web app does not require customer email authentication.
- Manager login uses Firebase email/password auth.
- Firestore table statuses currently used by the app are `available`, `reserved`, and `occupied`.
- Legacy `cleaning` table status should be treated as `available`; do not reintroduce a cleaning flow unless explicitly requested.
- Table tiles should expose capacity and occupied count. Admin tables are grouped/sorted by capacity for easier table assignment.
- Reserving a queue entry should ask the manager to pick a table from available tables, not type a table number manually.
- Reserving a queue entry should immediately update the table to occupied and the queue entry to seated; there is no separate mark-seated step.
- Finishing a meal should capture completed party size and record lifecycle timestamps.

## UI/UX Direction

- Follow the existing Apple/iOS-inspired visual direction: compact hierarchy, generous but not wasteful spacing, soft surfaces, clear controls, and safe-area aware layouts.
- Keep customer flows simple and guest-friendly.
- Keep admin flows dense enough for repeated operational use.
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
