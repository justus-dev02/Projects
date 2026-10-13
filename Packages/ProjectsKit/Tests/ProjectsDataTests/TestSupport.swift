import Foundation
import SwiftData
import ProjectsCore
@testable import ProjectsData

/// Records observer callbacks so tests can assert that platform side effects are triggered.
final class ObserverSpy: TaskChangeObserving {
    private(set) var changedIDs: [UUID] = []
    private(set) var deletedIDs: [UUID] = []

    func tasksDidChange(_ tasks: [TaskItem]) {
        changedIDs += tasks.map(\.id)
    }

    func tasksWereDeleted(_ ids: [UUID]) {
        deletedIDs += ids
    }
}

/// A complete, isolated in-memory stack with a fixed clock and calendar.
final class TestStack {
    let container: ModelContainer
    let environment: ServiceEnvironment
    let observer = ObserverSpy()
    let calendar: Calendar
    let now: Date
    let installation: Installation

    lazy var workspaces = WorkspaceService(environment: environment)
    lazy var projects = ProjectService(environment: environment)
    lazy var tasks = TaskService(environment: environment)
    lazy var templates = TemplateService(environment: environment, taskService: tasks)
    lazy var dashboard = DashboardService(environment: environment)
    lazy var backup = BackupService(environment: environment)

    var context: ModelContext { container.mainContext }

    init(now: Date? = nil, deviceID: String = "test-device") throws {
        self.installation = Installation(id: deviceID, installedAt: .distantPast)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "de_DE")
        calendar.firstWeekday = 2
        self.calendar = calendar
        let fixedNow = now ?? calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 12))!
        self.now = fixedNow
        container = try PersistenceController.makeContainer(.inMemory)
        environment = ServiceEnvironment(
            context: container.mainContext,
            now: { fixedNow },
            calendar: calendar,
            observer: observer,
            installation: Installation(id: deviceID, installedAt: .distantPast)
        )
    }

    func date(dayOffset: Int, hour: Int = 12) -> Date {
        let start = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: start)!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    /// A workspace with one project using the default four columns.
    func makeProject(name: String = "Project") throws -> (Workspace, Project) {
        let workspace = try workspaces.create(name: "Workspace")
        let project = try projects.create(ProjectDraft(name: name), in: workspace)
        return (workspace, project)
    }

    func count<Model: PersistentModel>(_ type: Model.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }

    func column(_ project: Project, _ status: TaskStatus) -> BoardColumn {
        project.firstColumn(for: status)!
    }
}
