import SwiftUI
import ProjectsCore

/// Semantic colors. Wherever possible these are system colors, so dark mode, "Increase Contrast"
/// and future OS appearance changes work without extra code.
public enum TFColor {
    public static let accent = Color.dynamic(light: "#5B5BD6", dark: "#8B8BF5")

    /// The page behind content: plain white (black in dark mode) instead of the gray grouped
    /// background, which reads as dated next to the colored cards.
    #if canImport(UIKit)
    public static let background = Color(uiColor: .systemBackground)
    public static let separator = Color(uiColor: .separator)
    #else
    public static let background = Color(nsColor: .textBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
    #endif
    /// Cards. White on the white page, set apart by a hairline border and a soft shadow.
    public static let surface = Color.dynamic(light: "#FFFFFF", dark: "#1C1C1E")
    /// A faint tint of the accent color instead of gray, e.g. for board columns without a color.
    public static let rowBackground = Color.dynamic(light: "#F6F6FD", dark: "#1C1C1E")
    /// Secondary fills inside cards, e.g. unselected picker items.
    public static let surfaceSecondary = Color.dynamic(light: "#EFEFFA", dark: "#2C2C2E")

    public static let success = Color.green
    public static let warning = Color.orange
    public static let danger = Color.red
}

nonisolated public enum TFSpacing {
    public static let xxSmall: CGFloat = 2
    public static let xSmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xLarge: CGFloat = 24
    public static let xxLarge: CGFloat = 32
}

nonisolated public enum TFRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 20
}

extension TaskStatus {
    public var color: Color {
        switch self {
        case .todo: .gray
        case .inProgress: .blue
        case .review: .orange
        case .done: .green
        }
    }
}

extension TaskPriority {
    public var color: Color {
        switch self {
        case .low: .gray
        case .medium: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}

extension ProjectStatus {
    public var color: Color {
        switch self {
        case .active: .green
        case .onHold: .orange
        case .completed: .blue
        }
    }
}
