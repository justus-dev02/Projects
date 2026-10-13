import SwiftUI

/// A number with a caption, used on the dashboard.
public struct TFStatTile: View {
    let title: LocalizedStringKey
    let value: Int
    let systemImage: String
    let tint: Color

    public init(_ title: LocalizedStringKey, value: Int, systemImage: String, tint: Color) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TFSpacing.small) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value, format: .number)
                .font(.title.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .tfCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value, format: .number))
    }
}

/// A rounded square with an SF Symbol on a colored background (workspace and project icons).
public struct IconTile: View {
    let systemImage: String
    let colorHex: String
    @ScaledMetric private var size: CGFloat

    public init(systemImage: String, colorHex: String, size: CGFloat = 36) {
        self.systemImage = systemImage
        self.colorHex = colorHex
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex).gradient, in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}
