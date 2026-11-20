import Observation
import SwiftUI

/// Estado da navegação partilhado pela barra lateral, pelos separadores e pela busca ⌘K.
@MainActor
@Observable
final class AppRouter {
    /// Secção escolhida. Nos separadores do iPhone, `nil` é o separador "Mais".
    var selection: AppSection? = .today
    /// Pilha do separador "Mais" (iPhone).
    var morePath: [AppSection] = []
    /// A busca global está aberta.
    var isSearching = false
    /// A navegação atual é por separadores (iPhone).
    var usesTabs = false

    func open(_ section: AppSection) {
        if usesTabs, !AppSection.primaryTabs.contains(section) {
            selection = nil
            morePath = [section]
        } else {
            selection = section
        }
    }
}
