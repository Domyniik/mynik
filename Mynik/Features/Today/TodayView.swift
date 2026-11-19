import SwiftUI

struct TodayView: View {
    var body: some View {
        ContentUnavailableView("Hoje", systemImage: "sun.max", description: Text("Em breve."))
            .navigationTitle("Hoje")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        TodayView()
    }
}
