import Foundation

/// How urgent a task is.
///
/// Backed by an `Int` so that SwiftData can sort and filter by priority directly in the store.
/// The raw value is persisted, so existing cases must keep their numbers.
public enum TaskPriority: Int, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low: String(localized: "Low", bundle: .module, comment: "Task priority")
        case .medium: String(localized: "Medium", bundle: .module, comment: "Task priority")
        case .high: String(localized: "High", bundle: .module, comment: "Task priority")
        case .urgent: String(localized: "Urgent", bundle: .module, comment: "Task priority")
        }
    }

    public var symbolName: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "equal"
        case .high: "arrow.up"
        case .urgent: "exclamationmark.2"
        }
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
