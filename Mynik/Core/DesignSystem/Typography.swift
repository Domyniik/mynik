import SwiftUI

/// Escalas de tipografia dos números (saldos, KPIs).
///
/// Usam estilos de texto, por isso crescem com o Dynamic Type.
enum NumberStyle {
    /// Número principal de um ecrã (saldo, património).
    case display
    /// Número de um cartão de KPI.
    case kpi
    /// Número secundário dentro de um cartão.
    case figure

    var font: Font {
        switch self {
        case .display: .system(.largeTitle, design: .rounded, weight: .bold)
        case .kpi: .system(.title2, design: .rounded, weight: .semibold)
        case .figure: .system(.headline, design: .rounded, weight: .semibold)
        }
    }
}

extension View {
    /// Número arredondado, com algarismos de largura fixa e animação ao mudar.
    func numberStyle(_ style: NumberStyle) -> some View {
        font(style.font)
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
