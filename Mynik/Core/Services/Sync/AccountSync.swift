import Auth
import Foundation
import Observation
import SwiftData

/// Conta Supabase opcional e sync automático entre o Mac e o iPhone.
///
/// Sem configuração, sem conta ou sem rede a app funciona igual: o SwiftData é
/// a fonte e o Supabase só guarda uma cópia. O sync corre ao abrir a app, ao
/// voltar ao primeiro plano e alguns segundos depois de cada gravação.
@MainActor
@Observable
final class AccountSync {
    /// Espera depois de uma gravação antes de sincronizar (junta várias alterações).
    static let debounce: Duration = .seconds(3)

    let isConfigured: Bool
    private(set) var email: String?
    private(set) var userID: String?
    private(set) var isSyncing = false
    private(set) var lastSyncAt: Date?
    private(set) var lastReport: SyncReport?
    private(set) var lastError: String?

    var isSignedIn: Bool { userID != nil }

    @ObservationIgnored private let auth: AuthClient?
    @ObservationIgnored private let engine: SyncEngine?
    @ObservationIgnored private let stateStore: SyncStateStore
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false

    init(config: SupabaseConfig? = AccountSync.defaultConfig, stateStore: SyncStateStore = .standard) {
        self.stateStore = stateStore
        lastSyncAt = stateStore.load().lastSyncAt
        guard let config else {
            isConfigured = false
            auth = nil
            engine = nil
            return
        }
        let auth = AuthClient(
            url: config.authURL,
            headers: ["apikey": config.anonKey],
            flowType: .implicit,
            localStorage: KeychainAuthStorage(),
            emitLocalSessionAsInitialSession: true
        )
        self.auth = auth
        engine = SyncEngine(remote: SupabaseSyncRemote(config: config, auth: auth), store: stateStore)
        isConfigured = true
    }

    /// Sem sync nos testes e no modo de demonstração.
    static var defaultConfig: SupabaseConfig? {
        AppEnvironment.isRunningTests || AppEnvironment.isDemo ? nil : .fromBundle
    }

    // MARK: - Sessão

    /// Lê a sessão guardada no Keychain (uma vez, ao abrir a app).
    func start() {
        guard !hasStarted, let session = auth?.currentSession else { return }
        hasStarted = true
        apply(session.user)
    }

    /// Envia o código de 6 dígitos para o email (cria a conta se não existir).
    func sendCode(to email: String) async throws {
        guard let auth else { return }
        try await auth.signInWithOTP(email: email.trimmingCharacters(in: .whitespaces).lowercased())
    }

    func verify(email: String, code: String) async throws {
        guard let auth else { return }
        let response = try await auth.verifyOTP(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            token: code.filter(\.isNumber),
            type: .email
        )
        apply(response.user)
    }

    /// Termina a sessão. Os dados ficam no dispositivo; o próximo login volta a juntá-los.
    func signOut() async {
        debounceTask?.cancel()
        try? await auth?.signOut(scope: .local)
        stateStore.reset()
        email = nil
        userID = nil
        lastSyncAt = nil
        lastReport = nil
        lastError = nil
    }

    private func apply(_ user: User) {
        email = user.email
        userID = user.id.uuidString.lowercased()
    }

    // MARK: - Sync

    func sync(context: ModelContext) async {
        guard let engine, let userID, !isSyncing else { return }
        debounceTask?.cancel()
        isSyncing = true
        defer { isSyncing = false }
        do {
            lastReport = try await engine.sync(context: context, userID: userID)
            lastSyncAt = .now
            lastError = nil
        } catch {
            if case AuthError.sessionMissing = error { await signOut() }
            lastError = Self.message(for: error)
        }
    }

    /// Sync alguns segundos depois de gravar. Ignora as gravações do próprio sync.
    func scheduleSync(context: ModelContext) {
        guard isSignedIn, !isSyncing else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.sync(context: context)
        }
    }

    private static func message(for error: any Error) -> String {
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code) {
            return "Sem ligação. Os dados ficam guardados aqui e sincronizam quando houver rede."
        }
        return error.localizedDescription
    }
}
