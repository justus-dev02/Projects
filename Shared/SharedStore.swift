import AppIntents
import Foundation
import SwiftData
import ProjectsCore
import ProjectsData

/// Opens the store from processes other than the app (widget, intents run by the system).
///
/// Extensions never enable CloudKit mirroring: syncing is the app's job, and running the mirror
/// in a short-lived extension process risks conflicting exports.
@MainActor
enum SharedStore {
    private static var cached: ModelContainer?

    static func container() throws -> ModelContainer {
        if let cached { return cached }
        let url = PersistenceController.defaultStoreURL(appGroupIdentifier: SharedConfiguration.appGroupIdentifier)
        let container = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
        // The history records the author, so the app can tell the widget's changes from its own.
        container.mainContext.author = StoreAuthor.widget
        cached = container
        return container
    }
}

/// What App Intents need from the process they run in.
///
/// Each process registers one with `AppDependencyManager` at launch and intents receive it through
/// `@Dependency`, so no intent reaches for a global. The app registers a context backed by its own
/// container and change observer (reminders, Spotlight) and its router; the widget extension
/// registers one backed by the shared store.
@MainActor
final class IntentContext {
    let environment: ServiceEnvironment
    /// Opens a destination in the app. `nil` in extensions, which have no user interface to navigate.
    let open: ((DeepLink) -> Void)?

    init(environment: ServiceEnvironment, open: ((DeepLink) -> Void)? = nil) {
        self.environment = environment
        self.open = open
    }

    /// The context of extensions: the shared store without platform side effects.
    static func sharedStore() throws -> IntentContext {
        IntentContext(environment: ServiceEnvironment(
            context: try SharedStore.container().mainContext,
            installation: SharedConfiguration.installation
        ))
    }
}
