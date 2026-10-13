import Foundation
import ProjectsData

/// Forwards task changes from the data layer to every platform integration and bumps a
/// version counter that views use to refresh derived numbers (dashboard statistics).
final class PlatformTaskObserver: TaskChangeObserving {
    private let reminders: ReminderScheduler
    private let spotlight: SpotlightIndexer
    private let widgets: WidgetRefresher
    private let onChange: () -> Void

    init(reminders: ReminderScheduler, spotlight: SpotlightIndexer, widgets: WidgetRefresher, onChange: @escaping () -> Void) {
        self.reminders = reminders
        self.spotlight = spotlight
        self.widgets = widgets
        self.onChange = onChange
    }

    func tasksDidChange(_ tasks: [TaskItem]) {
        reminders.update(for: tasks)
        spotlight.index(tasks)
        widgets.setNeedsReload()
        onChange()
    }

    func tasksWereDeleted(_ ids: [UUID]) {
        reminders.cancel(taskIDs: ids)
        spotlight.remove(taskIDs: ids)
        widgets.setNeedsReload()
        onChange()
    }
}
