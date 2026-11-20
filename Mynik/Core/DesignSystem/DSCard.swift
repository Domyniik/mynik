import SwiftUI

/// Superfície de cartão: fundo sólido arredondado com um contorno subtil.
///
/// O Liquid Glass fica reservado aos controlos (botões, seletores); o conteúdo usa superfícies sólidas.
struct CardBackground: ViewModifier {
    var padding: CGFloat = DS.Spacing.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurface, in: .rect(cornerRadius: DS.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            }
    }
}

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.l) -> some View {
        modifier(CardBackground(padding: padding))
    }

    /// Linha de `List` sem fundo nem margens, para pôr cartões próprios numa lista.
    func dsListCardRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

/// Cartão com cabeçalho de secção: o bloco base dos painéis.
struct DashboardCard<Content: View, Accessory: View>: View {
    let title: String
    var symbolName: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(
        _ title: String,
        systemImage symbolName: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbolName = symbolName
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHeader(title, systemImage: symbolName) { accessory }
            content
        }
        .dsCard()
    }
}
