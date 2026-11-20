import SwiftUI
import WidgetKit

/// Contas por pagar: atrasadas e próximas.
struct UpcomingBillsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpcomingBills", provider: SnapshotProvider()) { entry in
            UpcomingBillsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .app)
        }
        .configurationDisplayName("Contas a vencer")
        .description("As próximas contas a pagar, com as atrasadas primeiro.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UpcomingBillsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                Label("Contas a vencer", systemImage: "calendar.badge.clock")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                BillList(bills: Array(snapshot.bills.prefix(limit)), now: entry.date, emptyText: "Nada a pagar nos próximos 30 dias")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            OpenAppHint()
        }
    }

    private var limit: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 3
        default: 8
        }
    }
}

/// Lista compacta de contas com o valor e quando vencem.
struct BillList: View {
    let bills: [WidgetSnapshot.BillItem]
    let now: Date
    let emptyText: String

    var body: some View {
        if bills.isEmpty {
            Label(emptyText, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bills) { bill in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(bill.title)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(Currency.format(bill.amount, code: bill.currencyCode))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.medium))
                        Text(DueDateText.describe(bill.dueDate, from: now))
                            .font(.caption2)
                            .foregroundStyle(DueDateText.isOverdue(bill.dueDate, from: now) ? .red : .secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview(as: .systemMedium) {
    UpcomingBillsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview)
}
