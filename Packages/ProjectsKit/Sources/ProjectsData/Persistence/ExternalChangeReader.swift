import Foundation
import SwiftData

/// Brings changes written by other processes (the widget, a background context) into a context.
///
/// A `ModelContext` keeps the objects it has loaded in memory. When another process changes the
/// store, those objects stay stale until they are fetched again. This reader uses SwiftData's
/// persistent history: it finds the transactions of other authors since the last call and fetches
/// the changed tasks again, which updates the objects (and with them the views) in place.
public final class ExternalChangeReader {
    /// What changed since the last call.
    public struct Changes: Equatable, Sendable {
        public var transactionCount = 0
        /// Identifiers of tasks that were inserted or updated. Deleted tasks are not included.
        public var taskIDs: Set<UUID> = []

        public var isEmpty: Bool { transactionCount == 0 }
    }

    private let context: ModelContext
    private let tokenStore: HistoryTokenStore

    /// - Parameters:
    ///   - context: The context to refresh. Its `author` must be set; its own transactions are skipped.
    ///   - tokenStore: Where the position in the history is kept between launches.
    public init(context: ModelContext, tokenStore: HistoryTokenStore) {
        self.context = context
        self.tokenStore = tokenStore
    }

    /// Reads the history since the last call and fetches changed tasks again.
    ///
    /// On the very first call there is no position yet: the reader only remembers the newest
    /// transaction, because everything before it is already in the store the context reads.
    @discardableResult
    public func mergeChanges() throws -> Changes {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        switch tokenStore.load() {
        case .neverRead:
            tokenStore.save(.readUpTo(try context.fetchHistory(descriptor).last?.token))
            return Changes()
        case .readUpTo(let token?):
            descriptor.predicate = #Predicate { $0.token > token }
        case .readUpTo(nil):
            break // The history was empty last time: everything in it now is new.
        }
        let transactions = try context.fetchHistory(descriptor)
        guard let newest = transactions.last else { return Changes() }

        let ownAuthor = context.author
        var changes = Changes()
        var changedTasks: [PersistentIdentifier] = []
        for transaction in transactions where transaction.author != ownAuthor {
            changes.transactionCount += 1
            for change in transaction.changes {
                switch change {
                case .insert(let insert as DefaultHistoryInsert<TaskItem>):
                    changedTasks.append(insert.changedPersistentIdentifier)
                case .update(let update as DefaultHistoryUpdate<TaskItem>):
                    changedTasks.append(update.changedPersistentIdentifier)
                default:
                    continue
                }
            }
        }

        if !changedTasks.isEmpty {
            let identifiers = Set(changedTasks)
            // Fetching refreshes objects the context has already loaded.
            let refreshed = try context.fetch(FetchDescriptor<TaskItem>(
                predicate: #Predicate { identifiers.contains($0.persistentModelID) }
            ))
            changes.taskIDs = Set(refreshed.map(\.id))
        }
        tokenStore.save(.readUpTo(newest.token))
        try pruneHistory(before: newest.token)
        return changes
    }

    /// Removes history this reader has processed, so the store does not grow forever. Only safe
    /// because the app is the single reader; extensions never read history.
    private func pruneHistory(before token: DefaultHistoryToken) throws {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        descriptor.predicate = #Predicate { $0.token < token }
        try context.deleteHistory(descriptor)
    }
}

/// Persists the position in the history between launches.
public struct HistoryTokenStore {
    public enum Position {
        /// The history was never read; the first read only records the current end.
        case neverRead
        /// Everything up to the token was processed (`nil`: the history was empty).
        case readUpTo(DefaultHistoryToken?)
    }

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults, key: String = "historyToken") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Position {
        guard let data = defaults.data(forKey: key) else { return .neverRead }
        return .readUpTo(try? JSONDecoder().decode(DefaultHistoryToken.self, from: data))
    }

    public func save(_ position: Position) {
        switch position {
        case .neverRead:
            defaults.removeObject(forKey: key)
        case .readUpTo(let token):
            // An empty value marks "read, history was empty".
            defaults.set(token.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key)
        }
    }
}

/// Authors of the contexts that write to the store. The history records them, so every process
/// can tell its own changes from those of others.
public enum StoreAuthor {
    public static let app = "app"
    public static let appBackground = "app.background"
    public static let widget = "widget"
}
