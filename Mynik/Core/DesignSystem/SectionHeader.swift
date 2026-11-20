import SwiftUI

/// Cabeçalho de secção: ícone com a cor do módulo, título e acessório opcional.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var symbolName: String?
    @ViewBuilder var accessory: Accessory
    @Environment(\.moduleTint) private var tint

    init(_ title: String, systemImage symbolName: String? = nil, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.symbolName = symbolName
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            if let symbolName {
                Image(systemName: symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DS.Spacing.s)
            accessory
                .font(.subheadline)
        }
    }
}
