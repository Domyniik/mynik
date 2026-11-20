import SwiftData
import SwiftUI

/// Cursos e certificações agrupados por estado.
struct CoursesList: View {
    @Binding var editing: Course?
    @Binding var isAdding: Bool

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]

    var body: some View {
        if courses.isEmpty {
            ContentUnavailableView {
                Label("Sem cursos", systemImage: "graduationcap")
            } description: {
                Text("Guarda os cursos e certificações, o progresso e a validade dos certificados.")
            } actions: {
                Button("Novo curso") { isAdding = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        ForEach(CourseStatus.allCases) { status in
            let group = courses.filter { $0.status == status }
            if !group.isEmpty {
                Section(status.title) {
                    ForEach(group) { course in
                        Button { editing = course } label: {
                            CourseRow(course: course)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Apagar", systemImage: "trash", role: .destructive) { delete(course) }
                        }
                        .contextMenu {
                            if course.status != .completed {
                                Button("Marcar como concluído", systemImage: "checkmark") {
                                    course.status = .completed
                                    try? modelContext.save()
                                }
                            }
                            if let url = course.url {
                                Link(destination: url) { Label("Abrir", systemImage: "safari") }
                            }
                            Button("Apagar", systemImage: "trash", role: .destructive) { delete(course) }
                        }
                    }
                }
            }
        }
    }

    private func delete(_ course: Course) {
        withAnimation {
            modelContext.delete(course)
            try? modelContext.save()
        }
    }
}

struct CourseRow: View {
    let course: Course

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: course.status.symbolName, color: course.status == .completed ? .green : .indigo)
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title).lineLimit(1)
                if course.status == .inProgress {
                    ProgressView(value: course.progress).tint(.indigo)
                }
                Text(details)
                    .font(.caption)
                    .foregroundStyle(isExpiringSoon ? .orange : .secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(.rect)
    }

    private var isExpiringSoon: Bool {
        course.expiresAt.map { DueDateText.daysUntil($0) <= 60 } ?? false
    }

    private var details: String {
        var parts = [course.provider].filter { !$0.isEmpty }
        if course.status == .inProgress {
            parts.append(course.progress.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
        }
        if let completed = course.completedAt {
            parts.append("concluído em \(completed.formatted(.dateTime.month(.abbreviated).year().locale(.app)))")
        }
        if let expires = course.expiresAt {
            parts.append(DocumentStatus.describe(expiry: expires))
        }
        return parts.joined(separator: " · ")
    }
}
