import SwiftUI

/// Editor do valor de uma propriedade numa linha de base de dados.
struct PropertyValueEditor: View {
    let row: Note
    let property: NoteProperty
    /// Chamado quando se cria uma opção nova numa seleção.
    var onAddOption: (String) -> Void = { _ in }

    @State private var isAddingOption = false
    @State private var newOption = ""

    private var value: Binding<String> {
        Binding { row.value(for: property) } set: { row.setValue($0, for: property) }
    }

    var body: some View {
        switch property.type {
        case .text:
            TextField(property.name, text: value)
                .textFieldStyle(.plain)
        case .number:
            TextField("0", text: value)
                .textFieldStyle(.plain)
                .monospacedDigit()
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        case .checkbox:
            Toggle(property.name, isOn: Binding {
                value.wrappedValue == "true"
            } set: {
                value.wrappedValue = $0 ? "true" : ""
            })
            .labelsHidden()
            .toggleStyle(.checkbox)
        case .date:
            dateEditor
        case .select:
            selectEditor
        }
    }

    @ViewBuilder
    private var dateEditor: some View {
        if let date = NoteDatabase.date(from: value.wrappedValue) {
            HStack(spacing: 4) {
                DatePicker(property.name, selection: Binding {
                    date
                } set: {
                    value.wrappedValue = NoteDatabase.dateValue($0)
                }, displayedComponents: .date)
                .labelsHidden()
                Button("Limpar data", systemImage: "xmark.circle.fill") { value.wrappedValue = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button("Definir data") { value.wrappedValue = NoteDatabase.dateValue(.now) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }

    private var selectEditor: some View {
        Menu {
            ForEach(property.options, id: \.self) { option in
                Button(option) { value.wrappedValue = option }
            }
            Divider()
            Button("Nova opção…", systemImage: "plus") {
                newOption = ""
                isAddingOption = true
            }
            if !value.wrappedValue.isEmpty {
                Button("Limpar", systemImage: "xmark", role: .destructive) { value.wrappedValue = "" }
            }
        } label: {
            SelectTag(text: value.wrappedValue)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .tint(.primary)
        .fixedSize()
        .alert("Nova opção", isPresented: $isAddingOption) {
            TextField("Nome", text: $newOption)
            Button("Criar") {
                let option = newOption.trimmingCharacters(in: .whitespaces)
                guard !option.isEmpty else { return }
                onAddOption(option)
                value.wrappedValue = option
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

/// Etiqueta colorida de uma opção (a cor vem do texto, sempre a mesma).
struct SelectTag: View {
    let text: String

    static let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .yellow, .red, .indigo, .brown]

    static func color(for text: String) -> Color {
        let sum = text.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        if text.isEmpty {
            Text("Vazio").foregroundStyle(.tertiary)
        } else {
            Text(text)
                .font(.callout)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Self.color(for: text).opacity(0.2), in: .capsule)
                .foregroundStyle(.primary)
        }
    }
}

#if os(iOS)
/// No iOS não há estilo de caixa: usa-se um botão com o símbolo.
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(configuration.isOn ? "Marcado" : "Por marcar")
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
#endif

/// Propriedades de uma linha, mostradas no topo da página dela.
struct NoteRowPropertiesView: View {
    @Bindable var row: Note
    let database: Note

    var body: some View {
        ForEach(database.databaseProperties) { property in
            LabeledContent {
                PropertyValueEditor(row: row, property: property) { option in
                    var updated = property
                    updated.options.append(option)
                    NoteDatabase.update(updated, in: database)
                }
            } label: {
                Label(property.name, systemImage: property.type.symbolName)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
