import SwiftUI
import WidgetKit

/// Saldo do mês: receitas menos gastos.
struct MonthBalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthBalance", provider: SnapshotProvider()) { entry in
            MonthBalanceView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .app)
        }
        .configurationDisplayName("Saldo do mês")
        .description("Receitas, gastos e saldo do mês, e a próxima conta a pagar.")
        .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

struct MonthBalanceView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
        } else {
            OpenAppHint()
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            Text("Saldo \(Currency.format(snapshot.balance))")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "eurosign")
                    .font(.caption)
                Text(snapshot.balance.formatted(.number.notation(.compactName).locale(.app)))
                    .font(.headline)
                    .minimumScaleFactor(0.6)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Saldo de \(snapshot.monthName)")
                    .font(.caption)
                Text(Currency.format(snapshot.balance))
                    .font(.headline)
                if let bill = snapshot.bills.first {
                    Text("\(bill.title) · \(DueDateText.describe(bill.dueDate, from: entry.date).lowercased())")
                        .font(.caption)
                }
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                BalanceSummary(snapshot: snapshot)
                Divider()
                BillList(bills: Array(snapshot.bills(within: 7, from: entry.date).prefix(3)), now: entry.date, emptyText: "Nada a pagar nos próximos 7 dias")
            }
        default:
            BalanceSummary(snapshot: snapshot)
        }
    }
}

/// Saldo grande com receitas e gastos por baixo.
struct BalanceSummary: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Saldo de \(snapshot.monthName)", systemImage: "eurosign.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Currency.format(snapshot.balance))
                .font(.title2.bold())
                .foregroundStyle(snapshot.balance < 0 ? .red : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer(minLength: 0)
            amountRow("Receitas", snapshot.income, symbol: "arrow.down.left", color: .green)
            amountRow("Gastos", snapshot.expenses, symbol: "arrow.up.right", color: .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountRow(_ title: String, _ amount: Decimal, symbol: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(Currency.format(amount))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(.caption)
        .accessibilityLabel("\(title): \(Currency.format(amount))")
    }
}

/// Mostrado quando a app ainda não escreveu o resumo.
struct OpenAppHint: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.up.forward.app")
                .font(.title2)
            Text("Abre o Mynik para ver os teus dados")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }
}
