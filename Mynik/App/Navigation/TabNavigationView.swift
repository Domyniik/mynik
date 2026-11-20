import SwiftUI

/// Navegação por separadores, usada no iPhone.
///
/// Com mais de cinco secções o iOS criaria o separador "Mais" do sistema, que
/// empilha a sua própria barra de navegação sobre a de cada secção. Por isso o
/// "Mais" é feito aqui, numa só `NavigationStack`.
struct TabNavigationView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selection) {
            ForEach(AppSection.primaryTabs) { section in
                Tab(section.title, systemImage: section.symbolName, value: Optional(section)) {
                    NavigationStack {
                        SectionDestination(section: section)
                    }
                }
            }
            Tab("Mais", systemImage: "ellipsis", value: AppSection?.none) {
                NavigationStack(path: $router.morePath) {
                    MoreSectionsView()
                }
            }
        }
        // Liquid Glass: a barra de separadores encolhe ao percorrer o conteúdo.
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .onAppear { router.navigationDidAppear(usingTabs: true) }
    }
}

/// Lista das secções sem separador próprio.
struct MoreSectionsView: View {
    var body: some View {
        List(AppSection.moreTabs) { section in
            NavigationLink(value: section) {
                Label(section.title, systemImage: section.symbolName)
            }
        }
        .navigationTitle("Mais")
        .navigationDestination(for: AppSection.self) { section in
            SectionDestination(section: section)
        }
    }
}

#Preview(traits: .sampleData) {
    TabNavigationView()
        .environment(AppRouter())
}
