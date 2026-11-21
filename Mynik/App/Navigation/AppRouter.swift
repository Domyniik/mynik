import Observation
import SwiftUI

/// Estado da navegação partilhado pela barra lateral, pelos separadores e pela busca ⌘K.
@MainActor
@Observable
final class AppRouter {
    /// Secção escolhida. Nos separadores do iPhone, `nil` é o separador "Mais".
    var selection: AppSection? = .today
    /// Pilha do separador "Mais" (iPhone). Sem tipo fixo: as secções empurram
    /// também os seus próprios destinos (notas, projetos…).
    var morePath = NavigationPath()
    /// A busca global está aberta.
    var isSearching = false
    /// A navegação atual é por separadores (iPhone).
    var usesTabs = false

    /// Secção inicial pedida com `-MynikSection <secção>` (modo de demonstração, screenshots).
    private var pendingLaunchSection: AppSection? = AppEnvironment.isDemo
        ? UserDefaults.standard.string(forKey: "MynikSection").flatMap(AppSection.init(rawValue:))
        : nil

    /// Chamado quando a navegação aparece: aplica a secção inicial, se houver.
    func navigationDidAppear(usingTabs: Bool) {
        usesTabs = usingTabs
        if let section = pendingLaunchSection {
            pendingLaunchSection = nil
            open(section)
        }
    }

    func open(_ section: AppSection) {
        if usesTabs, !AppSection.primaryTabs.contains(section) {
            selection = nil
            morePath = NavigationPath([section])
        } else {
            selection = section
        }
    }
}
