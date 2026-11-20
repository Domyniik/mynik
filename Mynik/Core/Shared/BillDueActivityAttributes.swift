#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity (ecrã bloqueado e Dynamic Island) das contas que vencem hoje.
///
/// Partilhado entre a app (que a inicia, atualiza e termina localmente, sem push)
/// e a extensão de widgets (que a desenha).
nonisolated struct BillDueActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// A conta mais urgente.
        var title: String
        var amountText: String
        /// Contas por pagar hoje (incluindo atrasadas).
        var count: Int
        var totalText: String
        var hasOverdue: Bool
    }

    /// Dia a que a atividade se refere (início do dia).
    var day: Date
}
#endif
