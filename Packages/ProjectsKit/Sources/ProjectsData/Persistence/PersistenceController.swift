import Foundation
import SwiftData
import ProjectsCore

/// Where and how the store is opened.
public struct PersistenceConfiguration: Sendable, Equatable {
    public enum Storage: Sendable, Equatable {
        case inMemory
        case file(URL)
    }

    public enum Sync: Sendable, Equatable {
        case disabled
        /// Mirrors the store into the private database of the given iCloud container.
        case iCloud(containerIdentifier: String)
    }

    public var storage: Storage
    public var sync: Sync

    public init(storage: Storage, sync: Sync = .disabled) {
        self.storage = storage
        self.sync = sync
    }

    public static let inMemory = PersistenceConfiguration(storage: .inMemory)
}

/// Creates the `ModelContainer` for the app, the widget extension and tests.
public enum PersistenceController {
    public static let storeFileName = "Projects.store"

    public static var schema: Schema {
        Schema(versionedSchema: CurrentSchema.self)
    }

    /// The store location shared between app and widget.
    ///
    /// Uses the App Group container when the entitlement is present and falls back to the
    /// app's own Application Support directory otherwise (e.g. unsigned CI builds).
    public static func defaultStoreURL(appGroupIdentifier: String?) -> URL {
        let fileManager = FileManager.default
        let directory: URL
        var legacyDirectory: URL?
        if let appGroupIdentifier,
           let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            directory = groupURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        } else {
            directory = URL.applicationSupportDirectory.appending(path: "Projects", directoryHint: .isDirectory)
            legacyDirectory = URL.applicationSupportDirectory.appending(path: legacyName, directoryHint: .isDirectory)
        }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Log.persistence.error("Could not create store directory: \(error.localizedDescription, privacy: .public)")
        }
        let storeURL = directory.appending(path: storeFileName, directoryHint: .notDirectory)
        adoptLegacyStore(from: legacyDirectory ?? directory, to: storeURL)
        return storeURL
    }

    // MARK: Store from before the rename

    /// The app's former name. Stores created before the rename are named after it.
    static let legacyName = "TaskFlow"
    static let legacyStoreFileName = "\(legacyName).store"

    /// Moves a store created under the former name to `storeURL`, so existing data is kept.
    ///
    /// Moves the SQLite file with its `-wal` and `-shm` companions and the folder SwiftData uses for
    /// external storage (attachments). Does nothing when a store already exists at `storeURL`.
    static func adoptLegacyStore(from directory: URL, to storeURL: URL, fileManager: FileManager = .default) {
        let legacyStore = directory.appending(path: legacyStoreFileName, directoryHint: .notDirectory)
        guard fileManager.fileExists(atPath: legacyStore.path()),
              !fileManager.fileExists(atPath: storeURL.path()) else { return }
        let target = storeURL.deletingLastPathComponent()
        let moves = ["", "-wal", "-shm"].map { suffix in
            (legacyStore.path() + suffix, target.appending(path: storeFileName + suffix).path())
        } + [(
            directory.appending(path: ".\(legacyName)_SUPPORT").path(),
            target.appending(path: ".\(storeFileName.replacingOccurrences(of: ".store", with: ""))_SUPPORT").path()
        )]
        do {
            for (source, destination) in moves where fileManager.fileExists(atPath: source) {
                try fileManager.moveItem(atPath: source, toPath: destination)
            }
            Log.persistence.notice("Adopted the store from before the rename")
        } catch {
            Log.persistence.error("Could not adopt the old store: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Opens (and, if necessary, migrates) the store.
    /// - Throws: ``ProjectsError/storeUnavailable`` when the store cannot be opened.
    public static func makeContainer(_ configuration: PersistenceConfiguration) throws -> ModelContainer {
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = switch configuration.sync {
        case .disabled: .none
        case .iCloud(let identifier): .private(identifier)
        }

        let modelConfiguration: ModelConfiguration = switch configuration.storage {
        case .inMemory:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .file(let url):
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: cloudKitDatabase)
        }

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ProjectsMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            Log.persistence.fault("Opening the store failed: \(String(describing: error), privacy: .public)")
            throw ProjectsError.storeUnavailable
        }
    }

    /// Deletes the SQLite store and its side files. Only used for the explicit
    /// "Reset local database" recovery action.
    public static func destroyStore(at url: URL) throws {
        let fileManager = FileManager.default
        let candidates = [url, URL(filePath: url.path() + "-shm"), URL(filePath: url.path() + "-wal")]
        for file in candidates where fileManager.fileExists(atPath: file.path()) {
            try fileManager.removeItem(at: file)
        }
        let externalStorage = url.deletingLastPathComponent().appending(path: ".Projects_SUPPORT", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: externalStorage.path()) {
            try fileManager.removeItem(at: externalStorage)
        }
        Log.persistence.notice("Local store deleted")
    }
}
