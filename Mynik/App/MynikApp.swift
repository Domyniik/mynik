import SwiftData
import SwiftUI

@main
struct MynikApp: App {
    private let modelContainer = SharedModelContainer.shared
    @State private var storeSync = StoreSyncCoordinator(defaults: AppEnvironment.defaults)

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
