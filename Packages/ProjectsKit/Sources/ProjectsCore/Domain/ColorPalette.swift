import Foundation

/// The colors users can pick for workspaces, projects, columns and labels.
///
/// Persisted as hex strings, so the palette can change without migrating data. Every entry has a
/// localized name for VoiceOver ("Indigo" instead of "#5B5BD6").
public struct PaletteColor: Hashable, Sendable, Identifiable {
    public let hex: String
    public let name: String

    public var id: String { hex }
}

public enum ColorPalette {
    public static let indigo = "#5B5BD6"
    public static let blue = "#0A84FF"
    public static let teal = "#30B0C7"
    public static let green = "#34C759"
    public static let yellow = "#FFB800"
    public static let orange = "#FF9500"
    public static let red = "#FF3B30"
    public static let pink = "#FF2D55"
    public static let purple = "#AF52DE"
    public static let gray = "#8E8E93"

    public static var all: [PaletteColor] {
        [
            PaletteColor(hex: indigo, name: String(localized: "Indigo", bundle: .module, comment: "Color name")),
            PaletteColor(hex: blue, name: String(localized: "Blue", bundle: .module, comment: "Color name")),
            PaletteColor(hex: teal, name: String(localized: "Teal", bundle: .module, comment: "Color name")),
            PaletteColor(hex: green, name: String(localized: "Green", bundle: .module, comment: "Color name")),
            PaletteColor(hex: yellow, name: String(localized: "Yellow", bundle: .module, comment: "Color name")),
            PaletteColor(hex: orange, name: String(localized: "Orange", bundle: .module, comment: "Color name")),
            PaletteColor(hex: red, name: String(localized: "Red", bundle: .module, comment: "Color name")),
            PaletteColor(hex: pink, name: String(localized: "Pink", bundle: .module, comment: "Color name")),
            PaletteColor(hex: purple, name: String(localized: "Purple", bundle: .module, comment: "Color name")),
            PaletteColor(hex: gray, name: String(localized: "Gray", bundle: .module, comment: "Color name")),
        ]
    }

    /// The localized name of a palette color, or the hex string for custom colors.
    public static func name(for hex: String) -> String {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? hex
    }

    /// SF Symbols offered for workspaces and projects.
    public static let symbols = [
        "briefcase", "folder", "house", "person", "star", "bolt", "heart", "flag",
        "book", "cart", "airplane", "graduationcap", "hammer", "paintbrush", "laptopcomputer", "leaf",
    ]
}
