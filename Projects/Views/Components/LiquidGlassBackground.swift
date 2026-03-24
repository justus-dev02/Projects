import SwiftUI

public struct LiquidGlassBackground: View {
    public enum Style {
        case thin
        case regular
        case thick
        case ultra
    }
    
    private let style: Style
    private let cornerRadius: CGFloat
    private let tint: Color
    private let strokeOpacity: Double
    
    public init(style: Style = .regular, cornerRadius: CGFloat = 20, tint: Color = .clear, strokeOpacity: Double = 0.3) {
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
            case .ultra: return .ultraThinMaterial
            }
        }()
        
        ZStack {
            // Main Glass Layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material)
                .overlay(tint.opacity(tint == .clear ? 0 : 0.12))
            
            // Subtle Internal Glow (Top Left)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(strokeOpacity), .white.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .blendMode(.screen)
            
            // Subtle Shadow/Depth (Bottom Right)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.05), .black.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .blendMode(.multiply)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
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
