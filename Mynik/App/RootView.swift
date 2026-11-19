import SwiftUI

/// Escolhe a navegação certa para cada dispositivo:
/// barra lateral no Mac/iPad, separadores no iPhone.
struct RootView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            TabNavigationView()
        } else {
            SidebarNavigationView()
        }
        #else
        SidebarNavigationView()
        #endif
    }
}

#Preview(traits: .sampleData) {
    RootView()
}
