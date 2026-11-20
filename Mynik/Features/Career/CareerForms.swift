import SwiftData
import SwiftUI

/// Criar ou editar uma candidatura.
struct ApplicationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let application: JobApplication?

    @State private var company: String
    @State private var role: String
    @State private var appliedAt: Date
    @State private var status: ApplicationStatus
    @State private var hasFollowUp: Bool
    @State private var followUpDate: Date
    @State private var location: String
    @State private var link: String
    @State private var salary: String
    @State private var contact: String
    @State private var notes: String

    init(application: JobApplication? = nil) {
        self.application = application
        _company = State(initialValue: application?.company ?? "")
        _role = State(initialValue: application?.role ?? "")
        _appliedAt = State(initialValue: application?.appliedAt ?? .now)
        _status = State(initialValue: application?.status ?? .applied)
        _hasFollowUp = State(initialValue: application.map { $0.followUpDate != nil } ?? true)
        _followUpDate = State(initialValue: application?.followUpDate ?? CareerStats.suggestedFollowUp(after: .now))
        _location = State(initialValue: application?.location ?? "")
        _link = State(initialValue: application?.link ?? "")
        _salary = State(initialValue: application?.salary ?? "")
        _contact = State(initialValue: application?.contact ?? "")
        _notes = State(initialValue: application?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Nomes de empresas e cargos não passam pelo corretor.
                    TextField("Empresa", text: $company)
                        .autocorrectionDisabled()
                    TextField("Cargo", text: $role)
                        .autocorrectionDisabled()
                    DatePicker("Candidatei-me a", selection: $appliedAt, displayedComponents: .date)
                    Picker("Estado", selection: $status.animation()) {
                        ForEach(ApplicationStatus.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
                    }
                }
                if status.isActive {
                    Section {
                        Toggle("Lembrar follow-up", isOn: $hasFollowUp.animation())
                        if hasFollowUp {
                            DatePicker("Follow-up a", selection: $followUpDate, displayedComponents: .date)
                        }
                    } footer: {
                        Text("Recebes um aviso às 9:00 e aparece na tela Hoje.")
                    }
                }
                Section("Detalhes") {
                    TextField("Local (cidade, remoto…)", text: $location)
                    TextField("Link do anúncio", text: $link)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    TextField("Salário", text: $salary)
                    TextField("Contacto (recrutador)", text: $contact)
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(2...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(application == nil ? "Nova candidatura" : "Candidatura")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(company.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 560)
        #endif
    }

    private func save() {
        let target = application ?? JobApplication(company: "", role: "")
        target.company = company.trimmingCharacters(in: .whitespaces)
        target.role = role.trimmingCharacters(in: .whitespaces)
        target.appliedAt = appliedAt
        target.status = status
        target.followUpDate = status.isActive && hasFollowUp ? followUpDate : nil
        target.location = location.trimmingCharacters(in: .whitespaces)
        target.link = link.trimmingCharacters(in: .whitespaces)
        target.salary = salary
        target.contact = contact
        target.notes = notes
        if application == nil { modelContext.insert(target) }
        try? modelContext.save()
        dismiss()
    }
}

/// Criar ou editar um curso ou certificação.
struct CourseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let course: Course?

    @State private var title: String
    @State private var provider: String
    @State private var status: CourseStatus
    @State private var progress: Double
    @State private var link: String
    @State private var credentialID: String
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var notes: String

    init(course: Course? = nil) {
        self.course = course
        _title = State(initialValue: course?.title ?? "")
        _provider = State(initialValue: course?.provider ?? "")
        _status = State(initialValue: course?.status ?? .inProgress)
        _progress = State(initialValue: course?.progress ?? 0)
        _link = State(initialValue: course?.link ?? "")
        _credentialID = State(initialValue: course?.credentialID ?? "")
        _hasExpiry = State(initialValue: course?.expiresAt != nil)
        _expiresAt = State(initialValue: course?.expiresAt ?? Calendar.current.date(byAdding: .year, value: 3, to: .now) ?? .now)
        _notes = State(initialValue: course?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Curso ou certificação", text: $title)
                    TextField("Plataforma / entidade", text: $provider)
                    Picker("Estado", selection: $status.animation()) {
                        ForEach(CourseStatus.allCases) { Text($0.title).tag($0) }
                    }
                    if status == .inProgress {
                        LabeledContent("Progresso") {
                            Slider(value: $progress, in: 0...1, step: 0.05)
                                .frame(maxWidth: 220)
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
                Section {
                    TextField("Link", text: $link)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    TextField("ID da credencial", text: $credentialID)
                    Toggle("O certificado expira", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("Expira a", selection: $expiresAt, displayedComponents: .date)
                    }
                } header: {
                    Text("Certificado")
                } footer: {
                    if hasExpiry {
                        Text("Avisamos 60 dias antes de expirar para teres tempo de renovar.")
                    }
                }
                Section("Notas") {
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(course == nil ? "Novo curso" : "Curso")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 500)
        #endif
    }

    private func save() {
        let target = course ?? Course(title: "")
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.provider = provider.trimmingCharacters(in: .whitespaces)
        target.status = status
        if status == .inProgress { target.progress = progress }
        if status == .planned { target.progress = 0 }
        target.link = link.trimmingCharacters(in: .whitespaces)
        target.credentialID = credentialID
        target.expiresAt = hasExpiry ? expiresAt : nil
        target.notes = notes
        if course == nil { modelContext.insert(target) }
        try? modelContext.save()
        dismiss()
    }
}
