import CoreData
import Foundation
import Observation
import OSLog

/// Observes the CloudKit mirroring that SwiftData runs under the hood and exposes a simple
/// status for the settings screen.
@Observable
final class SyncMonitor {
    enum State: Equatable {
        /// The user turned sync off.
        case disabled
        /// Sync is on, but the container could not be opened with CloudKit
        /// (no iCloud entitlement, no account, …).
        case unavailable
        case idle(lastSync: Date?)
        case syncing
        case failed(message: String)
    }

    private(set) var state: State
    private var observer: (any NSObjectProtocol)?
    private let logger = Logger(subsystem: SharedConfiguration.logSubsystem, category: "sync")

    init(initialState: State) {
        state = initialState
        guard case .idle = initialState else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let finished = event.endDate
            let succeeded = event.succeeded
            let message = event.error?.localizedDescription
            MainActor.assumeIsolated {
                self?.handle(finished: finished, succeeded: succeeded, errorMessage: message)
            }
        }
    }

    private func handle(finished: Date?, succeeded: Bool, errorMessage: String?) {
        guard let finished else {
            state = .syncing
            return
        }
        if succeeded {
            state = .idle(lastSync: finished)
        } else {
            let message = errorMessage ?? String(localized: "Unknown error")
            logger.error("CloudKit event failed: \(message, privacy: .public)")
            state = .failed(message: message)
        }
    }
}
