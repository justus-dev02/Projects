import Foundation

/// Groups task templates in the template gallery.
public enum TemplateCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case general
    case bug
    case feature
    case meeting
    case research
    case design
    case documentation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: String(localized: "General", bundle: .module, comment: "Template category")
        case .bug: String(localized: "Bug", bundle: .module, comment: "Template category")
        case .feature: String(localized: "Feature", bundle: .module, comment: "Template category")
        case .meeting: String(localized: "Meeting", bundle: .module, comment: "Template category")
        case .research: String(localized: "Research", bundle: .module, comment: "Template category")
        case .design: String(localized: "Design", bundle: .module, comment: "Template category")
        case .documentation: String(localized: "Documentation", bundle: .module, comment: "Template category")
        }
    }

    public var symbolName: String {
        switch self {
        case .general: "square.grid.2x2"
        case .bug: "ladybug"
        case .feature: "sparkles"
        case .meeting: "person.2"
        case .research: "magnifyingglass"
        case .design: "paintbrush"
        case .documentation: "doc.text"
        }
    }
}
