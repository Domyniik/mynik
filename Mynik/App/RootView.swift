import SwiftUI

/// Vista raiz da app. A navegação completa chega na próxima feature.
struct RootView: View {
    var body: some View {
        ContentUnavailableView(
            "Mynik",
            systemImage: "square.grid.2x2",
            description: Text("A tua vida, num só lugar.")
        )
    }
}

#Preview {
    RootView()
}
