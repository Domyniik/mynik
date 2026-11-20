import SwiftUI

/// Linha de uma conta a pagar, com botão "Paguei" opcional.
struct BillRow: View {
    let bill: Bill
    var onPay: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Nos tamanhos de acessibilidade o valor e o botão passam para baixo do título.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            HStack(spacing: 12) {
                CategoryIcon(category: bill.category)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.title)
                        .lineLimit(isLarge ? nil : 1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                        .lineLimit(isLarge ? nil : 1)
                }
            }
            .accessibilityElement(children: .combine)

            if !isLarge { Spacer(minLength: 8) }

            VStack(alignment: isLarge ? .leading : .trailing, spacing: 4) {
                Text(Currency.format(bill.amount, code: bill.currencyCode))
                    .monospacedDigit()

                if let onPay, !bill.isPaid {
                    Button("Paguei", systemImage: "checkmark", action: onPay)
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.green)
                        // Único por linha para o VoiceOver e o Controlo por Voz.
                        .accessibilityLabel("Paguei \(bill.title)")
                        .accessibilityInputLabels(["Paguei \(bill.title)", "Pagar \(bill.title)"])
                }
            }
        }
        .contentShape(.rect)
    }

    private var isOverdue: Bool {
        !bill.isPaid && DueDateText.isOverdue(bill.dueDate)
    }

    private var subtitle: String {
        if bill.isPaid, let paidAt = bill.paidAt {
            return "Paga a \(paidAt.formatted(.dateTime.day().month(.abbreviated).locale(.app)))"
        }
        let due = DueDateText.describe(bill.dueDate)
        return bill.recurrence == .none ? due : "\(due) · \(bill.recurrence.title)"
    }
}
