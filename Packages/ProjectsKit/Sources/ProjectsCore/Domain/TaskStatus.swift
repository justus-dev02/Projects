import Foundation

/// The workflow state of a task.
///
/// The raw value is persisted, so existing cases must never be renamed.
public enum TaskStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case todo
    case inProgress
    case review
    case done

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .todo: String(localized: "To Do", bundle: .module, comment: "Task status")
        case .inProgress: String(localized: "In Progress", bundle: .module, comment: "Task status")
        case .review: String(localized: "Review", bundle: .module, comment: "Task status")
        case .done: String(localized: "Done", bundle: .module, comment: "Task status")
        }
    }

    public var symbolName: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .review: "eye.circle"
        case .done: "checkmark.circle.fill"
        }
    }

    public var isCompleted: Bool { self == .done }
}
