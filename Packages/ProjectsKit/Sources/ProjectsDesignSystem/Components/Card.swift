import SwiftUI

/// A content container on the content layer. Liquid Glass is reserved for navigation and
/// controls (Apple HIG), so cards use an opaque surface.
public struct TFCardModifier: ViewModifier {
    let padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TFColor.surface, in: .rect(cornerRadius: TFRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: TFRadius.large)
                    .strokeBorder(TFColor.separator.opacity(0.4), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

extension View {
    public func tfCard(padding: CGFloat = TFSpacing.large) -> some View {
        modifier(TFCardModifier(padding: padding))
    }
}
