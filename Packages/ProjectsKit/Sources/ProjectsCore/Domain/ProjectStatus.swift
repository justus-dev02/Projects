import Foundation

/// The lifecycle state of a project. Archiving is modelled separately so that an archived
/// project keeps the status it had.
public enum ProjectStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case active
    case onHold
    case completed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .active: String(localized: "Active", bundle: .module, comment: "Project status")
        case .onHold: String(localized: "On Hold", bundle: .module, comment: "Project status")
        case .completed: String(localized: "Completed", bundle: .module, comment: "Project status")
        }
    }

    public var symbolName: String {
        switch self {
        case .active: "play.circle"
        case .onHold: "pause.circle"
        case .completed: "checkmark.seal"
        }
    }
}
