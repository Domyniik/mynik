import SwiftUI

/// Navegação com barra lateral, usada no Mac e no iPad.
struct SidebarNavigationView: View {
    @State private var selection: AppSection? = .today

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbolName)
            }
            .navigationTitle("Mynik")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            NavigationStack {
                if let selection {
                    SectionDestination(section: selection)
                } else {
                    ContentUnavailableView("Escolhe uma secção", systemImage: "sidebar.left")
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    SidebarNavigationView()
}
