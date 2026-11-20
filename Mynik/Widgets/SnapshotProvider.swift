import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    /// `nil` quando a app ainda não escreveu nada (ou o App Group não está disponível).
    let snapshot: WidgetSnapshot?
}

/// Lê o resumo que a app deixou no App Group.
///
/// Gera uma entrada por dia (à meia-noite) para que "vence hoje / amanhã"
/// avance sozinho; a app pede uma atualização sempre que os dados mudam.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? (WidgetSnapshot.load() ?? .preview) : WidgetSnapshot.load()
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [SnapshotEntry(date: .now, snapshot: snapshot)]
        for day in 1...7 {
            if let date = calendar.date(byAdding: .day, value: day, to: today) {
                entries.append(SnapshotEntry(date: date, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
