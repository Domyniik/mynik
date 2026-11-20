import SwiftData
import SwiftUI

/// "Pergunte ao Mynik": chat sobre os próprios dados.
struct AskMynikView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currencyConverter) private var converter

    @State private var model = AskMynikModel()
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    statusBanner
                    if model.messages.isEmpty {
                        suggestions
                    }
                    ForEach(model.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if model.isResponding {
                        ProgressView()
                            .accessibilityLabel("A pensar")
                            .id("typing")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) {
                withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle("Pergunte ao Mynik")
        .toolbar {
            if !model.messages.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Nova conversa", systemImage: "square.and.pencil") { model.reset() }
                }
            }
        }
        .task { model.refreshStatus() }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if model.status.isAvailable {
            Label("Apple Intelligence no dispositivo · os teus dados não saem daqui", systemImage: "sparkles")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modo sem IA").font(.subheadline.bold())
                    Text("\(model.status.message) Respondo com resumos dos teus dados.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 12))
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Experimenta perguntar")
                .font(.headline)
            ForEach(AskMynikModel.suggestions, id: \.self) { suggestion in
                Button(suggestion) { ask(suggestion) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Pergunta sobre os teus dados…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit { ask(draft) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
            Button("Enviar", systemImage: "arrow.up") { ask(draft) }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || model.isResponding)
        }
        .padding()
    }

    private func ask(_ question: String) {
        draft = ""
        let container = modelContext.container
        Task { await model.send(question, container: container, converter: converter) }
    }
}

/// Balão de uma mensagem.
private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .textSelection(.enabled)
                if message.isOffline {
                    Label("Resumo dos dados (sem IA)", systemImage: "list.bullet.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .background(isUser ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary), in: .rect(cornerRadius: 16))
            if !isUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "Tu: \(message.text)" : "Mynik: \(message.text)")
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        AskMynikView()
    }
}
