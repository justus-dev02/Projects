//
//  NotificationService.swift
//  Projects
//
//  TaskFlow - Local Notifications & Push Notifications Service
//

import Foundation
import UserNotifications
import Combine

#if os(iOS)
import UIKit
#endif

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func scheduleTaskReminder(task: Projects.Task, date: Date)
    func cancelReminder(for task: Projects.Task)
    func cancelAllReminders()
    func scheduleDueDateReminder(task: Projects.Task)
    func scheduleOverdueNotification(task: Projects.Task)
}

// MARK: - Notification Service Implementation
@MainActor
final class NotificationService: NotificationServiceProtocol, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private let center: UNUserNotificationCenter
    private var cancellables = Set<AnyCancellable>()
    
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        checkAuthorization()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            #if os(iOS)
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            #endif
            
            return granted
        } catch {
            throw NotificationError.authorizationFailed
        }
    }
    
    private func checkAuthorization() {
        center.getNotificationSettings { settings in
            // FIXED: Used _Concurrency.Task to perfectly disambiguate from Projects.Task
            _Concurrency.Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Load Pending Notifications
    func loadPendingNotifications() {
        center.getPendingNotificationRequests { requests in
            // FIXED: Used _Concurrency.Task to perfectly disambiguate from Projects.Task
            _Concurrency.Task { @MainActor in
                self.pendingNotifications = requests
            }
        }
    }
    
    // MARK: - Schedule Task Reminder
    func scheduleTaskReminder(task: Projects.Task, date: Date) {
        guard isAuthorized else { return }
        guard date > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "\(task.title) is due soon"
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskId": task.id, "taskTitle": task.title]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "task_reminder_\(task.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling reminder: \(error)")
            }
        }
    }
    
    // MARK: - Schedule Due Date Reminder
    func scheduleDueDateReminder(task: Projects.Task) {
        guard let dueDate = task.dueDate else { return }
        guard task.reminderEnabled else { return }
        
        // Schedule reminder 1 hour before due date
        let reminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate) ?? dueDate
        scheduleTaskReminder(task: task, date: reminderDate)
    }
    
    // MARK: - Schedule Overdue Notification
    func scheduleOverdueNotification(task: Projects.Task) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Overdue"
        content.body = "\(task.title) is now overdue!"
        content.sound = .default
        content.categoryIdentifier = "TASK_OVERDUE"
        content.userInfo = ["taskId": task.id, "taskTitle": task.title]
        
        // Schedule for the due date time
        guard let dueDate = task.dueDate else { return }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "task_overdue_\(task.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    // MARK: - Cancel Reminder
    func cancelReminder(for task: Projects.Task) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "task_reminder_\(task.id)",
            "task_overdue_\(task.id)"
        ])
    }
    
    // MARK: - Cancel All Reminders
    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Schedule Recurring Task Notification
    func scheduleRecurringTaskNotification(task: Projects.Task, nextDate: Date) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Recurring Task"
        content.body = "New instance of \"\(task.title)\" has been created"
        content.sound = .default
        content.categoryIdentifier = "RECURRING_TASK"
        content.userInfo = ["taskId": task.id, "isRecurring": true]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "recurring_task_\(task.id)_\(nextDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    // MARK: - Handle Notification Response
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        if let taskId = userInfo["taskId"] as? String {
            // Post notification for app to handle
            NotificationCenter.default.post(
                name: .openTaskDetail,
                object: nil,
                userInfo: ["taskId": taskId]
            )
        }
    }
}

// MARK: - Notification Errors
enum NotificationError: LocalizedError {
    case authorizationFailed
    case schedulingFailed
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Failed to get notification authorization"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .notAuthorized:
            return "Notifications are not authorized"
        }
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let openTaskDetail = Notification.Name("openTaskDetail")
}

// MARK: - UNNotificationCategory Setup
extension NotificationService {
    static func setupNotificationCategories() {
        let taskReminderCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_TASK",
                    title: "View Task",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "Snooze",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let taskOverdueCategory = UNNotificationCategory(
            identifier: "TASK_OVERDUE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_TASK",
                    title: "View Task",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "MARK_COMPLETE",
                    title: "Mark Complete",
                    options: .destructive
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            taskReminderCategory,
            taskOverdueCategory
        ])
    }
}

// MARK: - Email Notification Service
@MainActor
final class EmailNotificationService {
    static let shared = EmailNotificationService(dataService: DataService())
    
    private let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func sendTaskAssignmentEmail(task: Projects.Task, assignee: Projects.User) async {
        // In production, this would send via an email service
        // For now, we'll create a notification
        let notification = NotificationModel(
            title: "Task Assigned",
            message: "You were assigned to \"\(task.title)\"",
            type: "assignment",
            isActionable: true
        )
        notification.recipient = assignee
        notification.task = task
        
        dataService.insert(notification)
        try? dataService.save()
    }
    
    func sendDueDateReminderEmail(task: Projects.Task, assignee: Projects.User) async {
        let notification = NotificationModel(
            title: "Task Due Soon",
            message: "\"\(task.title)\" is due \(formatDueDate(task.dueDate))",
            type: "dueDate"
        )
        notification.recipient = assignee
        notification.task = task
        
        dataService.insert(notification)
        try? dataService.save()
    }
    
    func sendMentionNotification(comment: Comment, mentionedUser: Projects.User) async {
        let notification = NotificationModel(
            title: "You were mentioned",
            message: "\(comment.author?.displayName ?? "Someone") mentioned you in a comment",
            type: "mention",
            isActionable: true
        )
        notification.recipient = mentionedUser
        notification.task = comment.task
        
        dataService.insert(notification)
        try? dataService.save()
    }
    
    private func formatDueDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Push Notification Service (APNs)
@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService(dataService: DataService())
    
    private let dataService: DataService
    @Published var deviceToken: Data?
    @Published var isRegistered: Bool = false
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func registerForPushNotifications() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }
    
    func handleDeviceToken(_ token: Data) {
        self.deviceToken = token
        self.isRegistered = true
        
        // Save token for server-side notifications
        saveDeviceToken(token)
    }
    
    func handleRegistrationFailure(_ error: Error) {
        print("Failed to register for push notifications: \(error)")
        self.isRegistered = false
    }
    
    private func saveDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: "deviceToken")
    }
    
    func sendPushNotification(to userId: String, title: String, body: String, taskId: String? = nil) {
        // In production, this would call your backend API to send via APNs
        print("Would send push to \(userId): \(title) - \(body)")
    }
}
