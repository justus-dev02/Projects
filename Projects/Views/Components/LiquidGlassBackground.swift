import SwiftUI

public struct LiquidGlassBackground: View {
    public enum Style {
        case thin
        case regular
        case thick
    }
    
    private let style: Style
    private let cornerRadius: CGFloat
    private let tint: Color
    private let strokeOpacity: Double
    
    public init(style: Style = .regular, cornerRadius: CGFloat = 12, tint: Color = .clear, strokeOpacity: Double = 0.25) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.strokeOpacity = strokeOpacity
    }
    
    public var body: some View {
        let material: Material = {
            switch style {
            case .thin: return .thin
            case .regular: return .regular
            case .thick: return .thick
            }
        }()
        
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(strokeOpacity), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .overlay(tint.opacity(tint == .clear ? 0 : 0.15))
            )
            .compositingGroup()
    }
}

public struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassBackground.Style
    let cornerRadius: CGFloat
    let tint: Color
    let strokeOpacity: Double
    
    public func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassBackground(style: style, cornerRadius: cornerRadius, tint: tint, strokeOpacity: strokeOpacity)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public extension View {
    func liquidGlass(style: LiquidGlassBackground.Style = .regular, cornerRadius: CGFloat = 12, tint: Color = .clear, strokeOpacity: Double = 0.25) -> some View {
        modifier(LiquidGlassModifier(style: style, cornerRadius: cornerRadius, tint: tint, strokeOpacity: strokeOpacity))
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Thin")
            .padding()
            .liquidGlass(style: .thin, cornerRadius: 16)
        Text("Regular")
            .padding()
            .liquidGlass(style: .regular, cornerRadius: 16)
        Text("Thick")
            .padding()
            .liquidGlass(style: .thick, cornerRadius: 16)
    }
    .padding()
    .background(Image(systemName: "circle.grid.3x3.fill").font(.system(size: 200)).opacity(0.1))
}
