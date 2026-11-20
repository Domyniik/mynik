import SwiftData
import SwiftUI

/// Prazos a vencer (ITV, seguro, manutenções, documentos, follow-ups…), na tela Hoje.
struct TodayAgendaSection: View {
    @Query private var vehicles: [Vehicle]
    @Query private var documents: [PersonalDocument]
    @Query private var applications: [JobApplication]
    @Query private var courses: [Course]

    var body: some View {
        let items = (
            LifeAgenda.carItems(vehicles)
                + LifeAgenda.documentItems(documents)
                + LifeAgenda.careerItems(applications, courses: courses)
        ).upcoming()
        if !items.isEmpty {
            Section("A vencer") {
                ForEach(items) { item in
                    AgendaItemRow(item: item)
                }
            }
        }
    }
}

/// Linha de um item da agenda: ícone, título, detalhe e prazo.
struct AgendaItemRow: View {
    let item: AgendaItem

    var body: some View {
        let days = item.daysUntil()
        HStack(spacing: 12) {
            SymbolBadge(symbolName: item.symbolName, color: days < 0 ? .red : days <= 7 ? .orange : .indigo, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).lineLimit(1)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(item.describe())
                .font(.caption)
                .foregroundStyle(days < 0 ? .red : .secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
