import SwiftData
import SwiftUI

/// Definições → Conta: login opcional por email com código e sync entre o Mac e o iPhone.
struct AccountSettingsSection: View {
    @Environment(AccountSync.self) private var account
    @Environment(\.modelContext) private var modelContext

    @State private var email = ""
    @State private var code = ""
    @State private var codeSentTo: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if !account.isConfigured {
                Text("Esta versão foi compilada sem o Supabase: os dados ficam só neste dispositivo.")
                    .foregroundStyle(.secondary)
            } else if account.isSignedIn {
                signedIn
            } else if let codeSentTo {
                codeEntry(for: codeSentTo)
            } else {
                emailEntry
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            ListSectionHeader("Conta", systemImage: "person.crop.circle", color: .blue)
        } footer: {
            Text("Opcional. Com sessão iniciada, os dados sincronizam entre o Mac e o iPhone pelo Supabase. Sem conta ou sem rede, tudo continua a funcionar aqui. As fotos dos documentos e os segredos (como o token da Shopify) nunca saem do dispositivo.")
        }
    }

    // MARK: - Estados

    @ViewBuilder
    private var signedIn: some View {
        LabeledContent("Sessão iniciada", value: account.email ?? "—")
        LabeledContent("Último sync") {
            if account.isSyncing {
                ProgressView().controlSize(.small)
            } else if let lastSyncAt = account.lastSyncAt {
                Text(lastSyncAt, format: .relative(presentation: .named))
            } else {
                Text("Nunca")
            }
        }
        if let error = account.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.orange)
        }
        Button("Sincronizar agora", systemImage: "arrow.triangle.2.circlepath") {
            Task { await account.sync(context: modelContext) }
        }
        .disabled(account.isSyncing)
        Button("Terminar sessão", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            Task { await account.signOut() }
        }
    }

    @ViewBuilder
    private var emailEntry: some View {
        TextField("Email", text: $email, prompt: Text("nome@exemplo.com"))
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            #endif
            .onSubmit(sendCode)
        Button("Enviar código", systemImage: "envelope", action: sendCode)
            .disabled(!isValidEmail || isWorking)
    }

    @ViewBuilder
    private func codeEntry(for address: String) -> some View {
        Text("Enviámos um código de 6 dígitos para \(address).")
            .foregroundStyle(.secondary)
        TextField("Código", text: $code, prompt: Text("123456"))
            .textContentType(.oneTimeCode)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onSubmit(verify)
        Button("Entrar", systemImage: "checkmark.circle", action: verify)
            .disabled(code.filter(\.isNumber).count < 6 || isWorking)
        Button("Usar outro email", systemImage: "arrow.uturn.backward") {
            codeSentTo = nil
            code = ""
            errorMessage = nil
        }
    }

    // MARK: - Ações

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private func sendCode() {
        guard isValidEmail, !isWorking else { return }
        run {
            try await account.sendCode(to: email)
            codeSentTo = email.trimmingCharacters(in: .whitespaces)
        }
    }

    private func verify() {
        guard let codeSentTo, !isWorking else { return }
        run {
            try await account.verify(email: codeSentTo, code: code)
            self.codeSentTo = nil
            code = ""
            await account.sync(context: modelContext)
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
