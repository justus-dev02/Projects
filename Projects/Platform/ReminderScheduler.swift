import Foundation
import OSLog
import SwiftData
import ProjectsCore
import ProjectsData
import UserNotifications

/// The subset of `UNUserNotificationCenter` the app uses. Abstracted so that scheduling logic is
/// testable without a real notification center.
protocol NotificationCenterClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
    func pendingRequestIdentifiers() async -> [String]
    func setCategories(_ categories: Set<UNNotificationCategory>)
}

final class SystemNotificationCenter: NotificationCenterClient {
    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingRequestIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }
}

/// A reminder the app wants to be scheduled.
struct PlannedReminder: Equatable {
    let identifier: String
    let taskID: UUID
    let title: String
    let body: String
    let date: Date
}

/// Keeps local notifications in sync with the reminder dates of tasks.
@Observable
final class ReminderScheduler {
    nonisolated static let categoryIdentifier = "TASK_REMINDER"
    nonisolated static let completeActionIdentifier = "COMPLETE_TASK"
    nonisolated static let snoozeActionIdentifier = "SNOOZE_TASK"
    nonisolated static let taskIDKey = "taskID"
    /// iOS keeps at most 64 pending notifications per app.
    nonisolated static let maximumPending = 60

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: NotificationCenterClient
    private let now: () -> Date
    private let logger = Logger(subsystem: SharedConfiguration.logSubsystem, category: "reminders")

    init(center: NotificationCenterClient, now: @escaping () -> Date = { .now }) {
        self.center = center
        self.now = now
    }

    static func identifier(for taskID: UUID) -> String {
        "reminder-\(taskID.uuidString)"
    }

    static func taskID(fromIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix("reminder-") else { return nil }
        return UUID(uuidString: String(identifier.dropFirst("reminder-".count)))
    }

    /// The reminder for a task, or `nil` when it should not be scheduled.
    static func plan(for task: TaskItem, now: Date) -> PlannedReminder? {
        guard let date = task.reminderDate, date > now, !task.isCompleted else { return nil }
        let body: String
        if let due = task.dueDate {
            let formatted = due.formatted(date: .abbreviated, time: .shortened)
            body = String(localized: "Due \(formatted)", comment: "Reminder notification body")
        } else if let project = task.project?.name {
            body = project
        } else {
            body = String(localized: "Reminder", comment: "Reminder notification body")
        }
        return PlannedReminder(identifier: identifier(for: task.id), taskID: task.id, title: task.title, body: body, date: date)
    }

    func registerCategories() {
        let complete = UNNotificationAction(
            identifier: Self.completeActionIdentifier,
            title: String(localized: "Mark as Done"),
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionIdentifier,
            title: String(localized: "Remind Me in 1 Hour"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setCategories([category])
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.authorizationStatus()
    }

    /// Asks for permission if the user has not decided yet.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorized || authorizationStatus == .provisional
        }
        do {
            let granted = try await center.requestAuthorization()
            await refreshAuthorizationStatus()
            return granted
        } catch {
            logger.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Schedules or cancels the reminders of the given tasks.
    func update(for tasks: [TaskItem]) {
        let plans = tasks.map { ($0.id, Self.plan(for: $0, now: now())) }
        let toRemove = plans.filter { $0.1 == nil }.map { Self.identifier(for: $0.0) }
        if !toRemove.isEmpty {
            center.removePendingRequests(withIdentifiers: toRemove)
        }
        let toAdd = plans.compactMap(\.1)
        guard !toAdd.isEmpty else { return }
        Task {
            for plan in toAdd {
                await add(plan)
            }
        }
    }

    func cancel(taskIDs: [UUID]) {
        center.removePendingRequests(withIdentifiers: taskIDs.map(Self.identifier(for:)))
    }

    /// Rebuilds the schedule from the database, e.g. after launch or after a sync brought in
    /// changes from another device. Only the next ``maximumPending`` reminders are scheduled.
    func reconcile(context: ModelContext) async {
        let tasks: [TaskItem]
        do {
            tasks = try context.fetch(TaskQueries.upcomingReminders(now: now(), limit: Self.maximumPending))
        } catch {
            logger.error("Reconciling reminders failed")
            return
        }
        let plans = tasks.compactMap { Self.plan(for: $0, now: now()) }
        let wanted = Set(plans.map(\.identifier))
        let pending = await center.pendingRequestIdentifiers().filter { Self.taskID(fromIdentifier: $0) != nil }
        let obsolete = pending.filter { !wanted.contains($0) }
        if !obsolete.isEmpty {
            center.removePendingRequests(withIdentifiers: obsolete)
        }
        for plan in plans {
            await add(plan)
        }
    }

    private func add(_ plan: PlannedReminder) async {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [Self.taskIDKey: plan.taskID.uuidString]
        content.targetContentIdentifier = DeepLink.task(plan.taskID).url.absoluteString

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // Adding a request with an existing identifier replaces it.
        let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            logger.error("Scheduling a reminder failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
