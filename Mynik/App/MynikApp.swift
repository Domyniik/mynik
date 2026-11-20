import SwiftData
import SwiftUI

@main
struct MynikApp: App {
    private let modelContainer: ModelContainer
    @State private var storeSync = StoreSyncCoordinator(
        defaults: AppEnvironment.isRunningTests ? AppEnvironment.testDefaults : .standard
    )

    init() {
        do {
            // Os testes correm dentro da app: nunca podem tocar na base de dados real.
            modelContainer = try ModelContainerFactory.make(inMemory: AppEnvironment.isRunningTests)
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
        #if os(iOS)
        .backgroundTask(.appRefresh(StoreBackgroundRefresh.taskIdentifier)) { [modelContainer, storeSync] in
            await StoreBackgroundRefresh.run(container: modelContainer, coordinator: storeSync)
        }
        #endif
    }
}
