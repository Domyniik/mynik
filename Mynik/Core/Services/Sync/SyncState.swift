import CryptoKit
import Foundation

/// Um registo como viaja de e para o Supabase (`sync_push` / `sync_pull`).
nonisolated struct SyncRow: Equatable, Sendable {
    var entity: String
    var key: String
    /// Registo em JSON (`nil` nos tombstones).
    var payload: Data?
    /// Hora da alteração no dispositivo: decide o last-write-wins.
    var modifiedAt: Date
    /// Hora em que o servidor recebeu a linha: cursor do pull incremental.
    var updatedAt: Date?
    var deleted: Bool
}

/// Servidor de sync (o Supabase na app; um falso nos testes).
nonisolated protocol SyncRemote: Sendable {
    /// Linhas alteradas no servidor desde `since` (todas, se `nil`), de qualquer dispositivo.
    func pull(since: Date?) async throws -> [SyncRow]
    /// Grava as linhas; o servidor ignora as que forem mais antigas do que as que já tem.
    func push(_ rows: [SyncRow]) async throws
}

/// O que este dispositivo sabe de cada registo desde o último sync.
nonisolated struct SyncState: Codable, Equatable, Sendable {
    nonisolated struct Entry: Codable, Equatable, Sendable {
        /// Hash do registo como ficou depois do último sync (`nil`: apagado).
        var hash: String?
        /// Hora da última alteração conhecida (local ou do servidor).
        var modifiedAt: Date
        /// Alterado aqui e ainda por enviar.
        var dirty: Bool
    }

    /// Conta a que este estado pertence (outra conta recomeça do zero).
    var userID: String?
    /// Maior `updatedAt` do servidor já recebido.
    var cursor: Date?
    var lastSyncAt: Date?
    /// Indexado por `SyncState.key(entity, key)`.
    var entries: [String: Entry] = [:]

    var isFirstSync: Bool { cursor == nil && entries.isEmpty }

    static func key(_ entity: SyncEntity, _ key: String) -> String { "\(entity.rawValue)/\(key)" }

    static func split(_ stateKey: String) -> (SyncEntity, String)? {
        guard let slash = stateKey.firstIndex(of: "/"),
              let entity = SyncEntity(rawValue: String(stateKey[..<slash]))
        else { return nil }
        return (entity, String(stateKey[stateKey.index(after: slash)...]))
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Guarda o `SyncState` num ficheiro JSON em Application Support.
nonisolated struct SyncStateStore: Sendable {
    let url: URL

    static var standard: SyncStateStore {
        let folder = URL.applicationSupportDirectory.appending(path: "Mynik", directoryHint: .isDirectory)
        return SyncStateStore(url: folder.appending(path: "sync-state.json"))
    }

    func load() -> SyncState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SyncState.self, from: data)
        else { return SyncState() }
        return state
    }

    func save(_ state: SyncState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }

    func reset() {
        try? FileManager.default.removeItem(at: url)
    }
}
