import SwiftData
import SwiftUI

@main
struct MynikApp: App {
    static let mainWindowID = "main"

    private let modelContainer = SharedModelContainer.shared
    @State private var storeSync = StoreSyncCoordinator(defaults: AppEnvironment.defaults)
    @State private var router = AppRouter()
    #if os(macOS)
    @AppStorage(SettingsKey.showMenuBarExtra) private var showMenuBarExtra = true
    #endif

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            RootView()
                .environment(\.locale, .app)
                .environment(storeSync)
                .environment(router)
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Pesquisar no Mynik…", systemImage: "magnifyingglass") {
                    router.isSearching = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(StoreBackgroundRefresh.taskIdentifier)) { [modelContainer, storeSync] in
            await StoreBackgroundRefresh.run(container: modelContainer, coordinator: storeSync)
        }
        #endif

        #if os(macOS)
        MenuBarExtra("Mynik", systemImage: "eurosign.circle", isInserted: $showMenuBarExtra) {
            MenuBarContentView()
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
