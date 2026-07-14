# EZQ Platform Stabilization Issues Tracker

## PS-001 - Production admin login used email/password

- **Description:** Admin login had been changed to email/password even though EZQ production authentication is Phone Number + OTP.
- **Root Cause:** Email/password was introduced as a live-verification workaround because the existing Biryani Bay seeded admin was an email/password Auth user.
- **Fix:** Restored admin login UI to phone number + OTP and removed the production `signInAdmin(email, password)` API from `AuthRepository`.
- **Files Changed:**
  - `lib/features/auth/presentation/admin_login_screen.dart`
  - `lib/features/auth/data/auth_repository.dart`
- **Firestore Changes:** None.
- **Verification Steps:**
  - Opened `/admin/login` locally with Firebase enabled.
  - Verified the login screen shows Phone Number and Send OTP, not email/password.
  - `flutter analyze --no-pub`
  - `flutter test --no-pub`
- **Status:** Fixed in code, live OTP completion blocked by PS-002 and PS-003.

## PS-002 - Firebase Phone Auth SMS region is not enabled

- **Description:** Sending OTP to the Biryani Bay admin phone fails before OTP entry.
- **Root Cause:** Firebase Auth returned: `SMS unable to be sent until this region enabled by the app developer.`
- **Fix:** Added clearer UI copy for this Firebase configuration error. The Firebase project must enable SMS delivery for the target phone region.
- **Files Changed:**
  - `lib/features/auth/presentation/admin_login_screen.dart`
- **Firestore Changes:** None.
- **Verification Steps:**
  - Started the app with `USE_FIREBASE=true`.
  - Opened `/admin/login`.
  - Entered `9999000222`.
  - Firebase returned the region configuration error.
- **Status:** Blocked by Firebase Console/Auth settings.

## PS-003 - Phone Auth admin users are not provisioned for every branch

- **Description:** Every `restaurantBranches/{restaurantBranchId}` except `codex-rule-sync-*` must have exactly one Firebase Auth phone admin and one matching `admins/{uid}` document.
- **Root Cause:** Existing Biryani Bay admin mapping was created for an email/password Auth UID. Phone OTP sign-in will produce/use a phone Auth UID, which must map to `admins/{uid}`.
- **Fix:** Added an Admin SDK utility to provision phone admins from existing Firestore admin mappings and remove stale duplicate admin docs. The script now authenticates with `GOOGLE_APPLICATION_CREDENTIALS` service account JSON first, then falls back to Application Default Credentials, and prints clear setup instructions if neither is available.
- **Files Changed:**
  - `tool/provision_phone_admins_for_branches.mjs`
- **Firestore Changes:** Not applied. Dry run is blocked because this machine has no service account JSON configured and no ADC.
- **Verification Steps:**
  - Ran `node tool/provision_phone_admins_for_branches.mjs ezq-dev-cubiquitous --dry-run`.
  - Confirmed blocker is now reported with setup instructions instead of a generic Firebase stack trace.
  - Ran `node --check tool/provision_phone_admins_for_branches.mjs`.
- **Status:** Blocked by Firebase Admin credentials.

## PS-004 - Dashboard ignored provisioned T1 table

- **Description:** Dashboard loaded but displayed zero tables even though Firestore contained `T1`.
- **Root Cause:** `FirebaseTableRepository.watchTables()` queried with `.orderBy('sortOrder')`. Firestore `orderBy` excludes documents missing that field. Provisioned `T1` did not have `sortOrder`.
- **Fix:** Removed Firestore `orderBy('sortOrder')` and kept Dart-side sorting. Updated onboarding provisioning to write `sortOrder` and `tableType` for future tables.
- **Files Changed:**
  - `lib/features/tables/data/table_repository.dart`
  - `lib/features/rest_onboarding/data/restaurant_onboarding_repository.dart`
- **Firestore Changes:**
  - Updated live `restaurantBranches/biryani-bay-domlur-edge/tables/T1` with `sortOrder: 1`, `tableType: "1-top"`, and `section: "default"`.
- **Verification Steps:**
  - Authenticated REST read confirmed `T1` existed with missing `sortOrder`.
  - Patched live `T1`.
  - `flutter analyze --no-pub`
  - `flutter test --no-pub`
- **Status:** Fixed and live Firestore data patched for Biryani Bay.

## PS-005 - Legacy slug-pair routes remained in GoRouter

- **Description:** Router still accepted legacy mixed slug routes such as `/customer/:restaurantSlug/:branchSlug` and `/admin/:restaurantSlug/:branchSlug/dashboard`.
- **Root Cause:** Backward-compatible redirect routes remained after the canonical `restaurantBranchId` model was introduced.
- **Fix:** Removed legacy slug-pair customer/admin routes and removed the production `/admin/register` route from GoRouter.
- **Files Changed:**
  - `lib/app/router.dart`
  - `lib/features/auth/presentation/admin_login_screen.dart`
- **Firestore Changes:** None.
- **Verification Steps:**
  - Static route audit with `rg`.
  - `flutter analyze --no-pub`
  - `flutter test --no-pub`
- **Status:** Fixed in code, full live route sweep pending after PS-002 and PS-003.

## PS-006 - Firebase Test Phone Numbers need project-level configuration

- **Description:** Sprint requires Firebase Test Phone Numbers for every restaurant branch with OTP `123456`.
- **Root Cause:** Test phone numbers are Firebase Auth project configuration, not app code. They cannot be hardcoded into the Flutter app and require privileged Firebase project access.
- **Fix:** Not applied from this environment. Must be configured in Firebase Auth test phone numbers for each generated branch admin phone.
- **Files Changed:** None.
- **Firestore Changes:** None.
- **Verification Steps:** Pending Firebase project access.
- **Status:** Blocked by Firebase project access.

## PS-007 - QR local asset fallback can duplicate canonical branch ID

- **Description:** QR management attempted to load a missing local asset path shaped like `assets/qr/biryani-bay-domlur-edge/biryani-bay-domlur-edge/biryani-bay-domlur-edge.png`.
- **Root Cause:** `QrManagementRepository` still builds fallback QR asset paths from legacy `restaurantId/branchSlug` assumptions. In canonical admin routes both values are the same `restaurantBranchId`.
- **Fix:** Not applied yet. Production-ready options are to regenerate QR assets using canonical branch IDs or write `qrPngLocalPath`/`qrSvgLocalPath` for every `restaurantBranches/{restaurantBranchId}` document.
- **Files Changed:** None yet.
- **Firestore Changes:** None yet.
- **Verification Steps:**
  - Browser console showed a 404 for the duplicated fallback path while opening QR management.
- **Status:** Open.
