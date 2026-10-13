import Foundation

/// The type of an entry in a task's activity history.
///
/// Activity entries store the kind plus a raw `detail` instead of a finished sentence, so the
/// history is rendered in whatever language the user currently runs the app in.
public enum ActivityKind: String, Codable, CaseIterable, Sendable {
    case created
    case statusChanged
    case priorityChanged
    case moved
    case dueDateChanged
    case completed
    case reopened
    case commentAdded
    case subtaskAdded
    case attachmentAdded
    case recurrenceSpawned

    public var symbolName: String {
        switch self {
        case .created: "plus.circle"
        case .statusChanged: "arrow.triangle.2.circlepath"
        case .priorityChanged: "flag"
        case .moved: "arrow.right.square"
        case .dueDateChanged: "calendar"
        case .completed: "checkmark.circle"
        case .reopened: "arrow.uturn.backward.circle"
        case .commentAdded: "text.bubble"
        case .subtaskAdded: "checklist"
        case .attachmentAdded: "paperclip"
        case .recurrenceSpawned: "repeat"
        }
    }

    /// A human readable description in the current language.
    ///
    /// - Parameter detail: The raw value stored with the entry. For status and priority changes
    ///   this is the enum raw value, for moves the column name, for due date changes an ISO 8601
    ///   date (or `nil` when the date was removed).
    public func message(detail: String?) -> String {
        switch self {
        case .created:
            return String(localized: "Task created", bundle: .module, comment: "Activity")
        case .statusChanged:
            let status = detail.flatMap(TaskStatus.init(rawValue:))?.title ?? "–"
            return String(localized: "Status changed to \(status)", bundle: .module, comment: "Activity")
        case .priorityChanged:
            let priority = detail.flatMap { Int($0) }.flatMap { TaskPriority(rawValue: $0) }?.title ?? "–"
            return String(localized: "Priority changed to \(priority)", bundle: .module, comment: "Activity")
        case .moved:
            let column = detail ?? "–"
            return String(localized: "Moved to \(column)", bundle: .module, comment: "Activity")
        case .dueDateChanged:
            if let date = detail.flatMap(CustomFieldCodec.decodeDate) {
                let formatted = date.formatted(date: .abbreviated, time: .omitted)
                return String(localized: "Due date set to \(formatted)", bundle: .module, comment: "Activity")
            }
            return String(localized: "Due date removed", bundle: .module, comment: "Activity")
        case .completed:
            return String(localized: "Task completed", bundle: .module, comment: "Activity")
        case .reopened:
            return String(localized: "Task reopened", bundle: .module, comment: "Activity")
        case .commentAdded:
            return String(localized: "Comment added", bundle: .module, comment: "Activity")
        case .subtaskAdded:
            return String(localized: "Subtask added", bundle: .module, comment: "Activity")
        case .attachmentAdded:
            let name = detail ?? "–"
            return String(localized: "Attachment \(name) added", bundle: .module, comment: "Activity")
        case .recurrenceSpawned:
            return String(localized: "Next occurrence created", bundle: .module, comment: "Activity")
        }
    }
}
