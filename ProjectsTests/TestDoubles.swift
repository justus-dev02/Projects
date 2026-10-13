import CoreSpotlight
import Foundation
import UserNotifications
@testable import Projects

/// Records what the app asks the notification center to do.
final class FakeNotificationCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus = .authorized
    var grantsAuthorization = true
    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var categories: Set<UNNotificationCategory> = []
    private(set) var authorizationRequests = 0

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        status = grantsAuthorization ? .authorized : .denied
        return grantsAuthorization
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending[request.identifier] = request
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers {
            pending[identifier] = nil
        }
    }

    func pendingRequestIdentifiers() async -> [String] { Array(pending.keys) }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }
}

/// Records indexing calls.
final class FakeSearchIndex: SearchIndexClient {
    private(set) var indexed: [String: CSSearchableItem] = [:]
    private(set) var deleteAllCount = 0

    func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        for item in items {
            indexed[item.uniqueIdentifier] = item
        }
    }

    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        for identifier in identifiers {
            indexed[identifier] = nil
        }
    }

    func deleteAllSearchableItems() async throws {
        deleteAllCount += 1
        indexed.removeAll()
    }
}

/// Waits until a condition becomes true. Platform work is dispatched to unstructured tasks,
/// so tests poll instead of sleeping for a fixed time.
func eventually(timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
