# ADR 0002 – Persistence, schema versioning and iCloud sync

- Status: accepted
- Date: 2026-10-08

## Context

Version 1 had `@Attribute(.unique)` on every model, requested CloudKit with `.automatic` and used
delete rules that cascaded from children to parents (deleting a comment deleted its author and its
task). The store could not have been synced with CloudKit and data was lost on ordinary actions.

## Decision

1. **CloudKit-compatible schema**: every attribute has a default or is optional, every relationship
   is optional with an explicit inverse, no unique constraints. Identifiers are `UUID`s set at
   creation.
2. **Delete rules cascade from parent to child only** (workspace → projects → columns/tasks →
   subtasks/comments/attachments/activity). Links between peers (labels ↔ tasks, dependencies,
   column → tasks) use `.nullify`. Deleting a column moves its tasks first. Each rule has a test in
   `DeleteRuleTests`.
3. **Versioned schema**: `SchemaV1`, `SchemaV2` + `ProjectsMigrationPlan`. A released version is
   never edited; changes go into a new version plus a migration stage. While sync is enabled only
   lightweight stages are allowed, because CloudKit cannot run custom migration code on other devices.
   `SchemaV2` (2026-10-09) adds involved people, `TaskQuestion` and the unread state of comments
   (`authorDeviceID`, `isRead`) – all additive with defaults, verified by `MigrationTests`.
4. **Store location**: App Group container, shared read/write with the widget. Extensions open the
   store without CloudKit mirroring; only the app syncs.
5. **Sync**: private CloudKit database of the user. Status is observed through
   `NSPersistentCloudKitContainer.eventChangedNotification`. If the container cannot be opened with
   CloudKit (no entitlement, no account), the app falls back to the local store and shows "Unavailable".
6. **Conflicts**: CloudKit mirroring resolves conflicts per record with last-writer-wins.
   For a single-user app this is acceptable; invariants are restored on the next write
   (e.g. a task whose column was deleted elsewhere is placed into a matching column on move).
7. **Offline first**: all reads and writes are local; sync happens in the background.
8. **Failure handling**: if the store cannot be opened at all, a recovery screen offers to delete the
   local store (data in iCloud is downloaded again) instead of `fatalError`.

## Consequences

- Attachments use `@Attribute(.externalStorage)` and become CKAssets; they are limited to 25 MiB.
- The JSON backup format (`BackupDocument`) is versioned independently of the schema.
