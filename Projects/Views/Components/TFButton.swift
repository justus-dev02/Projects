//
//  TFButton.swift
//  Projects
//
//  TaskFlow - Reusable Button Component
//

import SwiftUI

// MARK: - Button Style
enum TFButtonStyle {
    case primary
    case secondary
    case ghost
    case outline
    case danger
    case success
}

// MARK: - Button Size
enum TFButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 40
        case .large: return 48
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 20
        case .large: return 28
        }
    }
    
    var font: Font {
        switch self {
        case .small: return .system(size: 12, weight: .medium)
        case .medium: return .system(size: 14, weight: .medium)
        case .large: return .system(size: 16, weight: .semibold)
        }
    }
}

// MARK: - TFButton
struct TFButton: View {
    let title: String
    let style: TFButtonStyle
    let size: TFButtonSize
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        style: TFButtonStyle = .primary,
        size: TFButtonSize = .medium,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled || isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            action()
        }) {
            HStack(spacing: TaskFlowSpacing.medium) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size == .small ? 12 : 14))
                }
                
                Text(title)
                    .font(size.font)
            }
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(TaskFlowRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
    
    // MARK: - Colors
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.primary
        case .secondary:
            return isDisabled ? TaskFlowColors.background : TaskFlowColors.background
        case .ghost:
            return Color.clear
        case .outline:
            return Color.clear
        case .danger:
            return isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.error
        case .success:
            return isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.success
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .danger, .success:
            return isDisabled ? TaskFlowColors.background : .white
        case .secondary:
            return isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.textPrimary
        case .ghost:
            return isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.primary
        case .outline:
            return isDisabled ? TaskFlowColors.textTertiary : TaskFlowColors.primary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .ghost:
            return Color.clear
        case .secondary:
            return isDisabled ? TaskFlowColors.border : TaskFlowColors.border
        case .outline:
            return isDisabled ? TaskFlowColors.border : TaskFlowColors.primary
        case .danger:
            return isDisabled ? TaskFlowColors.border : TaskFlowColors.error
        case .success:
            return isDisabled ? TaskFlowColors.border : TaskFlowColors.success
        }
    }
}

// MARK: - Icon Button
struct TFIconButton: View {
    let icon: String
    let size: CGFloat
    let style: TFButtonStyle
    let action: () -> Void
    
    init(
        icon: String,
        size: CGFloat = 20,
        style: TFButtonStyle = .ghost,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(foregroundColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor)
                .cornerRadius(TaskFlowRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return TaskFlowColors.primary
        case .secondary:
            return TaskFlowColors.background
        case .ghost, .outline, .danger, .success:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return TaskFlowColors.textPrimary
        case .ghost:
            return TaskFlowColors.textSecondary
        case .outline:
            return TaskFlowColors.primary
        case .danger:
            return TaskFlowColors.error
        case .success:
            return TaskFlowColors.success
        }
    }
}

// MARK: - Previews
#Preview("Primary Button") {
    TFButton(title: "Primary", style: .primary, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Secondary Button") {
    TFButton(title: "Secondary", style: .secondary, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Ghost Button") {
    TFButton(title: "Ghost", style: .ghost, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Outline Button") {
    TFButton(title: "Outline", style: .outline, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Danger Button") {
    TFButton(title: "Delete", style: .danger, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Button with Icon") {
    TFButton(title: "Create Task", style: .primary, icon: "plus", action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Loading Button") {
    TFButton(title: "Loading", style: .primary, isLoading: true, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Disabled Button") {
    TFButton(title: "Disabled", style: .primary, isDisabled: true, action: {
        print("Tapped")
    })
    .padding()
}

#Preview("Icon Button") {
    TFIconButton(icon: "plus", action: {
        print("Icon button tapped")
    })
    .padding()
}
