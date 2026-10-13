# Release checklist (TestFlight / App Store)

These steps need the Apple Developer account and cannot be automated from this repository.

## One-time setup

1. In Xcode › target **Projects** › Signing & Capabilities, confirm the capabilities that the
   entitlement files already request (Xcode registers them for the App ID):
   - App Groups: `group.<PROJECTS_BUNDLE_ID>` on iOS, `<TEAM_ID>.<PROJECTS_BUNDLE_ID>` on macOS
     (derived in `Config/Projects.xcconfig` from your `Config/Local.xcconfig`)
   - iCloud › CloudKit, container `iCloud.<PROJECTS_BUNDLE_ID>` (see `Config/Projects.xcconfig`)
   - Push Notifications (CloudKit uses silent pushes)
   - Background Modes › Remote notifications (iOS)
2. Repeat App Groups for the target **ProjectsWidgets**.
3. In the [CloudKit Console](https://icloud.developer.apple.com), after running the app once with
   sync, **deploy the schema to Production**. Without this step, TestFlight and App Store builds
   cannot sync.
4. App Store Connect: create the app, privacy "Data Not Collected" (matches `PrivacyInfo.xcprivacy`).

## Every release

- [ ] CI green (lint, package tests, app + UI tests in English and German, localization check)
- [ ] `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` bumped
- [ ] If the schema changed: new `SchemaV…` + migration stage + test, CloudKit schema deployed
- [ ] Screenshots: `TEST_RUNNER_PROJECTS_SCREENSHOTS=1 xcodebuild test -scheme Projects -only-testing:ProjectsUITests/ScreenshotTests -destination '…'`
      (produces every screen in English and German)
- [ ] Product › Archive › Distribute App › TestFlight
- [ ] Release notes in English and German
