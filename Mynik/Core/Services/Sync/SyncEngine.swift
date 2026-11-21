import Foundation
import SwiftData

/// Resultado de um sync.
nonisolated struct SyncReport: Equatable, Sendable {
    var pushed = 0
    var pulled = 0
    var deletedLocally = 0
}

/// Sincroniza o SwiftData com um `SyncRemote`.
///
/// O SwiftData é a fonte da app; o servidor guarda uma cópia de cada registo.
/// Os modelos não têm data de alteração, por isso as alterações locais
/// descobrem-se comparando o hash de cada registo com o do último sync.
///
/// Regras:
/// - **last-write-wins** por registo, pela hora da alteração (`modifiedAt`);
/// - apagar envia um **tombstone** (`deleted = true`), que apaga nos outros dispositivos;
/// - no primeiro sync de um dispositivo, o servidor ganha nos registos que já lá estão.
@MainActor
final class SyncEngine {
    /// Margem do pull incremental, para não perder linhas gravadas ao mesmo tempo.
    static let pullOverlap: TimeInterval = 5

    private let remote: any SyncRemote
    private let store: SyncStateStore

    init(remote: any SyncRemote, store: SyncStateStore) {
        self.remote = remote
        self.store = store
    }

    @discardableResult
    func sync(context: ModelContext, userID: String, now: Date = .now) async throws -> SyncReport {
        var state = store.load()
        if state.userID != userID {
            state = SyncState(userID: userID)
        }
        // No primeiro sync os registos locais contam como antigos: o que já está no servidor ganha.
        let localTime = state.isFirstSync ? Date(timeIntervalSince1970: 0) : now
        var report = SyncReport()

        // 1. Alterações locais desde o último sync.
        var local = try Self.snapshot(context)
        Self.markLocalChanges(local, in: &state, at: localTime)

        // 2. Pull: aplica o que veio do servidor, exceto onde a alteração local é mais recente.
        let rows = try await remote.pull(since: state.cursor.map { $0.addingTimeInterval(-Self.pullOverlap) })
        var incoming = BackupArchive()
        var deletions: [SyncEntity: Set<String>] = [:]
        var applied: Set<String> = []
        var maxUpdatedAt = state.cursor

        for row in rows {
            if let updatedAt = row.updatedAt, updatedAt > (maxUpdatedAt ?? .distantPast) {
                maxUpdatedAt = updatedAt
            }
            guard let entity = SyncEntity(rawValue: row.entity) else { continue }
            let stateKey = SyncState.key(entity, row.key)
            let entry = state.entries[stateKey]
            if let entry, entry.dirty, entry.modifiedAt > row.modifiedAt { continue }

            if row.deleted {
                if local[stateKey] != nil {
                    deletions[entity, default: []].insert(row.key)
                    report.deletedLocally += 1
                }
                state.entries[stateKey] = .init(hash: nil, modifiedAt: row.modifiedAt, dirty: false)
            } else if let payload = row.payload {
                // Registo de uma versão mais recente da app que não se consegue ler: fica para depois.
                var scratch = BackupArchive()
                guard let canonical = try? entity.append(payload, to: &scratch) else { continue }
                let hash = SyncState.hash(canonical)
                if local[stateKey]?.hash != hash {
                    try entity.append(payload, to: &incoming)
                    applied.insert(stateKey)
                    report.pulled += 1
                }
                state.entries[stateKey] = .init(hash: hash, modifiedAt: row.modifiedAt, dirty: false)
            }
        }

        if !applied.isEmpty || !deletions.isEmpty {
            if !applied.isEmpty {
                try BackupService.importArchive(incoming, into: context)
            }
            for (entity, keys) in deletions {
                try entity.deleteModels(withKeys: keys, in: context)
            }
            try context.save()

            // O registo aplicado pode diferir do recebido (uma relação para algo que
            // não existe aqui, por exemplo): guarda o hash local para não o reenviar.
            local = try Self.snapshot(context)
            for stateKey in applied {
                if let hash = local[stateKey]?.hash { state.entries[stateKey]?.hash = hash }
            }
            // Apagados em cascata ou juntados por nome (categorias iniciais) passam a tombstones.
            Self.markLocalChanges(local, in: &state, at: localTime)
        }

        // 3. Push do que ficou por enviar.
        let dirty = state.entries.filter(\.value.dirty)
        let outgoing: [SyncRow] = dirty.compactMap { stateKey, entry in
            guard let (entity, key) = SyncState.split(stateKey) else { return nil }
            return SyncRow(
                entity: entity.rawValue, key: key,
                payload: entry.hash == nil ? nil : local[stateKey]?.data,
                modifiedAt: entry.modifiedAt, updatedAt: nil, deleted: entry.hash == nil
            )
        }
        if !outgoing.isEmpty {
            try await remote.push(outgoing)
            for stateKey in dirty.keys { state.entries[stateKey]?.dirty = false }
            report.pushed = outgoing.count
        }

        state.cursor = maxUpdatedAt
        state.lastSyncAt = now
        try store.save(state)
        return report
    }

    // MARK: - Passos

    nonisolated struct LocalRecord: Equatable, Sendable {
        var data: Data
        var hash: String
    }

    /// Todos os registos sincronizáveis, indexados por `SyncState.key`.
    static func snapshot(_ context: ModelContext) throws -> [String: LocalRecord] {
        let archive = try BackupService.makeArchive(from: context, includingDocumentPhotos: false)
        var result: [String: LocalRecord] = [:]
        for entity in SyncEntity.allCases {
            for (key, data) in try entity.payloads(in: archive) {
                result[SyncState.key(entity, key)] = LocalRecord(data: data, hash: SyncState.hash(data))
            }
        }
        return result
    }

    /// Marca como por enviar o que é novo, mudou ou desapareceu desde o último sync.
    nonisolated static func markLocalChanges(_ local: [String: LocalRecord], in state: inout SyncState, at time: Date) {
        for (stateKey, record) in local where state.entries[stateKey]?.hash != record.hash {
            state.entries[stateKey] = .init(hash: record.hash, modifiedAt: time, dirty: true)
        }
        for (stateKey, entry) in state.entries where entry.hash != nil && local[stateKey] == nil {
            state.entries[stateKey] = .init(hash: nil, modifiedAt: time, dirty: true)
        }
    }
}
