import CoreSpotlight
import Foundation
import OSLog
import SwiftData
import ProjectsCore
import ProjectsData
import UniformTypeIdentifiers

/// The subset of `CSSearchableIndex` the app uses, so indexing logic can be tested.
protocol SearchIndexClient: AnyObject {
    func indexSearchableItems(_ items: [CSSearchableItem]) async throws
    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws
    func deleteAllSearchableItems() async throws
}

extension CSSearchableIndex: SearchIndexClient {}

/// Makes tasks findable in system search. Selecting a result opens the task through its
/// deep link, which is used as the item's unique identifier.
final class SpotlightIndexer {
    static let domainIdentifier = "\(SharedConfiguration.logSubsystem).tasks"

    private let index: SearchIndexClient
    private let logger = Logger(subsystem: SharedConfiguration.logSubsystem, category: "spotlight")

    init(index: SearchIndexClient) {
        self.index = index
    }

    static func item(for task: TaskItem) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = task.title
        var description = [task.project?.name, task.status.title].compactMap(\.self)
        if !task.details.isEmpty {
            description.append(task.details)
        }
        attributes.contentDescription = description.joined(separator: " · ")
        attributes.dueDate = task.dueDate
        attributes.keywords = task.sortedLabels.map(\.name)
        attributes.contentModificationDate = task.updatedAt
        let item = CSSearchableItem(
            uniqueIdentifier: task.deepLink.url.absoluteString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        // Completed tasks drop out of search results after a while.
        if task.isCompleted {
            item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: task.completedAt ?? .now)
        }
        return item
    }

    func index(_ tasks: [TaskItem]) {
        let items = tasks.map(Self.item(for:))
        guard !items.isEmpty else { return }
        Task {
            do {
                try await index.indexSearchableItems(items)
            } catch {
                logger.error("Indexing failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func remove(taskIDs: [UUID]) {
        let identifiers = taskIDs.map { DeepLink.task($0).url.absoluteString }
        guard !identifiers.isEmpty else { return }
        Task {
            try? await index.deleteSearchableItems(withIdentifiers: identifiers)
        }
    }

    /// Rebuilds the whole index in batches.
    func reindexAll(context: ModelContext) async {
        do {
            try await index.deleteAllSearchableItems()
            var descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt)])
            descriptor.fetchLimit = 500
            var offset = 0
            while true {
                descriptor.fetchOffset = offset
                let batch = try context.fetch(descriptor)
                guard !batch.isEmpty else { break }
                try await index.indexSearchableItems(batch.map(Self.item(for:)))
                offset += batch.count
            }
            logger.info("Spotlight index rebuilt with \(offset) tasks")
        } catch {
            logger.error("Rebuilding the index failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
