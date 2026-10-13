import CoreSpotlight
import Foundation
import Observation
import OSLog
import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import UserNotifications

/// The composition root. Builds the store and every service exactly once and hands them to the
/// view hierarchy through the environment. Views never create services themselves.
@Observable
final class AppDependencies {
    /// Why the regular store could not be used. The UI shows a recovery screen in that case.
    enum StoreIssue: Equatable {
        case couldNotOpen(storeURL: URL)
    }

    let container: ModelContainer
    let storeURL: URL?
    let storeIssue: StoreIssue?
    let environment: ServiceEnvironment

    let workspaces: WorkspaceService
    let projects: ProjectService
    let tasks: TaskService
    let templates: TemplateService
    let dashboard: DashboardService
    #if DEBUG
    /// Fills in-memory stores for tests and UI tests. Not part of release builds: the app starts empty.
    let seeder: DemoDataSeeder
    #endif
    let consistency: ConsistencyService
    /// Heavy work (backups, imports, attachments) runs here, off the main thread.
    let background: BackgroundStore

    let reminders: ReminderScheduler
    let spotlight: SpotlightIndexer
    let widgets: WidgetRefresher
    let sync: SyncMonitor
    let diagnostics: DiagnosticsStore
    private let platformObserver: PlatformTaskObserver
    private let changeReader: ExternalChangeReader
    private var storeChangeObservation: StoreChangeSignal.Observation?

    let router = AppRouter()
    let errors = ErrorCenter()
    let toasts = ToastCenter()

    /// Incremented after every data change. Views that show derived values (statistics) use it
    /// as a `task(id:)` trigger.
    private(set) var dataVersion = 0

    private static let logger = Logger(subsystem: SharedConfiguration.logSubsystem, category: "app")

    // MARK: Construction

    private init(
        container: ModelContainer,
        storeURL: URL?,
        storeIssue: StoreIssue?,
        syncState: SyncMonitor.State,
        notificationCenter: NotificationCenterClient,
        searchIndex: SearchIndexClient,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.container = container
        self.storeURL = storeURL
        self.storeIssue = storeIssue

        let reminders = ReminderScheduler(center: notificationCenter, now: now)
        let spotlight = SpotlightIndexer(index: searchIndex)
        let widgets = WidgetRefresher()
        self.reminders = reminders
        self.spotlight = spotlight
        self.widgets = widgets
        sync = SyncMonitor(initialState: syncState)
        diagnostics = DiagnosticsStore()

        // The observer needs `self` to bump `dataVersion`; it is wired after all stored
        // properties are initialised through a small indirection.
        let bump = VersionBump()
        let observer = PlatformTaskObserver(reminders: reminders, spotlight: spotlight, widgets: widgets) {
            bump.action?()
        }
        platformObserver = observer
        // The history records the author, so changes from the widget can be told apart.
        container.mainContext.author = StoreAuthor.app
        changeReader = ExternalChangeReader(context: container.mainContext, tokenStore: HistoryTokenStore(defaults: .standard))
        let environment = ServiceEnvironment(
            context: container.mainContext,
            now: now,
            observer: observer,
            installation: SharedConfiguration.installation
        )
        self.environment = environment

        workspaces = WorkspaceService(environment: environment)
        projects = ProjectService(environment: environment)
        tasks = TaskService(environment: environment)
        templates = TemplateService(environment: environment, taskService: tasks)
        dashboard = DashboardService(environment: environment)
        #if DEBUG
        seeder = DemoDataSeeder(environment: environment)
        #endif
        consistency = ConsistencyService(environment: environment)
        background = BackgroundStore(container: container, installation: environment.installation)

        bump.action = { [weak self] in self?.dataVersion += 1 }
    }

    private final class VersionBump {
        var action: (() -> Void)?
    }

    /// Builds the dependencies of the running app. Called once by `ProjectsApp`.
    static func makeForLaunch() -> AppDependencies {
        if LaunchOptions.usesInMemoryStore {
            return makeInMemory(seed: LaunchOptions.seedDemoData)
        }

        let defaults = SharedConfiguration.sharedDefaults
        defaults.register(defaults: [SharedConfiguration.DefaultsKey.iCloudSyncEnabled: true])
        let wantsSync = SharedConfiguration.isCloudSyncAvailable
            && defaults.bool(forKey: SharedConfiguration.DefaultsKey.iCloudSyncEnabled)
        let storeURL = PersistenceController.defaultStoreURL(appGroupIdentifier: SharedConfiguration.appGroupIdentifier)

        var syncState = SyncMonitor.State.disabled
        var container: ModelContainer?
        if wantsSync, let cloudContainer = SharedConfiguration.iCloudContainerIdentifier {
            do {
                container = try PersistenceController.makeContainer(PersistenceConfiguration(
                    storage: .file(storeURL),
                    sync: .iCloud(containerIdentifier: cloudContainer)
                ))
                syncState = .idle(lastSync: nil)
            } catch {
                logger.error("Opening the store with iCloud failed, falling back to local storage")
                syncState = .unavailable
            }
        }
        if container == nil {
            container = try? PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(storeURL)))
        }

        guard let container else {
            // Keep the app usable enough to show the recovery screen.
            logger.fault("The local store could not be opened")
            let fallback = (try? PersistenceController.makeContainer(.inMemory))
                ?? { fatalError("Even an in-memory store could not be created") }()
            return AppDependencies(
                container: fallback,
                storeURL: storeURL,
                storeIssue: .couldNotOpen(storeURL: storeURL),
                syncState: .disabled,
                notificationCenter: SystemNotificationCenter(),
                searchIndex: CSSearchableIndex.default()
            )
        }

        return AppDependencies(
            container: container,
            storeURL: storeURL,
            storeIssue: nil,
            syncState: syncState,
            notificationCenter: SystemNotificationCenter(),
            searchIndex: CSSearchableIndex.default()
        )
    }

    /// An isolated in-memory stack for UI tests, unit tests and previews.
    static func makeInMemory(
        seed: Bool,
        notificationCenter: NotificationCenterClient = InertNotificationCenter(),
        searchIndex: SearchIndexClient = InertSearchIndex()
    ) -> AppDependencies {
        guard let container = try? PersistenceController.makeContainer(.inMemory) else {
            fatalError("An in-memory store could not be created")
        }
        let dependencies = AppDependencies(
            container: container,
            storeURL: nil,
            storeIssue: nil,
            syncState: .disabled,
            notificationCenter: notificationCenter,
            searchIndex: searchIndex
        )
        #if DEBUG
        if seed {
            do {
                try dependencies.seeder.seed()
            } catch {
                logger.error("Seeding sample data failed")
            }
        }
        #endif
        return dependencies
    }

    // MARK: Lifecycle

    /// Brings platform state in line with the database. Called on launch and whenever the app
    /// becomes active (another device or the widget may have changed data in the meantime).
    func refreshPlatformState() async {
        guard storeIssue == nil else { return }
        mergeExternalChanges()
        await reminders.refreshAuthorizationStatus()
        await reminders.reconcile(context: container.mainContext)
        widgets.setNeedsReload()
        dataVersion += 1
    }

    func onLaunch() async {
        reminders.registerCategories()
        diagnostics.start()
        repairConsistency()
        storeChangeObservation = StoreChangeSignal.observe { [weak self] in
            Task { @MainActor in self?.mergeExternalChanges() }
        }
        await refreshPlatformState()
        guard !LaunchOptions.usesInMemoryStore else { return }
        await spotlight.reindexAll(context: container.mainContext)
    }

    /// Loads changes that the widget extension (or a background context) wrote to the store,
    /// repairs the board if they left it inconsistent and updates reminders, Spotlight and widgets.
    func mergeExternalChanges() {
        guard storeIssue == nil else { return }
        do {
            let changes = try changeReader.mergeChanges()
            guard !changes.isEmpty else { return }
            Self.logger.info("Merged \(changes.transactionCount) external transactions")
            repairConsistency()
            let identifiers = changes.taskIDs
            let changed = try container.mainContext.fetch(FetchDescriptor<TaskItem>(
                predicate: #Predicate { identifiers.contains($0.id) }
            ))
            platformObserver.tasksDidChange(changed)
        } catch {
            Self.logger.error("Merging external changes failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Background work

    func exportBackup() async -> Data? {
        let background = background
        return await errors.attempt { try await background.exportJSON() }
    }

    func exportCSV() async -> Data? {
        let background = background
        return await errors.attempt { try await background.exportCSV() }
    }

    func importBackup(from url: URL, mode: BackupService.ImportMode) async -> BackupService.ImportSummary? {
        let background = background
        guard let (summary, result) = await errors.attempt({ try await background.importJSON(from: url, mode: mode) }) else {
            return nil
        }
        apply(result)
        return summary
    }

    func addAttachment(toTaskWithID taskID: UUID, from url: URL) async {
        let background = background
        guard let result = await errors.attempt({ try await background.addAttachment(toTaskWithID: taskID, from: url) }) else {
            return
        }
        apply(result)
    }

    /// Brings the saves of the background store into the UI and updates the platform integrations.
    private func apply(_ result: BackgroundStore.Result) {
        mergeExternalChanges()
        if !result.deletedTaskIDs.isEmpty {
            platformObserver.tasksWereDeleted(result.deletedTaskIDs)
        }
        dataVersion += 1
    }

    /// Restores board invariants that iCloud merges or other processes may have broken.
    private func repairConsistency() {
        do {
            try consistency.repair()
        } catch {
            Self.logger.error("Repairing the board failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Actions shared by several screens

    /// Deletes tasks, offers "Undo" in a toast and registers the undo with the window's undo
    /// manager (Edit ▸ Undo on macOS and iPad, shake to undo on iPhone).
    func delete(_ tasks: [TaskItem], undoManager: UndoManager?) {
        guard !tasks.isEmpty else { return }
        guard let deleted = errors.attempt({ try self.tasks.deleteUndoably(tasks) }) else { return }

        if let undoManager {
            // Window undo managers group by run loop event; others need an explicit group.
            let needsExplicitGroup = !undoManager.groupsByEvent
            if needsExplicitGroup { undoManager.beginUndoGrouping() }
            undoManager.registerUndo(withTarget: self) { dependencies in
                MainActor.assumeIsolated {
                    dependencies.restore(deleted)
                }
            }
            undoManager.setActionName(String(localized: "Delete \(deleted.count) Tasks", comment: "Undo action name"))
            if needsExplicitGroup { undoManager.endUndoGrouping() }
        }

        toasts.show(
            String(localized: "\(deleted.count) tasks deleted", comment: "Toast after deleting tasks"),
            actionTitle: String(localized: "Undo")
        ) { [weak self, weak undoManager] in
            if let undoManager, undoManager.canUndo {
                undoManager.undo()
            } else {
                self?.restore(deleted)
            }
        }
    }

    private func restore(_ deleted: DeletedTasks) {
        errors.perform {
            _ = try tasks.restore(deleted)
        }
    }

    /// Handles the buttons of a reminder notification.
    func handleNotificationAction(_ actionIdentifier: String, taskID: UUID) {
        switch actionIdentifier {
        case ReminderScheduler.completeActionIdentifier:
            errors.perform {
                guard let task = try tasks.task(id: taskID), !task.isCompleted else { return }
                try tasks.setStatus(task, to: .done)
            }
        case ReminderScheduler.snoozeActionIdentifier:
            errors.perform {
                guard let task = try tasks.task(id: taskID) else { return }
                try tasks.snoozeReminder(of: task, by: 3600)
            }
        default:
            router.handle(.task(taskID))
        }
    }
}

/// A notification center that does nothing. Used where no real notifications may appear.
final class InertNotificationCenter: NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func add(_ request: UNNotificationRequest) async throws {}
    func removePendingRequests(withIdentifiers identifiers: [String]) {}
    func pendingRequestIdentifiers() async -> [String] { [] }
    func setCategories(_ categories: Set<UNNotificationCategory>) {}
}

/// A search index that does nothing.
final class InertSearchIndex: SearchIndexClient {
    func indexSearchableItems(_ items: [CSSearchableItem]) async throws {}
    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {}
    func deleteAllSearchableItems() async throws {}
}
