import Foundation
import SwiftData
import ProjectsCore

/// Receives notifications about task changes so that platform features (reminders, Spotlight,
/// widgets) stay in sync without the data layer knowing about them.
public protocol TaskChangeObserving: AnyObject {
    /// Called after a successful save with all tasks that were created or modified.
    func tasksDidChange(_ tasks: [TaskItem])
    /// Called after a successful save with the identifiers of all deleted tasks.
    func tasksWereDeleted(_ ids: [UUID])
}

/// The default observer that ignores all changes. Used by tests and the widget extension.
public final class NoopTaskChangeObserver: TaskChangeObserving {
    public init() {}
    public func tasksDidChange(_ tasks: [TaskItem]) {}
    public func tasksWereDeleted(_ ids: [UUID]) {}
}

/// Shared dependencies of all services. Injecting `now` and `calendar` keeps every service
/// deterministic in tests.
public struct ServiceEnvironment {
    public let context: ModelContext
    public let now: @Sendable () -> Date
    public let calendar: Calendar
    public let observer: any TaskChangeObserving
    /// This installation. Stored with new comments to tell comments synced from another device
    /// (unread until viewed) from the user's own.
    public let installation: Installation

    public init(
        context: ModelContext,
        now: @escaping @Sendable () -> Date = { Date.now },
        calendar: Calendar = .autoupdatingCurrent,
        observer: any TaskChangeObserving = NoopTaskChangeObserver(),
        installation: Installation = .unknown
    ) {
        self.context = context
        self.now = now
        self.calendar = calendar
        self.observer = observer
        self.installation = installation
    }

    /// Saves the context. On failure the pending changes are rolled back so that the UI never
    /// shows data that is not persisted.
    func save(changed: [TaskItem] = [], deleted: [UUID] = []) throws {
        do {
            try context.save()
        } catch {
            Log.persistence.error("Save failed: \(String(describing: error), privacy: .public)")
            context.rollback()
            throw ProjectsError.persistenceFailed
        }
        if !changed.isEmpty {
            observer.tasksDidChange(changed)
        }
        if !deleted.isEmpty {
            observer.tasksWereDeleted(deleted)
        }
    }

    func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) throws -> [Model] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.persistence.error("Fetch failed: \(String(describing: error), privacy: .public)")
            throw ProjectsError.persistenceFailed
        }
    }

    func count<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) throws -> Int {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            Log.persistence.error("Count failed: \(String(describing: error), privacy: .public)")
            throw ProjectsError.persistenceFailed
        }
    }
}
