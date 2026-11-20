import SwiftUI

/// Eventos do Calendário e lembretes de hoje.
struct TodayCalendarSection: View {
    @AppStorage(SettingsKey.showCalendarOnToday) private var isEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    private let service = CalendarService.shared

    var body: some View {
        if isEnabled {
            Section("Calendário e lembretes") {
                content
            }
            .task(id: scenePhase) {
                if scenePhase == .active { await service.reload() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if service.needsRequest && !service.hasAnyAccess {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vê aqui os eventos e os lembretes de hoje.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Ligar Calendário e Lembretes", systemImage: "calendar.badge.plus") {
                        Task { await service.requestAccess() }
                    }
                    .buttonStyle(.glassProminent)
                    Button("Agora não") { isEnabled = false }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
        } else if !service.hasAnyAccess {
            Label("Sem acesso ao Calendário e aos Lembretes. Ativa-o nos Ajustes do sistema, em Privacidade.", systemImage: "lock")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else if service.items.isEmpty {
            Label("Nada no calendário hoje", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        } else {
            ForEach(service.items.prefix(8)) { item in
                CalendarDayRow(item: item) {
                    Task { await service.complete(item) }
                }
            }
        }
    }
}

/// Linha de um evento (barra com a cor do calendário) ou lembrete (círculo para marcar).
struct CalendarDayRow: View {
    let item: CalendarDayItem
    var onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if item.isReminder {
                Button(action: onComplete) {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Marcar \(item.title) como feito")
            } else {
                Capsule()
                    .fill(tint)
                    .frame(width: 4, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.timeText(on: .now))
                    if !item.location.isEmpty {
                        Text("· \(item.location)")
                    }
                }
                .font(.caption)
                .foregroundStyle(isOverdue ? .red : .secondary)
                .lineLimit(1)
            }
        }
    }

    private var tint: Color {
        guard item.color.count == 3 else { return .accentColor }
        return Color(red: item.color[0], green: item.color[1], blue: item.color[2])
    }

    private var isOverdue: Bool {
        if case .reminder(let due?, _) = item.kind {
            return Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: .now)
        }
        return false
    }
}
