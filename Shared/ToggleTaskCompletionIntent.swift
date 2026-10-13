import AppIntents
import Foundation
import ProjectsCore
import ProjectsData
import WidgetKit

/// Marks a task as done (or open again). Runs without opening the app, which makes it usable
/// from interactive widgets, Siri and the Shortcuts app.
struct ToggleTaskCompletionIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription("Marks a task as done, or reopens a completed task.")

    @Parameter(title: "Task")
    var task: TaskEntity

    @Dependency private var context: IntentContext

    init() {}

    init(task: TaskEntity) {
        self.task = task
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle completion of \(\.$task)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = TaskService(environment: context.environment)
        guard let item = try service.task(id: task.id) else {
            throw ProjectsError.notFound(.task)
        }
        try service.toggleCompletion(item)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfiguration.todayWidgetKind)
        // When this runs in the widget extension, the running app picks the change up right away.
        StoreChangeSignal.post()
        let title = item.title
        return .result(dialog: item.isCompleted ? "Completed “\(title)”." : "Reopened “\(title)”.")
    }
}
