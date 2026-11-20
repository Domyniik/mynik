import SwiftUI

/// Linhas dentro de um cartão, separadas por divisórias finas (alinhadas ao texto).
struct CardRows<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    var dividerInset: CGFloat = 44
    @ViewBuilder let row: (Data.Element) -> Row

    init(_ data: Data, dividerInset: CGFloat = 44, @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.data = data
        self.dividerInset = dividerInset
        self.row = row
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                if index > 0 {
                    Divider().padding(.leading, dividerInset)
                }
                row(element)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
