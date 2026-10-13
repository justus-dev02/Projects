import AppIntents
import SwiftData
import SwiftUI
import UserNotifications

/// The composition root of the process: creates the dependencies once and hands them to the views
/// (environment), App Intents (`AppDependencyManager`) and notification handling (delegate).
@main
struct ProjectsApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    private let dependencies: AppDependencies
    /// Kept alive here because the notification center holds its delegate weakly.
    private let notificationResponder: NotificationResponder

    init() {
        let dependencies = AppDependencies.makeForLaunch()
        self.dependencies = dependencies
        notificationResponder = NotificationResponder(dependencies: dependencies)
        // Set before launch finishes, so a tap on a notification that launches the app is delivered.
        UNUserNotificationCenter.current().delegate = notificationResponder

        let router = dependencies.router
        let context = IntentContext(environment: dependencies.environment) { link in
            router.handle(link)
        }
        AppDependencyManager.shared.add(dependency: context)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .modelContainer(dependencies.container)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        .commands {
            AppCommands(router: dependencies.router)
        }

        #if os(macOS)
        Settings {
            NavigationStack {
                SettingsView()
            }
            .frame(width: 520, height: 640)
            .environment(dependencies)
            .modelContainer(dependencies.container)
        }
        #endif
    }
}
