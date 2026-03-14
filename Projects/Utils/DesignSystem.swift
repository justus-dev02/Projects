//
//  DesignSystem.swift
//  Projects
//
//  TaskFlow - Design System & Theme
//

import SwiftUI

// MARK: - Color Palette
struct TaskFlowColors {
    // Primary Colors
    static let primary = Color(hex: "#2D5BFF")
    static let success = Color(hex: "#00BA88")
    static let warning = Color(hex: "#FFB020")
    static let error = Color(hex: "#FF4757")
    
    // Background Colors
    static let background = Color(hex: "#FAFBFC")
    static let backgroundDark = Color(hex: "#1A1A2E")
    static let surface = Color(hex: "#FFFFFF")
    static let surfaceDark = Color(hex: "#16213E")
    
    // Border Colors
    static let border = Color(hex: "#E6E9ED")
    static let borderDark = Color(hex: "#2D3748")
    
    // Text Colors
    static let textPrimary = Color(hex: "#1A202E")
    static let textSecondary = Color(hex: "#718096")
    static let textTertiary = Color(hex: "#A0AEC0")
    static let textPrimaryDark = Color(hex: "#F7FAFC")
    static let textSecondaryDark = Color(hex: "#A0AEC0")
    
    // Label Colors
    static let labelColors: [Color] = [
        Color(hex: "#FF6B6B"),
        Color(hex: "#4ECDC4"),
        Color(hex: "#45B7D1"),
        Color(hex: "#96CEB4"),
        Color(hex: "#FFEAA7"),
        Color(hex: "#DDA0DD"),
        Color(hex: "#98D8C8"),
        Color(hex: "#F7DC6F")
    ]
    
    // Priority Colors
    static let priorityLow = Color(hex: "#95A5A6")
    static let priorityMedium = Color(hex: "#45B7D1")
    static let priorityHigh = Color(hex: "#FFB020")
    static let priorityUrgent = Color(hex: "#FF4757")
    
    // Status Colors
    static let statusTodo = Color(hex: "#95A5A6")
    static let statusInProgress = Color(hex: "#45B7D1")
    static let statusReview = Color(hex: "#FFB020")
    static let statusDone = Color(hex: "#00BA88")
}

// MARK: - Typography
struct TaskFlowTypography {
    // Font Sizes
    static let tiny: CGFloat = 10
    static let small: CGFloat = 12
    static let body: CGFloat = 14
    static let mediumSize: CGFloat = 16
    static let large: CGFloat = 18
    static let xLarge: CGFloat = 20
    static let title: CGFloat = 24
    static let xTitle: CGFloat = 28
    static let display: CGFloat = 32

    // Font Weights
    static let regular: Font.Weight = .regular
    static let mediumWeight: Font.Weight = .medium
    static let semibold: Font.Weight = .semibold
    static let bold: Font.Weight = .bold
}

// MARK: - Spacing
struct TaskFlowSpacing {
    static let none: CGFloat = 0
    static let xs: CGFloat = 2
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let xLarge: CGFloat = 16
    static let xxLarge: CGFloat = 20
    static let huge: CGFloat = 24
    static let xHuge: CGFloat = 32
}

// MARK: - Corner Radius
struct TaskFlowRadius {
    static let none: CGFloat = 0
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let xLarge: CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - Shadow
struct TaskFlowShadow {
    static let none: Shadow = Shadow(color: .clear, radius: 0, x: 0, y: 0)
    static let small: Shadow = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    static let medium: Shadow = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    static let large: Shadow = Shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Animation
struct TaskFlowAnimation {
    static let fast: Double = 0.15
    static let medium: Double = 0.25
    static let slow: Double = 0.35
    static let springDuration: Double = 0.5

    static let easeInOut: Animation = .easeInOut(duration: medium)
    static let spring: Animation = .spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(iOS)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif os(macOS)
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a) ?? ()
        #endif
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - View Extension for Shadows
extension View {
    func taskFlowShadow(_ shadow: TaskFlowShadow.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
