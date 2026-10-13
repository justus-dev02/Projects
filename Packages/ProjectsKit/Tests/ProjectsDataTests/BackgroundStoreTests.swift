import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

/// The background store runs on its own context; the main context sees its saves through the
/// history (see `ExternalChangeReader`).
@Suite("BackgroundStore")
struct BackgroundStoreTests {
    private func makeContainer() throws -> (ModelContainer, URL) {
        let directory = URL.temporaryDirectory.appending(path: "ProjectsBackground-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try PersistenceController.makeContainer(PersistenceConfiguration(
            storage: .file(directory.appending(path: PersistenceController.storeFileName))
        ))
        container.mainContext.author = StoreAuthor.app
        return (container, directory)
    }

    @Test("A backup imported in the background reaches the main context")
    func backupRoundTripInTheBackground() async throws {
        let (container, directory) = try makeContainer()
        defer { try? FileManager.default.removeItem(at: directory) }
        try DemoDataSeeder(environment: ServiceEnvironment(context: container.mainContext)).seed()
        let before = try container.mainContext.fetchCount(FetchDescriptor<TaskItem>())
        let store = BackgroundStore(container: container, installation: .unknown)

        let data = try await store.exportJSON()
        let (summary, result) = try await store.importJSON(data, mode: .replaceAll)

        #expect(summary.importedTasks == before)
        #expect(result.deletedTaskIDs.count == before, "Replacing reports the deleted tasks")
        #expect(result.changedTaskIDs.count == before, "Imported tasks are reported for Spotlight and reminders")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()) == before)
        #expect(!(try await store.exportCSV()).isEmpty)
    }

    @Test func attachmentsAreReadInTheBackground() async throws {
        let (container, directory) = try makeContainer()
        defer { try? FileManager.default.removeItem(at: directory) }
        let environment = ServiceEnvironment(context: container.mainContext)
        let workspace = try WorkspaceService(environment: environment).create(name: "W")
        let project = try ProjectService(environment: environment).create(ProjectDraft(name: "P"), in: workspace)
        let task = try TaskService(environment: environment).create(TaskDraft(title: "Task"), in: project)
        let file = directory.appending(path: "notes.txt")
        try Data("Hello".utf8).write(to: file)

        let store = BackgroundStore(container: container, installation: .unknown)
        let result = try await store.addAttachment(toTaskWithID: task.id, from: file)

        #expect(result.changedTaskIDs == [task.id])
        let id = task.id
        let attachments = try container.mainContext.fetch(FetchDescriptor<TaskAttachment>())
        #expect(attachments.count == 1)
        #expect(attachments.first?.task?.id == id)
        #expect(attachments.first?.contentType == "public.plain-text")
    }

    @Test func tooLargeAttachmentsAreRejectedBeforeReading() async throws {
        let (container, directory) = try makeContainer()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BackgroundStore(container: container, installation: .unknown)
        let file = directory.appending(path: "big.bin")
        FileManager.default.createFile(atPath: file.path(), contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(AttachmentPolicy.maxBytes + 1))
        try handle.close()

        await #expect(throws: ProjectsError.attachmentTooLarge(maxBytes: AttachmentPolicy.maxBytes)) {
            _ = try await store.addAttachment(toTaskWithID: UUID(), from: file)
        }
    }
}
