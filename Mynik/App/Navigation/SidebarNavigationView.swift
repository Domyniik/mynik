import SwiftUI

/// Navegação com barra lateral, usada no Mac e no iPad.
struct SidebarNavigationView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(AppSection.allCases, selection: $router.selection) { section in
                Label(section.title, systemImage: section.symbolName)
            }
            .navigationTitle("Mynik")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            NavigationStack {
                if let selection = router.selection {
                    SectionDestination(section: selection)
                } else {
                    ContentUnavailableView("Escolhe uma secção", systemImage: "sidebar.left")
                }
            }
        }
        .onAppear { router.navigationDidAppear(usingTabs: false) }
    }
}

#Preview(traits: .sampleData) {
    SidebarNavigationView()
        .environment(AppRouter())
}
