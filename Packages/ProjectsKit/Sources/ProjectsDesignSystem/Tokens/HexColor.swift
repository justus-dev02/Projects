import SwiftUI

/// An sRGB color parsed from `#RGB`, `#RRGGBB` or `#RRGGBBAA`.
nonisolated public struct HexColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public static let black = HexColor(red: 0, green: 0, blue: 0, alpha: 1)

    private init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Returns `nil` for malformed input instead of silently producing black.
    public init?(_ string: String) {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.allSatisfy(\.isHexDigit), let value = UInt64(hex, radix: 16) else { return nil }

        switch hex.count {
        case 3:
            red = Double((value >> 8) & 0xF) * 17 / 255
            green = Double((value >> 4) & 0xF) * 17 / 255
            blue = Double(value & 0xF) * 17 / 255
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            return nil
        }
    }

    /// Relative luminance as defined by WCAG 2.1.
    public var luminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Whether white or black text is more readable on top of this color.
    public var prefersLightForeground: Bool {
        // Contrast against white vs. black; pick the larger one.
        (1.05 / (luminance + 0.05)) > ((luminance + 0.05) / 0.05)
    }
}

extension Color {
    /// Creates a color from a hex string. Malformed values fall back to the accent color.
    public init(hex: String) {
        if let parsed = HexColor(hex) {
            self.init(.sRGB, red: parsed.red, green: parsed.green, blue: parsed.blue, opacity: parsed.alpha)
        } else {
            self = TFColor.accent
        }
    }

    /// A color that switches between two hex values for light and dark appearance.
    static func dynamic(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        Color(NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
import UIKit

extension UIColor {
    convenience init(hex: String) {
        let parsed = HexColor(hex) ?? .black
        self.init(red: parsed.red, green: parsed.green, blue: parsed.blue, alpha: parsed.alpha)
    }
}
#else
import AppKit

extension NSColor {
    convenience init(hex: String) {
        let parsed = HexColor(hex) ?? .black
        self.init(srgbRed: parsed.red, green: parsed.green, blue: parsed.blue, alpha: parsed.alpha)
    }
}
#endif
