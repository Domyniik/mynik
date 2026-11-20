import SwiftData
import SwiftUI

@main
struct MynikApp: App {
    private let modelContainer: ModelContainer
    @State private var storeSync = StoreSyncCoordinator()

    init() {
        do {
            modelContainer = try ModelContainerFactory.make()
            try DefaultDataSeeder.seedIfNeeded(in: modelContainer.mainContext)
        } catch {
            fatalError("Não foi possível abrir a base de dados: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, .app)
                .environment(storeSync)
        }
        .modelContainer(modelContainer)
    }
}
