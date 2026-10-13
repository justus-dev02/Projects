import Foundation

/// URLs the app understands, e.g. from widgets, notifications, Spotlight or other apps.
///
/// Format: `projects://task/<uuid>`, `projects://project/<uuid>`, `projects://workspace/<uuid>`,
/// `projects://new-task`, `projects://today`.
public enum DeepLink: Hashable, Sendable {
    case task(UUID)
    case project(UUID)
    case workspace(UUID)
    case newTask
    case today

    public static let scheme = "projects"

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, let host = url.host()?.lowercased() else {
            return nil
        }
        let identifier = url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:))

        switch host {
        case "task":
            guard let identifier else { return nil }
            self = .task(identifier)
        case "project":
            guard let identifier else { return nil }
            self = .project(identifier)
        case "workspace":
            guard let identifier else { return nil }
            self = .workspace(identifier)
        case "new-task":
            self = .newTask
        case "today":
            self = .today
        default:
            return nil
        }
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .task(let id):
            components.host = "task"
            components.path = "/" + id.uuidString
        case .project(let id):
            components.host = "project"
            components.path = "/" + id.uuidString
        case .workspace(let id):
            components.host = "workspace"
            components.path = "/" + id.uuidString
        case .newTask:
            components.host = "new-task"
        case .today:
            components.host = "today"
        }
        // The components above are always valid, so this cannot fail.
        return components.url ?? URL(filePath: "/")
    }
}
