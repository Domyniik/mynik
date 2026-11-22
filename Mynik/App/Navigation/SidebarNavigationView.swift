import SwiftUI

/// Navegação com barra lateral, usada no iPad.
struct SidebarNavigationView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(AppSection.allCases, selection: $router.selection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(section.tint)
                }
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
