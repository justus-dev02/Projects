import AppIntents
import Foundation
import ProjectsCore
import ProjectsData

/// "Add a task in Projects" – works from Siri, Spotlight and the Shortcuts app without opening the app.
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a new task to a project.")

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Project")
    var project: ProjectEntity

    @Parameter(title: "Due Date")
    var dueDate: Date?

    /// Set by the system from `AppDependencyManager`; tests may set it directly.
    @Dependency var context: IntentContext

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) to \(\.$project)") {
            \.$dueDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TaskEntity> & ProvidesDialog {
        let environment = context.environment
        guard let target = try ProjectService(environment: environment).project(id: project.id) else {
            throw ProjectsError.notFound(.project)
        }
        let task = try TaskService(environment: environment).create(TaskDraft(title: title, dueDate: dueDate), in: target)
        let projectName = target.name
        return .result(value: TaskEntity(task), dialog: "Added to \(projectName).")
    }
}

/// Opens a task in the app.
struct OpenTaskIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Task"

    @Parameter(title: "Task")
    var target: TaskEntity

    /// Set by the system from `AppDependencyManager`; tests may set it directly.
    @Dependency var context: IntentContext

    @MainActor
    func perform() async throws -> some IntentResult {
        context.open?(.task(target.id))
        return .result()
    }
}

/// Opens the "Today" overview.
struct ShowTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Today"
    static let openAppWhenRun = true

    /// Set by the system from `AppDependencyManager`; tests may set it directly.
    @Dependency var context: IntentContext

    @MainActor
    func perform() async throws -> some IntentResult {
        context.open?(.today)
        return .result()
    }
}

/// Phrases for Siri and the Shortcuts app. They are localized in `AppShortcuts.xcstrings`.
nonisolated struct ProjectsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "New \(.applicationName) task",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ShowTodayIntent(),
            phrases: [
                "Show today in \(.applicationName)",
                "What is due in \(.applicationName)",
            ],
            shortTitle: "Today",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: ToggleTaskCompletionIntent(),
            phrases: [
                "Complete a task in \(.applicationName)",
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
    }
}
