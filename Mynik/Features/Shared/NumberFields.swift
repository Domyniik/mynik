import SwiftUI

/// Campo de valor monetário alinhado à direita, com teclado numérico no iPhone.
struct AmountField: View {
    let title: String
    @Binding var value: Decimal
    var currencyCode = Currency.defaultCode

    var body: some View {
        LabeledContent(title) {
            TextField(title, value: $value, format: .currency(code: currencyCode).locale(.app))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }
}

/// Campo numérico com unidade ("km", "L"...), alinhado à direita.
struct UnitNumberField: View {
    let title: String
    @Binding var value: Int
    let unit: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: $value, format: .number.locale(.app))
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}

/// Campo decimal (litros, unidades...) com unidade, alinhado à direita.
struct UnitDecimalField: View {
    let title: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...3)).locale(.app))
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}
