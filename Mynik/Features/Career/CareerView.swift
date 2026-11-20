import SwiftData
import SwiftUI

/// Carreira: candidaturas (por estado, com follow-ups) e cursos/certificações.
struct CareerView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case applications, courses
        var id: Self { self }
        var title: String { self == .applications ? "Candidaturas" : "Cursos" }
    }

    @State private var tab: Tab = .applications
    @State private var editingApplication: JobApplication?
    @State private var editingCourse: Course?
    @State private var isAddingApplication = false
    @State private var isAddingCourse = false

    var body: some View {
        List {
            Picker("Ver", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            switch tab {
            case .applications:
                ApplicationsList(editing: $editingApplication, isAdding: $isAddingApplication)
            case .courses:
                CoursesList(editing: $editingCourse, isAdding: $isAddingCourse)
            }
        }
        .navigationTitle("Carreira")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(tab == .applications ? "Nova candidatura" : "Novo curso", systemImage: "plus") {
                    if tab == .applications { isAddingApplication = true } else { isAddingCourse = true }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingApplication) { ApplicationFormView() }
        .sheet(item: $editingApplication) { ApplicationFormView(application: $0) }
        .sheet(isPresented: $isAddingCourse) { CourseFormView() }
        .sheet(item: $editingCourse) { CourseFormView(course: $0) }
    }
}

/// Resumo e candidaturas agrupadas por estado.
struct ApplicationsList: View {
    @Binding var editing: JobApplication?
    @Binding var isAdding: Bool

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobApplication.appliedAt, order: .reverse) private var applications: [JobApplication]

    var body: some View {
        if applications.isEmpty {
            ContentUnavailableView {
                Label("Sem candidaturas", systemImage: "briefcase")
            } description: {
                Text("Regista cada candidatura com a empresa e a data. Lembramos-te do follow-up uma semana depois.")
            } actions: {
                Button("Nova candidatura") { isAdding = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            CareerSummarySection(stats: CareerStats(statuses: applications.map(\.status)))
            ForEach(ApplicationStatus.allCases) { status in
                let group = applications.filter { $0.status == status }
                if !group.isEmpty {
                    Section(status.title) {
                        ForEach(group) { application in
                            Button { editing = application } label: {
                                ApplicationRow(application: application)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { menu(for: application) }
                            .swipeActions(edge: .leading) {
                                if application.status.isActive {
                                    Button("Follow-up feito", systemImage: "arrow.uturn.forward") { followedUp(application) }
                                        .tint(.blue)
                                }
                            }
                            .swipeActions {
                                Button("Apagar", systemImage: "trash", role: .destructive) { delete(application) }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for application: JobApplication) -> some View {
        Picker("Estado", selection: Binding(get: { application.status }, set: { setStatus($0, of: application) })) {
            ForEach(ApplicationStatus.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
        }
        if application.status.isActive {
            Button("Follow-up feito (próximo daqui a 7 dias)", systemImage: "arrow.uturn.forward") { followedUp(application) }
        }
        if let url = application.url {
            Link(destination: url) { Label("Abrir anúncio", systemImage: "safari") }
        }
        Button("Apagar", systemImage: "trash", role: .destructive) { delete(application) }
    }

    private func setStatus(_ status: ApplicationStatus, of application: JobApplication) {
        withAnimation {
            application.status = status
            try? modelContext.save()
        }
    }

    private func followedUp(_ application: JobApplication) {
        application.followUpDate = CareerStats.suggestedFollowUp(after: .now)
        try? modelContext.save()
    }

    private func delete(_ application: JobApplication) {
        withAnimation {
            modelContext.delete(application)
            try? modelContext.save()
        }
    }
}

struct CareerSummarySection: View {
    let stats: CareerStats

    var body: some View {
        Section {
            HStack {
                stat("\(stats.active)", "Ativas")
                Divider()
                stat("\(stats.interviews)", "Entrevistas")
                Divider()
                stat("\(stats.offers)", "Propostas")
                Divider()
                stat(stats.responseRate.map { $0.formatted(.percent.precision(.fractionLength(0)).locale(.app)) } ?? "—", "Respostas")
            }
            .padding(.vertical, 4)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ApplicationRow: View {
    let application: JobApplication

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbolName: application.status.symbolName, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(application.company).lineLimit(1)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let followUp = application.followUpDate, application.status.isActive {
                    let isDue = DueDateText.daysUntil(followUp) <= 0
                    Text("\(Image(systemName: "bell")) Follow-up \(followUp.formatted(.dateTime.day().month(.abbreviated).locale(.app)))")
                        .font(.caption)
                        .foregroundStyle(isDue ? .orange : .secondary)
                }
            }
        }
        .contentShape(.rect)
    }

    private var details: String {
        [application.role, application.location, application.appliedAt.formatted(.dateTime.day().month(.abbreviated).locale(.app))]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var color: Color {
        switch application.status {
        case .applied: .blue
        case .interviewing: .purple
        case .offer, .accepted: .green
        case .rejected: .red
        case .noResponse: .gray
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        CareerView()
    }
}
