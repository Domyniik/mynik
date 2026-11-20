import Foundation
import SwiftData

/// Contentor SwiftData único do processo: usado pela app e pelos App Intents
/// (Siri / Atalhos), que podem correr sem nenhuma janela aberta.
@MainActor
enum SharedModelContainer {
    static let shared: ModelContainer = {
        do {
            // Os testes correm dentro da app: nunca podem tocar na base de dados real.
            let container = try ModelContainerFactory.make(inMemory: AppEnvironment.isRunningTests)
            try DefaultDataSeeder.seedIfNeeded(in: container.mainContext)
            try StableIDRepair.runIfNeeded(in: container.mainContext, defaults: AppEnvironment.defaults)
            return container
        } catch {
            fatalError("Não foi possível abrir a base de dados: \(error)")
        }
    }()
}
