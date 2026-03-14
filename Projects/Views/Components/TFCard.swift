//
//  TFCard.swift
//  Projects
//
//  TaskFlow - Reusable Card Component
//

import SwiftUI

// MARK: - TFCard
struct TFCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let spacing: CGFloat
    let showShadow: Bool
    let borderColor: Color
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let action: (() -> Void)?
    
    init(
        padding: CGFloat = TaskFlowSpacing.xLarge,
        spacing: CGFloat = TaskFlowSpacing.medium,
        showShadow: Bool = true,
        borderColor: Color = TaskFlowColors.border,
        backgroundColor: Color = TaskFlowColors.surface,
        cornerRadius: CGFloat = TaskFlowRadius.large,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.spacing = spacing
        self.showShadow = showShadow
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(cornerRadius)
            .taskFlowShadow(showShadow ? TaskFlowShadow.medium : TaskFlowShadow.none)
    }
}

// MARK: - Stat Card
struct TFStatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let trend: Double?
    let trendUp: Bool?
    
    init(
        title: String,
        value: String,
        icon: String,
        iconColor: Color = TaskFlowColors.primary,
        trend: Double? = nil,
        trendUp: Bool? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
        self.trend = trend
        self.trendUp = trendUp
    }
    
    var body: some View {
        TFCard(padding: TaskFlowSpacing.large) {
            HStack(spacing: TaskFlowSpacing.large) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textSecondary)
                    
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    if let trend = trend, let trendUp = trendUp {
                        HStack(spacing: 2) {
                            Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                            
                            Text("\(String(format: "%.1f", abs(trend)))%")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(trendUp ? TaskFlowColors.success : TaskFlowColors.error)
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Info Card
struct TFInfoCard: View {
    let title: String
    let message: String
    let icon: String
    let type: InfoCardType
    
    enum InfoCardType {
        case info
        case warning
        case error
        case success
        
        var color: Color {
            switch self {
            case .info: return TaskFlowColors.primary
            case .warning: return TaskFlowColors.warning
            case .error: return TaskFlowColors.error
            case .success: return TaskFlowColors.success
            }
        }
        
        var backgroundColor: Color {
            color.opacity(0.1)
        }
    }
    
    init(
        title: String,
        message: String,
        icon: String,
        type: InfoCardType = .info
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.type = type
    }
    
    var body: some View {
        TFCard(
            padding: TaskFlowSpacing.large,
            borderColor: type.color.opacity(0.3),
            backgroundColor: type.backgroundColor
        ) {
            HStack(spacing: TaskFlowSpacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(type.color)
                
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(type.color)
                    
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(TaskFlowColors.textSecondary)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Empty State Card
struct TFEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        TFCard {
            VStack(spacing: TaskFlowSpacing.large) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(TaskFlowColors.textTertiary)
                
                VStack(spacing: TaskFlowSpacing.small) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    TFButton(title: actionTitle, style: .primary, action: action)
                }
            }
            .padding(.vertical, TaskFlowSpacing.xHuge)
        }
    }
}

// MARK: - Previews
#Preview("Stat Card") {
    TFStatCard(
        title: "Total Tasks",
        value: "128",
        icon: "checkmark.circle.fill",
        iconColor: TaskFlowColors.primary,
        trend: 12.5,
        trendUp: true
    )
    .padding()
}

#Preview("Info Card - Info") {
    TFInfoCard(
        title: "Information",
        message: "This is an informational message.",
        icon: "info.circle.fill",
        type: .info
    )
    .padding()
}

#Preview("Info Card - Warning") {
    TFInfoCard(
        title: "Warning",
        message: "This task is overdue!",
        icon: "exclamationmark.triangle.fill",
        type: .warning
    )
    .padding()
}

#Preview("Empty State") {
    TFEmptyStateCard(
        icon: "tray",
        title: "No Tasks Yet",
        message: "Create your first task to get started.",
        actionTitle: "Create Task",
        action: {}
    )
    .padding()
}

#Preview("Custom Card") {
    TFCard {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Custom Card")
                .font(.headline)
            Text("This is a custom card with any content.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    .padding()
}
