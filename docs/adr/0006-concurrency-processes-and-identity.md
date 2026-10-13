# ADR 0006 – Background work, cross-process changes and build identity

- Status: accepted
- Date: 2026-10-09

## Context

A review before the open-source release of the Mac app found structural weaknesses:

1. All data work ran on the main thread (`ProjectsData` used `MainActor` as default isolation);
   backups, imports and 25 MB attachments blocked the UI.
2. The app did not notice changes the widget extension wrote to the shared store.
3. A task's status is stored twice (`statusRaw` and the column), with no repair after sync merges.
4. Dense sort keys rewrote every task of a column on each move (many CloudKit records/conflicts).
5. Unread comments depended on a device identifier that changes on reinstall.
6. `AppDependencies.shared` and a static intent provider were hidden global dependencies.
7. Personal identifiers (team ID, bundle IDs, App Group) were hard-coded.

## Decisions

| Topic | Decision |
|---|---|
| Background work | `ProjectsData` has no default isolation. `BackgroundStore` is a `ModelActor` with its own context (author `app.background`) that runs the same services for backups, CSV and attachments. |
| Cross-process changes | Every context sets an `author`. `ExternalChangeReader` reads SwiftData's persistent history since the last token, re-fetches changed tasks (which refreshes stale objects in place) and prunes processed history. The widget posts a Darwin notification (`StoreChangeSignal`); the app also reads on launch and when it becomes active. Verified with two containers on one file. |
| Consistency | `ConsistencyService.repair()` runs on launch and after external changes. The status is the source of truth; the column follows it. |
| Ordering | `SparseOrder`: keys with gaps of 2¹⁶. A move writes only the moved task; a used-up gap renumbers its column once. No schema change. Columns and custom fields stay dense (short lists, index-based UI). |
| Unread state | `Installation(id, installedAt)`: only comments written by another installation after this one was installed can be unread. |
| Dependency injection | `ProjectsApp.init` builds `AppDependencies` and passes it to the views (environment), the notification delegate (initializer) and App Intents (`AppDependencyManager` + `@Dependency`). The widget registers its own `IntentContext`. |
| Build identity | `Config/Projects.xcconfig` holds neutral defaults; `Config/Local.xcconfig` (ignored by Git) sets the team and bundle identifier. Everything else (widget, tests, App Group, iCloud container, log subsystem) is derived and read from the Info.plist at runtime. |

## Comparison with Stats

[Stats](https://github.com/exelban/stats) keeps its team ID and bundle identifiers in the Xcode
project; forks edit them. Its CI builds with `CODE_SIGNING_ALLOWED=NO`, and its release workflow
imports the Developer ID certificate and notarization credentials from GitHub secrets. Its App Group
uses the team prefix (`$(TeamIdentifierPrefix)eu.exelban.Stats.widgets`). Projects follows the same
App Group convention on macOS and the same secrets approach for releases, but keeps personal values
out of the repository entirely, so a fork builds without touching the project.

## Consequences

- Heavy operations no longer block the UI; their results reach the UI through the same history
  mechanism as widget changes, so there is one code path for "someone else wrote to the store".
- Unread state only covers comments that arrive after installing, by design.
- Changing `PROJECTS_BUNDLE_ID` moves the App Group, so existing local data stays in the old group.
