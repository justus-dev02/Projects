import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

/// Two containers on the same file behave like the app and the widget extension.
@Suite("External changes")
struct ExternalChangeReaderTests {
    private struct Fixture {
        let app: ModelContainer
        let widget: ModelContainer
        let reader: ExternalChangeReader
        let directory: URL
    }

    private func makeFixture() throws -> Fixture {
        let directory = URL.temporaryDirectory.appending(path: "ProjectsHistory-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: PersistenceController.storeFileName)
        let app = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
        app.mainContext.author = StoreAuthor.app
        let widget = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
        widget.mainContext.author = StoreAuthor.widget
        let defaults = try #require(UserDefaults(suiteName: "ProjectsHistory-\(UUID().uuidString)"))
        let reader = ExternalChangeReader(context: app.mainContext, tokenStore: HistoryTokenStore(defaults: defaults))
        return Fixture(app: app, widget: widget, reader: reader, directory: directory)
    }

    private func makeTask(in container: ModelContainer) throws -> TaskItem {
        let environment = ServiceEnvironment(context: container.mainContext)
        let workspace = try WorkspaceService(environment: environment).create(name: "W")
        let project = try ProjectService(environment: environment).create(ProjectDraft(name: "P"), in: workspace)
        return try TaskService(environment: environment).create(TaskDraft(title: "Task"), in: project)
    }

    @Test("A task completed by the widget is updated in the app")
    func widgetChangesReachTheApp() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let task = try makeTask(in: fixture.app)
        try fixture.reader.mergeChanges() // first call only remembers the position

        let id = task.id
        let widgetTask = try #require(try fixture.widget.mainContext.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })).first)
        try TaskService(environment: ServiceEnvironment(context: fixture.widget.mainContext)).setStatus(widgetTask, to: .done)
        #expect(task.status == .todo, "Without merging, the app shows stale data")

        let changes = try fixture.reader.mergeChanges()

        #expect(changes.transactionCount == 1)
        #expect(changes.taskIDs == [id])
        #expect(task.status == .done)
    }

    @Test func theAppsOwnChangesAreSkipped() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.reader.mergeChanges()
        _ = try makeTask(in: fixture.app)

        #expect(try fixture.reader.mergeChanges().isEmpty)
    }

    @Test func eachChangeIsReportedOnce() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try fixture.reader.mergeChanges()
        _ = try makeTask(in: fixture.widget)

        #expect(try fixture.reader.mergeChanges().transactionCount > 0)
        #expect(try fixture.reader.mergeChanges().isEmpty)
    }
}
