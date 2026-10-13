import Foundation
import Observation
import OSLog
import ProjectsCore

/// A user facing error message.
struct PresentedError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Collects errors from anywhere in the UI and shows them in one alert at the root.
@Observable
final class ErrorCenter {
    var current: PresentedError?

    private let logger = Logger(subsystem: SharedConfiguration.logSubsystem, category: "ui")

    func present(_ error: any Error) {
        let message: String
        if let error = error as? ProjectsError {
            message = [error.errorDescription, error.recoverySuggestion].compactMap(\.self).joined(separator: "\n\n")
        } else {
            logger.error("Unexpected error: \(String(describing: error), privacy: .public)")
            message = String(localized: "Something went wrong. Please try again.")
        }
        current = PresentedError(title: String(localized: "Action failed"), message: message)
    }

    /// Runs an action and presents any thrown error.
    /// - Returns: `true` when the action succeeded.
    @discardableResult
    func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            return true
        } catch {
            present(error)
            return false
        }
    }

    /// Runs an action that produces a value and presents any thrown error.
    func attempt<Value>(_ action: () throws -> Value) -> Value? {
        do {
            return try action()
        } catch {
            present(error)
            return nil
        }
    }

    /// The asynchronous variant of ``attempt(_:)``, for work that runs off the main thread.
    func attempt<Value>(_ action: () async throws -> Value) async -> Value? {
        do {
            return try await action()
        } catch {
            present(error)
            return nil
        }
    }
}
