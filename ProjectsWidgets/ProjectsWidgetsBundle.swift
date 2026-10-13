import AppIntents
import OSLog
import SwiftUI
import WidgetKit

@main
struct ProjectsWidgetsBundle: WidgetBundle {
    /// Intents that run in the extension (e.g. completing a task from the widget) receive the
    /// shared store through `@Dependency`.
    init() {
        do {
            let context = try IntentContext.sharedStore()
            AppDependencyManager.shared.add(dependency: context)
        } catch {
            Logger(subsystem: SharedConfiguration.logSubsystem, category: "widget")
                .error("The shared store could not be opened for intents")
        }
    }

    var body: some Widget {
        TodayTasksWidget()
    }
}
