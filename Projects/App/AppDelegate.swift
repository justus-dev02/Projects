import Foundation
import UserNotifications

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // CloudKit delivers change notifications silently; no user permission required.
        // Needs the Push Notifications entitlement, so only when sync is built in.
        if SharedConfiguration.isCloudSyncAvailable && !LaunchOptions.usesInMemoryStore {
            application.registerForRemoteNotifications()
        }
        return true
    }
}
#else
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if SharedConfiguration.isCloudSyncAvailable && !LaunchOptions.usesInMemoryStore {
            NSApplication.shared.registerForRemoteNotifications()
        }
    }
}
#endif

/// Routes taps on reminder notifications and their action buttons into the app.
///
/// Created by `ProjectsApp` with the app's dependencies and installed as the notification center's
/// delegate before launch finishes, so taps that launch the app are not lost.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    private weak var dependencies: AppDependencies?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let rawID = response.notification.request.content.userInfo[ReminderScheduler.taskIDKey] as? String
        guard let rawID, let taskID = UUID(uuidString: rawID) else { return }
        await MainActor.run {
            dependencies?.handleNotificationAction(action, taskID: taskID)
        }
    }
}
