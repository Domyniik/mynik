import SwiftUI

/// Grelha de cores da paleta `CategoryColor` para escolher uma.
struct ColorChoicePicker: View {
    @Binding var selection: CategoryColor
    @ScaledMetric(relativeTo: .body) private var diameter = 30

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: max(44, diameter)), spacing: 6)], spacing: 6) {
            ForEach(CategoryColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: diameter, height: diameter)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                        .overlay {
                            if color == selection {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.name)
                .accessibilityAddTraits(color == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Grelha de SF Symbols para escolher um ícone.
struct SymbolChoicePicker: View {
    let symbols: [String]
    let tint: Color
    @Binding var selection: String
    @ScaledMetric(relativeTo: .body) private var diameter = 36

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: max(44, diameter)), spacing: 8)], spacing: 8) {
            ForEach(Array(symbols.enumerated()), id: \.element) { index, symbol in
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.body)
                        .frame(width: max(44, diameter), height: max(44, diameter))
                        .foregroundStyle(symbol == selection ? .white : tint)
                        .background(symbol == selection ? tint : tint.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ícone \(index + 1) de \(symbols.count)")
                .accessibilityAddTraits(symbol == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Ícone redondo colorido (projetos, metas).
struct SymbolBadge: View {
    let symbolName: String
    let color: Color
    var size: CGFloat = 34
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Cresce com o Dynamic Type, até 1,6× nos tamanhos de acessibilidade.
        let scaled = size * (dynamicTypeSize.isAccessibilitySize ? 1.6 : dynamicTypeSize >= .xxLarge ? 1.2 : 1)
        Image(systemName: symbolName)
            .font(.system(size: scaled * 0.45))
            .foregroundStyle(.white)
            .frame(width: scaled, height: scaled)
            .background(color, in: .circle)
            .accessibilityHidden(true)
    }
}
