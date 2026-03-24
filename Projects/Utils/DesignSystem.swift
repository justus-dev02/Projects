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
    static let primary = Color(hex: "#6366F1") // Modern Indigo/Violet
    static let primaryLight = Color(hex: "#EEF2FF")
    static let success = Color(hex: "#10B981")
    static let warning = Color(hex: "#F59E0B")
    static let error = Color(hex: "#EF4444")
    
    // Background Colors
    static let background = Color(hex: "#F8FAFC")
    static let backgroundDark = Color(hex: "#0F172A")
    static let surface = Color(hex: "#FFFFFF")
    static let surfaceDark = Color(hex: "#1E293B")
    
    // Border Colors
    static let border = Color(hex: "#E2E8F0")
    static let borderDark = Color(hex: "#334155")
    
    // Text Colors
    static let textPrimary = Color(hex: "#1E293B")
    static let textSecondary = Color(hex: "#64748B")
    static let textTertiary = Color(hex: "#94A3B8")
    static let textPrimaryDark = Color(hex: "#F7FAFC")
    static let textSecondaryDark = Color(hex: "#94A3B8")
    
    // Label/Tag Colors (Pastel)
    static let labelColors: [Color] = [
        Color(hex: "#FFEDD5"), // Orange
        Color(hex: "#DBEAFE"), // Blue
        Color(hex: "#D1FAE5"), // Green
        Color(hex: "#FCE7F3"), // Pink
        Color(hex: "#F3E8FF"), // Purple
        Color(hex: "#FEF9C3"), // Yellow
        Color(hex: "#E0F2FE"), // Light Blue
        Color(hex: "#FFCFD2")  // Red Pastel
    ]
    
    // Priority Colors
    static let priorityLow = Color(hex: "#94A3B8")
    static let priorityMedium = Color(hex: "#6366F1")
    static let priorityHigh = Color(hex: "#F59E0B")
    static let priorityUrgent = Color(hex: "#EF4444")
    
    // Status Colors
    static let statusTodo = Color(hex: "#94A3B8")
    static let statusInProgress = Color(hex: "#6366F1")
    static let statusReview = Color(hex: "#F59E0B")
    static let statusDone = Color(hex: "#10B981")
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
    static let xs: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
    static let huge: CGFloat = 40
    static let xHuge: CGFloat = 48
}

// MARK: - Corner Radius
struct TaskFlowRadius {
    static let none: CGFloat = 0
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 28
    static let huge: CGFloat = 36
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
