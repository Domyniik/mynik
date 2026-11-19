import SwiftUI

/// Linha de uma conta a pagar, com botão "Paguei" opcional.
struct BillRow: View {
    let bill: Bill
    var onPay: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: bill.category)

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(Currency.format(bill.amount, code: bill.currencyCode))
                    .monospacedDigit()

                if let onPay, !bill.isPaid {
                    Button("Paguei", systemImage: "checkmark", action: onPay)
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.green)
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
