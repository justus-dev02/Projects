import SwiftUI
import ProjectsCore

/// Lets the user pick one of the palette colors. Every swatch is announced by name.
public struct ColorPalettePicker: View {
    @Binding var selection: String
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 30

    public init(selection: Binding<String>) {
        _selection = selection
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchSize + TFSpacing.small))], spacing: TFSpacing.small) {
            ForEach(ColorPalette.all) { color in
                let isSelected = color.hex.caseInsensitiveCompare(selection) == .orderedSame
                Button {
                    selection = color.hex
                } label: {
                    Circle()
                        .fill(Color(hex: color.hex))
                        .frame(width: swatchSize, height: swatchSize)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(isSelected ? Color(hex: color.hex) : .clear, lineWidth: 2)
                        }
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.name))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// Lets the user pick an SF Symbol.
public struct SymbolPicker: View {
    @Binding var selection: String
    let symbols: [String]
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var cellSize: CGFloat = 40

    public init(selection: Binding<String>, symbols: [String] = ColorPalette.symbols, tint: Color = TFColor.accent) {
        _selection = selection
        self.symbols = symbols
        self.tint = tint
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellSize))], spacing: TFSpacing.small) {
            ForEach(symbols, id: \.self) { symbol in
                let isSelected = symbol == selection
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.body)
                        .frame(width: cellSize, height: cellSize)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background(isSelected ? tint : TFColor.surfaceSecondary, in: .rect(cornerRadius: TFRadius.small))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(symbol.replacing(".", with: " ")))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
