import SwiftUI

/// Navegação por separadores, usada no iPhone.
struct TabNavigationView: View {
    @State private var selection: AppSection = .today

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.symbolName, value: section) {
                    NavigationStack {
                        SectionDestination(section: section)
                    }
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    TabNavigationView()
}
