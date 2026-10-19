# Umrah Trip — Setup & Build Guide

## Prerequisites
- Flutter stable (3.24+), Dart 3.5+
- Android: JDK 17, Android SDK
- iOS: macOS + Xcode 16+ (CI's macOS runner covers this if you don't have a Mac)
- Python 3 (for the platform patch script)

## 1. Bootstrap the platforms
`android/` and `ios/` are generated, not committed:

```bash
cd app
bash ../scripts/bootstrap_platforms.sh
```

This runs `flutter create` (org `com.bwpexperts`, project `umrah_journey`), then:
- adds Android permissions (INTERNET, FINE/COARSE location) and the Google Maps `meta-data` key,
- sets the app label/display name to **Umrah Trip**,
- adds iOS `NSLocationWhenInUseUsageDescription`, maps URL query schemes, Podfile `platform :ios, '14.0'`,
- wires `GMSServices.provideAPIKey` (only when a key is present),
- generates launcher icons from `assets/images/logo.png` (Android adaptive icon on emerald `#086B58`).

## 2. Environment / keys
No secrets are committed. Supply keys at build time:

| Variable | Where | Purpose |
| --- | --- | --- |
| `MAPS_API_KEY` | env var for the bootstrap/patch step **and** `--dart-define` at build | Google Maps SDK (in-app live map). Optional — without it the Map tab shows a setup card and a distance-sorted list; one-tap external navigation works regardless. |

Local example:

```bash
export MAPS_API_KEY=AIza...        # before bootstrap (injects into manifests)
flutter run --dart-define=MAPS_API_KEY=$MAPS_API_KEY
```

CI: add `MAPS_API_KEY` as a GitHub **repository secret** — both workflows pick it up automatically.

A `.env.example` is provided at the repo root for the upcoming Laravel backend phase.

## 3. Android release builds

```bash
cd app
flutter build apk --release --dart-define=MAPS_API_KEY=$MAPS_API_KEY
flutter build appbundle --release --dart-define=MAPS_API_KEY=$MAPS_API_KEY
```

Outputs: `build/app/outputs/flutter-apk/app-release.apk`, `build/app/outputs/bundle/release/app-release.aab`.
CI (`.github/workflows/android-build.yml`) builds and uploads both on every push to `main` and also runs `flutter analyze` + unit tests.

> Play Store upload needs your own keystore; the default build is debug-signed for testing. Add a `key.properties` + signingConfig when you're ready to publish.

## 4. iOS builds & the IPA

### Unsigned IPA (no Apple account needed — for sideload testing)
CI (`.github/workflows/ios-build.yml`) runs on a macOS runner:
`flutter build ios --release --no-codesign`, wraps `Runner.app` into `Payload/`, zips it as **`UmrahTrip-unsigned.ipa`** and uploads it as an artifact.
Install on your iPhone with **AltStore** or **Sideloadly** (they re-sign with your Apple ID; apps last 7 days on a free ID).

### iOS signing (signed IPA / TestFlight)
Requires an Apple Developer Program membership ($99/yr):
1. Create an App ID `com.bwpexperts.umrahJourney` (check the generated `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj`), a Distribution certificate (.p12) and a provisioning profile.
2. Add GitHub secrets: `IOS_CERT_P12_BASE64`, `IOS_CERT_PASSWORD`, `IOS_PROVISION_BASE64`, `APPSTORE_ISSUER_ID`/`KEY_ID`/`PRIVATE_KEY` (if uploading).
3. In the iOS workflow: import certs with `apple-actions/import-codesign-certs`, install the profile, then replace the build step with
   `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`.
4. Upload with `xcrun altool`/`xcrun notarytool` or `apple-actions/upload-testflight-build`.

Per project policy, a signed IPA is only produced where valid Apple signing credentials exist — CI never fakes signing.

## 5. Tests

```bash
cd app && flutter test
```

Covers itinerary management (add/reorder/remove days & visits, date queries) and visit tracking (status transitions, counters, undo, serialization) — the spec's required automated tests.

## 6. Data verification workflow
`app/assets/data/destinations.json` stores per-destination `verified`, `source_url`, `last_verified`, plus `fee_verified` / `hours_verified`. The UI surfaces unverified items with an explicit badge. When editing data: verify against a trustworthy source, update `last_verified`, and never invent coordinates, prices or hours — leave them `null`/`false` instead.
