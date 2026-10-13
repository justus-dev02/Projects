import SwiftUI
import ProjectsCore

/// A small capsule with an optional SF Symbol.
public struct TFBadge: View {
    let text: String
    let systemImage: String?
    let tint: Color

    public init(_ text: String, systemImage: String? = nil, tint: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: TFSpacing.xSmall) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, TFSpacing.small)
        .padding(.vertical, TFSpacing.xxSmall + 1)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

public struct StatusBadge: View {
    let status: TaskStatus

    public init(_ status: TaskStatus) {
        self.status = status
    }

    public var body: some View {
        TFBadge(status.title, systemImage: status.symbolName, tint: status.color)
            .accessibilityLabel(Text("Status: \(status.title)", bundle: .module))
    }
}

public struct PriorityBadge: View {
    let priority: TaskPriority

    public init(_ priority: TaskPriority) {
        self.priority = priority
    }

    public var body: some View {
        TFBadge(priority.title, systemImage: priority.symbolName, tint: priority.color)
            .accessibilityLabel(Text("Priority: \(priority.title)", bundle: .module))
    }
}

/// A colored label chip. Text color is chosen for contrast against the label color.
///
/// Unselected chips (in pickers) use an outlined style instead of lowering the opacity, so the
/// text keeps a readable contrast.
public struct LabelChip: View {
    let name: String
    let colorHex: String
    let isSelected: Bool

    public init(name: String, colorHex: String, isSelected: Bool = true) {
        self.name = name
        self.colorHex = colorHex
        self.isSelected = isSelected
    }

    public var body: some View {
        let color = Color(hex: colorHex)
        Text(name)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, TFSpacing.small)
            .padding(.vertical, TFSpacing.xxSmall)
            .foregroundStyle(isSelected ? AnyShapeStyle(foreground) : AnyShapeStyle(.secondary))
            .background(isSelected ? color : .clear, in: .capsule)
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(color, lineWidth: 1)
                }
            }
            .accessibilityLabel(Text("Label: \(name)", bundle: .module))
    }

    private var foreground: Color {
        (HexColor(colorHex)?.prefersLightForeground ?? true) ? .white : .black
    }
}
