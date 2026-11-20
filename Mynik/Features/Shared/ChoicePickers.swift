import SwiftUI

/// Grelha de cores da paleta `CategoryColor` para escolher uma.
struct ColorChoicePicker: View {
    @Binding var selection: CategoryColor

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 32), spacing: 10)], spacing: 10) {
            ForEach(CategoryColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if color == selection {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue)
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

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.body)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(symbol == selection ? .white : tint)
                        .background(symbol == selection ? tint : tint.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
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

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.45))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: .circle)
            .accessibilityHidden(true)
    }
}
