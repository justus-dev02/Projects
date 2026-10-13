import Foundation
import SwiftData
import ProjectsCore
import UniformTypeIdentifiers

/// Runs heavy work on its own context off the main thread: backups, imports, CSV exports and
/// attachments (files of up to 25 MB).
///
/// It uses the same services as the UI, on a context with the author ``StoreAuthor/appBackground``.
/// The app picks up the saved changes through ``ExternalChangeReader`` and then updates reminders,
/// Spotlight and widgets for the tasks reported in ``Result``.
public actor BackgroundStore: ModelActor {
    /// The tasks a background operation changed or deleted, for platform integrations.
    public struct Result: Equatable, Sendable {
        public var changedTaskIDs: [UUID] = []
        public var deletedTaskIDs: [UUID] = []
    }

    nonisolated public let modelExecutor: any ModelExecutor
    nonisolated public let modelContainer: ModelContainer
    private let installation: Installation

    public init(container: ModelContainer, installation: Installation) {
        let context = ModelContext(container)
        context.author = StoreAuthor.appBackground
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        modelContainer = container
        self.installation = installation
    }

    // MARK: Backup and export

    public func exportJSON() throws -> Data {
        try BackupService(environment: makeEnvironment().environment).exportJSON()
    }

    public func exportCSV() throws -> Data {
        try CSVExportService(environment: makeEnvironment().environment).exportTasks()
    }

    /// Reads a backup file (possibly security scoped, from a file importer) and restores it.
    public func importJSON(from url: URL, mode: BackupService.ImportMode) throws -> (BackupService.ImportSummary, Result) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        return try importJSON(Data(contentsOf: url), mode: mode)
    }

    public func importJSON(_ data: Data, mode: BackupService.ImportMode) throws -> (BackupService.ImportSummary, Result) {
        let (environment, recorder) = makeEnvironment()
        let summary = try BackupService(environment: environment).importJSON(data, mode: mode)
        return (summary, recorder.result)
    }

    // MARK: Attachments

    /// Reads a file and attaches it to a task. The file is read here, not on the main thread.
    /// - Parameter url: A file URL, possibly security scoped (from a file importer).
    public func addAttachment(toTaskWithID taskID: UUID, from url: URL) throws -> Result {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        try AttachmentPolicy.validate(byteCount: values.fileSize ?? 0)
        let data = try Data(contentsOf: url)
        let type = values.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data

        let (environment, recorder) = makeEnvironment()
        let service = TaskService(environment: environment)
        guard let task = try service.task(id: taskID) else { throw ProjectsError.notFound(.task) }
        try service.addAttachment(to: task, fileName: url.lastPathComponent, contentType: type.identifier, data: data)
        return recorder.result
    }

    // MARK: Internals

    private func makeEnvironment() -> (environment: ServiceEnvironment, recorder: ChangeRecorder) {
        let recorder = ChangeRecorder()
        return (ServiceEnvironment(context: modelContext, observer: recorder, installation: installation), recorder)
    }
}

/// Collects the task changes of one background operation instead of acting on them, because
/// reminders, Spotlight and widgets are updated by the app on the main thread.
private final class ChangeRecorder: TaskChangeObserving {
    private var changed: [UUID] = []
    private var deleted: [UUID] = []

    var result: BackgroundStore.Result {
        BackgroundStore.Result(changedTaskIDs: changed, deletedTaskIDs: deleted)
    }

    func tasksDidChange(_ tasks: [TaskItem]) {
        changed += tasks.map(\.id)
    }

    func tasksWereDeleted(_ ids: [UUID]) {
        deleted += ids
    }
}
