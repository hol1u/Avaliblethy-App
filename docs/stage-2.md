# Stage 2: Delivery pipeline and security hardening

## Goal
Make the Stage 1 app installable and updatable on real devices (Android phone, iPad via
TestFlight, Windows, macOS) and remove the known security and CI weaknesses.
Prerequisite: Stage 1 is merged into `main`.

## Out of scope (do NOT implement)
New chat features, accounts/backend, connecting a real model, macOS notarization,
Microsoft Store / Google Play / App Store publishing.

## A. CI maintenance
1. Update every GitHub Action to its current major version (checkout, upload-artifact,
   flutter-action, etc.) so the Node.js 20 deprecation warnings disappear.
2. Remove invalid inputs (e.g. `cache-dependency-path` is not a valid input of
   `subosito/flutter-action`) and configure caching correctly (Flutter SDK and pub cache).
3. Add `concurrency` with `cancel-in-progress: true`, `workflow_dispatch` on build
   workflows, and `paths-ignore` for `docs/**` and `*.md`.
4. Make sure no generated or IDE files are tracked: `build/`, `.dart_tool/`, `.idea/`,
   `*.iml`. Remove them from git and fix `.gitignore`. Keep the committed web files
   `sqlite3.wasm` and `drift_worker.js`.
5. Result: all workflows green with no deprecation warnings.

## B. Network permissions (verify and fix)
- Android: `INTERNET` permission in the main `AndroidManifest.xml` (not only debug).
- macOS: `com.apple.security.network.client` in both Release and DebugProfile
  entitlements, otherwise the sandboxed app cannot reach a remote server.
- Document in README how a plain-HTTP dev server differs from HTTPS (Android cleartext
  and iOS/macOS ATS rules). Do not enable cleartext in release builds.

## C. Secure storage for the API key
- Store the API key with `flutter_secure_storage` on Android, iOS, macOS and Windows.
  Other settings stay in `shared_preferences`.
- Web: secure storage there is not truly secure. Keep the key in memory only by default
  (not persisted), with an explicit opt-in toggle "Remember key on this device" and a
  visible warning. Document this in README.
- Migration: on first launch after the update, move an existing key from
  `shared_preferences` into secure storage and delete the old value.
- Mask the key in the Settings UI; never log it.
- Tests: migration, read/write through an abstraction (mock the storage), key never
  appears in logs or error messages.

## D. App identity
- Replace all default `com.example.*` identifiers with one reverse-domain id on every
  platform. Placeholder: `com.hol1u.avaliblethy` (owner may change it later).
- Display name placeholder: `Avaliblethy`. Define identifiers and display name in as few
  places as possible and document where to change them.
- Add a proper app icon pipeline (`flutter_launcher_icons` with a placeholder icon).

## E. Android release signing
- Problem: release builds currently use the runner's throwaway debug key, so each CI
  build has a different signature and an APK cannot be installed over the previous one.
- Implement release signing from a keystore provided via GitHub secrets
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`). Decode the keystore at build time; never commit it.
- Produce a signed APK and AAB. If the secrets are absent (forks, PRs), fall back to an
  unsigned/debug-signed build so CI still passes.
- `versionCode` comes from `github.run_number`; `versionName` from `pubspec.yaml`.
- Write `docs/release-android.md` explaining how to generate the keystore and add the
  secrets (the owner does this manually).

## F. iOS to TestFlight
- Add `release-ios.yml`, triggered by `workflow_dispatch` and by tags matching `v*`.
- Build a signed IPA on `macos-latest` and upload it to TestFlight using an App Store
  Connect API key. Choose the simplest reliable approach (fastlane or `xcodebuild` with
  automatic signing via the API key) and justify the choice in the PR description.
- Secrets (names only, values are added by the owner): `APPLE_TEAM_ID`,
  `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_KEY_P8_BASE64`, plus whatever signing approach needs.
- Build number from `github.run_number`; version from `pubspec.yaml`.
- Must not run on pull requests from forks; secrets must never be echoed in logs.
- Write `docs/release-ios.md`: step-by-step manual prerequisites for the owner
  (Apple Developer Program membership, App ID, App Store Connect app record, API key,
  adding secrets, installing via TestFlight on iPad).
- Without the secrets the workflow must fail early with a clear message, not midway.

## G. Windows and macOS artifacts
- Windows: package the release folder as a versioned `.zip` artifact.
- macOS: package the unsigned `.app` as a versioned `.zip` artifact.
- Document in README that Windows SmartScreen and macOS Gatekeeper will warn about
  unsigned builds, and how to open them anyway for testing.

## H. Releases
- On tags `v*`, create a GitHub Release and attach: signed Android APK, Windows zip,
  macOS zip. The iOS build goes to TestFlight only.
- Document the release procedure in `docs/releasing.md` (bump version in `pubspec.yaml`,
  tag, push).

## Acceptance criteria
1. All workflows pass with no deprecation warnings; no generated or IDE files are tracked.
2. The API key is stored in secure storage on native platforms; the migration test passes.
3. `flutter analyze` and `flutter test` pass.
4. With Android secrets configured, two consecutive CI builds produce APKs that install
   over each other without uninstalling.
5. With the Apple secrets configured, a manual run of `release-ios.yml` delivers a build to
   TestFlight; without them it fails early with a clear message.
6. A `v*` tag creates a GitHub Release with the Android, Windows and macOS artifacts.
7. Every manual owner step is documented in `docs/`.

## Working rules
- One PR per section (A+B first, then C, D, E, F, G+H) or a clearly separated commit per
  section. Do not mix unrelated changes.
- If a step requires secrets or accounts you do not have, implement the workflow and docs,
  state what cannot be verified in the PR description, and do not invent values.
- Do not add features outside the scope above.
