//
//  TFBadge.swift
//  Projects
//
//  TaskFlow - Reusable Badge Component
//

import SwiftUI

// MARK: - Badge Size
enum TFBadgeSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 26
        case .large: return 32
        }
    }
    
    var font: Font {
        switch self {
        case .small: return .system(size: 10, weight: .medium)
        case .medium: return .system(size: 12, weight: .medium)
        case .large: return .system(size: 14, weight: .medium)
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 10
        case .large: return 14
        }
    }
}

// MARK: - Badge Style
enum TFBadgeStyle {
    case solid
    case outline
    case soft
    
    func backgroundColor(for color: Color) -> Color {
        switch self {
        case .solid: return color
        case .outline: return Color.clear
        case .soft: return color.opacity(0.1)
        }
    }
    
    func foregroundColor(for color: Color) -> Color {
        switch self {
        case .solid: return .white
        case .outline: return color
        case .soft: return color
        }
    }
    
    func borderColor(for color: Color) -> Color {
        switch self {
        case .outline: return color
        default: return Color.clear
        }
    }
}

// MARK: - TFBadge
struct TFBadge: View {
    let text: String
    let color: Color
    let style: TFBadgeStyle
    let size: TFBadgeSize
    let icon: String?
    let showDot: Bool
    
    init(
        text: String,
        color: Color = TaskFlowColors.primary,
        style: TFBadgeStyle = .soft,
        size: TFBadgeSize = .medium,
        icon: String? = nil,
        showDot: Bool = false
    ) {
        self.text = text
        self.color = color
        self.style = style
        self.size = size
        self.icon = icon
        self.showDot = showDot
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if showDot {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: size == .small ? 8 : 10))
            }
            
            Text(text)
                .font(size.font)
                .lineLimit(1)
        }
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .background(style.backgroundColor(for: color))
        .foregroundColor(style.foregroundColor(for: color))
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.full)
                .stroke(style.borderColor(for: color), lineWidth: 1)
        )
        .cornerRadius(TaskFlowRadius.full)
    }
}

// MARK: - Priority Badge
struct TFPriorityBadge: View {
    let priority: String
    let size: TFBadgeSize
    let style: TFBadgeStyle
    
    init(
        priority: String,
        size: TFBadgeSize = .medium,
        style: TFBadgeStyle = .soft
    ) {
        self.priority = priority
        self.size = size
        self.style = style
    }
    
    private var priorityData: (text: String, color: Color, icon: String) {
        switch priority.lowercased() {
        case "low":
            return ("Low", TaskFlowColors.priorityLow, "arrow.down")
        case "medium":
            return ("Medium", TaskFlowColors.priorityMedium, "arrow.left.and.right")
        case "high":
            return ("High", TaskFlowColors.priorityHigh, "arrow.up.right")
        case "urgent":
            return ("Urgent", TaskFlowColors.priorityUrgent, "exclamationmark.triangle.fill")
        default:
            return ("Medium", TaskFlowColors.priorityMedium, "arrow.left.and.right")
        }
    }
    
    var body: some View {
        TFBadge(
            text: priorityData.text,
            color: priorityData.color,
            style: style,
            size: size,
            icon: priorityData.icon
        )
    }
}

// MARK: - Status Badge
struct TFStatusBadge: View {
    let status: String
    let size: TFBadgeSize
    let style: TFBadgeStyle
    
    init(
        status: String,
        size: TFBadgeSize = .medium,
        style: TFBadgeStyle = .soft
    ) {
        self.status = status
        self.size = size
        self.style = style
    }
    
    private var statusData: (text: String, color: Color, icon: String) {
        switch status.lowercased() {
        case "todo":
            return ("To Do", TaskFlowColors.statusTodo, "circle")
        case "inprogress", "in_progress":
            return ("In Progress", TaskFlowColors.statusInProgress, "arrow.triangle.2.circlepath")
        case "review":
            return ("Review", TaskFlowColors.statusReview, "eye.fill")
        case "done":
            return ("Done", TaskFlowColors.statusDone, "checkmark.circle.fill")
        case "active":
            return ("Active", TaskFlowColors.success, "play.circle.fill")
        case "paused":
            return ("Paused", TaskFlowColors.warning, "pause.circle.fill")
        case "completed":
            return ("Completed", TaskFlowColors.primary, "checkmark.circle.fill")
        case "archived":
            return ("Archived", TaskFlowColors.textTertiary, "archivebox.fill")
        default:
            return (status.capitalized, TaskFlowColors.primary, "circle")
        }
    }
    
    var body: some View {
        TFBadge(
            text: statusData.text,
            color: statusData.color,
            style: style,
            size: size,
            icon: statusData.icon
        )
    }
}

// MARK: - Label Badge
struct TFLabelBadge: View {
    let name: String
    let colorHex: String
    let size: TFBadgeSize
    let icon: String?
    
    init(
        name: String,
        colorHex: String,
        size: TFBadgeSize = .small,
        icon: String? = nil
    ) {
        self.name = name
        self.colorHex = colorHex
        self.size = size
        self.icon = icon
    }
    
    var body: some View {
        TFBadge(
            text: name,
            color: Color(hex: colorHex),
            style: .soft,
            size: size,
            icon: icon
        )
    }
}

// MARK: - Previews
#Preview("Solid Badge") {
    TFBadge(text: "Badge", color: .blue, style: .solid)
        .padding()
}

#Preview("Outline Badge") {
    TFBadge(text: "Badge", color: .blue, style: .outline)
        .padding()
}

#Preview("Soft Badge") {
    TFBadge(text: "Badge", color: .blue, style: .soft)
        .padding()
}

#Preview("Priority Badges") {
    VStack(spacing: 8) {
        HStack(spacing: 8) {
            TFPriorityBadge(priority: "low")
            TFPriorityBadge(priority: "medium")
            TFPriorityBadge(priority: "high")
            TFPriorityBadge(priority: "urgent")
        }
    }
    .padding()
}

#Preview("Status Badges") {
    VStack(spacing: 8) {
        HStack(spacing: 8) {
            TFStatusBadge(status: "todo")
            TFStatusBadge(status: "inprogress")
            TFStatusBadge(status: "review")
            TFStatusBadge(status: "done")
        }
    }
    .padding()
}

#Preview("Badge with Dot") {
    TFBadge(text: "New", color: .green, showDot: true)
        .padding()
}

#Preview("Small Badge") {
    TFBadge(text: "Small", size: .small)
        .padding()
}

#Preview("Large Badge") {
    TFBadge(text: "Large", size: .large)
        .padding()
}
