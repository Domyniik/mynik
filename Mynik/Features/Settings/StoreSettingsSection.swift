import SwiftData
import SwiftUI

/// Ligação à loja Shopify. Os segredos vão diretamente para o Keychain.
struct StoreSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreSyncCoordinator.self) private var storeSync

    @AppStorage(SettingsKey.shopifyDomain) private var savedDomain = ""
    @AppStorage(SettingsKey.shopifyShopName) private var shopName = ""

    @State private var authMode: AuthMode = .devDashboard
    @State private var domainInput = ""
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var accessToken = ""
    @State private var status: Status = .idle
    @State private var missingScopes: [String] = []

    private enum AuthMode: String, CaseIterable, Identifiable {
        case devDashboard, legacyToken
        var id: Self { self }
        var title: String {
            switch self {
            case .devDashboard: "Dev Dashboard"
            case .legacyToken: "Token antigo"
            }
        }
    }

    private enum Status: Equatable {
        case idle
        case working
        case connected(String)
        case failed(String)
    }

    private var isConnected: Bool { !savedDomain.isEmpty }

    var body: some View {
        Section {
            if isConnected {
                connectedRows
            } else {
                connectForm
                StoreConnectionGuide()
            }
            statusRow
        } header: {
            ListSectionHeader("Loja Shopify", systemImage: "storefront", color: .pink)
        } footer: {
            Text("Os segredos ficam só no Keychain deste dispositivo. O Mynik só lê dados: produtos, pedidos, inventário e relatórios.")
        }
    }

    // MARK: - Ligada

    @ViewBuilder
    private var connectedRows: some View {
        LabeledContent("Loja", value: shopName.isEmpty ? savedDomain : shopName)
        LabeledContent("Endereço", value: savedDomain)

        Button("Testar ligação", systemImage: "checkmark.shield") {
            Task { await testSavedConnection() }
        }
        .disabled(status == .working)

        Button("Desligar loja", systemImage: "xmark.circle", role: .destructive) {
            disconnect()
        }
    }

    // MARK: - Por ligar

    @ViewBuilder
    private var connectForm: some View {
        TextField("Endereço da loja", text: $domainInput, prompt: Text("neloce.myshopify.com"))
            .textContentType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)

        Picker("Tipo de app", selection: $authMode) {
            ForEach(AuthMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        switch authMode {
        case .devDashboard:
            TextField("Client ID", text: $clientID)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("Client secret", text: $clientSecret)
        case .legacyToken:
            SecureField("Token Admin API (shpat_…)", text: $accessToken)
        }

        Button("Ligar loja", systemImage: "link") {
            Task { await connect() }
        }
        .disabled(!canConnect || status == .working)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .idle:
            EmptyView()
        case .working:
            HStack {
                ProgressView()
                Text("A ligar à Shopify…").foregroundStyle(.secondary)
            }
        case .connected(let name):
            Label("Ligada a \(name)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            if !missingScopes.isEmpty {
                Label(
                    "Faltam scopes: \(missingScopes.joined(separator: ", ")). Adiciona-os numa nova versão do app e volta a instalar.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    private var canConnect: Bool {
        guard ShopifyCredentials.normalizedDomain(domainInput) != nil else { return false }
        switch authMode {
        case .devDashboard: return !trimmed(clientID).isEmpty && !trimmed(clientSecret).isEmpty
        case .legacyToken: return !trimmed(accessToken).isEmpty
        }
    }

    // MARK: - Ações

    private func connect() async {
        guard let domain = ShopifyCredentials.normalizedDomain(domainInput) else {
            status = .failed(ShopifyError.invalidDomain.localizedDescription)
            return
        }
        let auth: ShopifyAuth = switch authMode {
        case .devDashboard: .clientCredentials(clientID: trimmed(clientID), clientSecret: trimmed(clientSecret))
        case .legacyToken: .accessToken(trimmed(accessToken))
        }
        let credentials = ShopifyCredentials(shopDomain: domain, auth: auth)

        // Só guarda depois de a Shopify aceitar as credenciais.
        guard await verify(credentials) else { return }
        do {
            try credentials.save()
            clientSecret = ""
            accessToken = ""
            // Troca os dados de exemplo pelos da loja real.
            await storeSync.refresh(in: modelContext)
        } catch {
            status = .failed("Não foi possível guardar no Keychain.")
        }
    }

    private func testSavedConnection() async {
        guard let credentials = ShopifyCredentials.load() else {
            status = .failed("Não encontrei as credenciais no Keychain. Liga a loja outra vez.")
            savedDomain = ""
            return
        }
        await verify(credentials)
    }

    @discardableResult
    private func verify(_ credentials: ShopifyCredentials) async -> Bool {
        status = .working
        let client = ShopifyClient(credentials: credentials)
        do {
            let shop = try await client.fetchShop()
            let granted = await client.grantedScopes
            missingScopes = granted.isEmpty ? [] : ShopifyCredentials.requiredScopes.filter { !granted.contains($0) }
            shopName = shop.name
            status = .connected(shop.name)
            return true
        } catch {
            status = .failed(error.localizedDescription)
            return false
        }
    }

    private func disconnect() {
        try? ShopifyCredentials.remove()
        shopName = ""
        status = .idle
        missingScopes = []
        Task { await storeSync.refresh(in: modelContext) }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Passo a passo para criar o app no Dev Dashboard da Shopify.
private struct StoreConnectionGuide: View {
    var body: some View {
        DisclosureGroup("Como obter as credenciais") {
            VStack(alignment: .leading, spacing: 8) {
                step(1, "No admin da Shopify, abre Definições › Apps › Desenvolver apps e escolhe Criar app no Dev Dashboard.")
                step(2, "Cria um app chamado “Mynik”.")
                step(3, "Na versão do app, em Admin API, escolhe só leitura: \(ShopifyCredentials.requiredScopes.joined(separator: ", ")). Lança a versão.")
                step(4, "Instala o app na tua loja.")
                step(5, "Em Definições do app, copia o Client ID e o Client secret e cola-os aqui.")
                Text("Tens um app antigo criado no admin? Escolhe “Token antigo” e cola o token shpat_.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).").monospacedDigit().foregroundStyle(.secondary)
            Text(text)
        }
        .font(.callout)
    }
}

#Preview(traits: .sampleData) {
    Form {
        StoreSettingsSection()
    }
    .formStyle(.grouped)
}
