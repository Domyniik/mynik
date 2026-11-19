import SwiftUI

struct FinanceView: View {
    var body: some View {
        ContentUnavailableView("Finanças", systemImage: "eurosign.circle", description: Text("Em breve."))
            .navigationTitle("Finanças")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        FinanceView()
    }
}
