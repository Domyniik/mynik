import SwiftUI

/// Tokens do sistema visual do Mynik: espaçamentos, raios e superfícies.
///
/// Os valores seguem a grelha de 4 pt das Human Interface Guidelines.
nonisolated enum DS {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    enum Radius {
        /// Cartões e blocos grandes.
        static let card: CGFloat = 22
        /// Mosaicos e elementos dentro de cartões.
        static let tile: CGFloat = 16
        /// Ícones em quadrado arredondado.
        static let badge: CGFloat = 9
    }

    /// Largura máxima do conteúdo dos painéis em ecrãs largos (Mac/iPad).
    static let readableWidth: CGFloat = 980
}

extension Color {
    /// Cor da marca Mynik (violeta), com variantes para o modo escuro e o contraste elevado.
    static let brand = Color("AccentColor")

    /// Fundo das páginas em estilo painel (agrupado).
    static var dsBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Superfície dos cartões, por cima do fundo.
    static var dsSurface: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Cores fixas do gradiente da marca (o cartão principal usa texto branco por cima).
    static let brandGradientTop = Color(red: 0.40, green: 0.30, blue: 0.95)
    static let brandGradientBottom = Color(red: 0.25, green: 0.16, blue: 0.80)
}

extension ShapeStyle where Self == LinearGradient {
    /// Gradiente da marca, usado no cartão principal e no ícone da app.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [.brandGradientTop, .brandGradientBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
