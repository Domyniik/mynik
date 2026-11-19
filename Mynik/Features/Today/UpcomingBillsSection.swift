import SwiftData
import SwiftUI

/// Contas por pagar que vencem nos próximos `days` dias (inclui as atrasadas).
struct UpcomingBillsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]

    init(days: Int, now: Date = .now, calendar: Calendar = .current) {
        let startOfToday = calendar.startOfDay(for: now)
        let limit = calendar.date(byAdding: .day, value: days + 1, to: startOfToday) ?? startOfToday
        _bills = Query(
            filter: #Predicate<Bill> { !$0.isPaid && $0.dueDate < limit },
            sort: \Bill.dueDate
        )
    }

    var body: some View {
        Section("Contas a vencer") {
            if bills.isEmpty {
                Label("Nada a pagar nos próximos 7 dias", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bills) { bill in
                    BillRow(bill: bill, onPay: { pay(bill) })
                        .swipeActions(edge: .leading) {
                            Button("Paguei", systemImage: "checkmark") { pay(bill) }
                                .tint(.green)
                        }
                }
            }
        }
    }

    private func pay(_ bill: Bill) {
        withAnimation {
            BillPaymentService.markPaid(bill, in: modelContext)
            try? modelContext.save()
        }
    }
}
