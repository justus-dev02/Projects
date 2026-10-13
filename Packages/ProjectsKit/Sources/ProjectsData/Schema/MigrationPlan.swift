import SwiftData

/// The ordered list of schema versions and the stages between them.
///
/// Adding a version:
/// 1. Copy the latest schema to a new `SchemaVn` and change the copy (never a released version).
/// 2. Point the typealiases in `CurrentSchema.swift` to the new version.
/// 3. Append the new version to `schemas` and a `MigrationStage` to `stages`.
///    Only lightweight stages are allowed while iCloud sync is enabled, because CloudKit
///    cannot replay custom migration code on other devices.
/// 4. Add a test that opens a store of the previous version with the new plan (see `MigrationTests`).
public enum ProjectsMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Adds involved people, questions and the unread state of comments. Every new attribute has
    /// a default value, so existing data needs no custom code.
    static var migrateV1toV2: MigrationStage {
        MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    }
}
