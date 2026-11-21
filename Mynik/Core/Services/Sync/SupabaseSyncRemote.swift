import Auth
import Foundation
import PostgREST

/// Tabelas tipadas do Supabase como `SyncRemote`, pelas funções `sync_pull` e
/// `sync_push` (ver supabase/migrations). O servidor converte os registos da
/// cópia de segurança nas colunas de cada tabela, que a app web usa diretamente.
nonisolated struct SupabaseSyncRemote: SyncRemote {
    /// Linhas por pedido no pull (o PostgREST devolve no máximo 1000).
    static let pageSize = 1000
    /// Limite aproximado de cada pedido de push (as notas podem levar imagens).
    static let maxPushBytes = 2_000_000

    let config: SupabaseConfig
    let auth: AuthClient

    private struct PullParams: Encodable {
        var p_since: String?
        var p_limit: Int
        var p_offset: Int
    }

    private struct PushParams: Encodable {
        var p_rows: [RemoteRow]
    }

    func pull(since: Date?) async throws -> [SyncRow] {
        let client = try await makeClient()
        var rows: [SyncRow] = []
        var offset = 0
        while true {
            let params = PullParams(
                p_since: since.map(PostgresTimestamp.string(from:)),
                p_limit: Self.pageSize,
                p_offset: offset
            )
            let response = try await client.rpc("sync_pull", params: params).execute()
            let page = try JSONDecoder().decode([RemoteRow].self, from: response.data)
            rows += try page.map { try $0.syncRow() }
            guard page.count == Self.pageSize else { return rows }
            offset += Self.pageSize
        }
    }

    func push(_ rows: [SyncRow]) async throws {
        let client = try await makeClient()
        var batch: [RemoteRow] = []
        var batchBytes = 0
        for row in rows {
            let remote = try RemoteRow(row)
            let size = row.payload?.count ?? 0
            if !batch.isEmpty, batchBytes + size > Self.maxPushBytes || batch.count >= 500 {
                try await send(batch, with: client)
                batch.removeAll()
                batchBytes = 0
            }
            batch.append(remote)
            batchBytes += size
        }
        if !batch.isEmpty { try await send(batch, with: client) }
    }

    private func send(_ batch: [RemoteRow], with client: PostgrestClient) async throws {
        try await client.rpc("sync_push", params: PushParams(p_rows: batch)).execute()
    }

    private func makeClient() async throws -> PostgrestClient {
        let token = try await auth.session.accessToken
        return PostgrestClient(
            url: config.restURL,
            headers: ["apikey": config.anonKey, "Authorization": "Bearer \(token)"],
            logger: nil
        )
    }
}

/// Linha no formato de `sync_pull` / `sync_push`.
private nonisolated struct RemoteRow: Codable, Sendable {
    var entity: String
    var key: String
    var payload: RawJSON?
    var deleted: Bool
    var modified_at: String
    var updated_at: String?

    init(_ row: SyncRow) throws {
        entity = row.entity
        key = row.key
        payload = try row.payload.map(RawJSON.init(data:))
        deleted = row.deleted
        modified_at = PostgresTimestamp.string(from: row.modifiedAt)
    }

    func syncRow() throws -> SyncRow {
        guard let modified = PostgresTimestamp.date(from: modified_at) else {
            throw URLError(.cannotParseResponse)
        }
        let payloadData: Data? = switch payload {
        case .none, .null?: nil
        case let value?: try value.data()
        }
        return SyncRow(
            entity: entity, key: key, payload: payloadData,
            modifiedAt: modified, updatedAt: updated_at.flatMap(PostgresTimestamp.date(from:)),
            deleted: deleted
        )
    }

    // O `updated_at` é sempre do servidor: não se envia.
    enum CodingKeys: String, CodingKey {
        case entity, key, payload, deleted, modified_at, updated_at
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entity, forKey: .entity)
        try c.encode(key, forKey: .key)
        try c.encode(payload ?? .null, forKey: .payload)
        try c.encode(deleted, forKey: .deleted)
        try c.encode(modified_at, forKey: .modified_at)
    }
}

/// Datas `timestamptz` do Postgres (`2026-11-21T15:07:38.123456+00:00`).
nonisolated enum PostgresTimestamp {
    static func string(from date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt))
    }

    static func date(from string: String) -> Date? {
        // Separa as frações de segundo (o Postgres manda até 6 casas).
        var base = string
        var fraction = 0.0
        if let dot = string.firstIndex(of: ".") {
            let rest = string[string.index(after: dot)...]
            let digits = rest.prefix(while: \.isNumber)
            fraction = Double("0." + digits) ?? 0
            base = String(string[..<dot]) + rest.dropFirst(digits.count)
        }
        if base.hasSuffix("+00") { base += ":00" }
        guard let whole = try? Date(base, strategy: .iso8601) else { return nil }
        return whole.addingTimeInterval(fraction)
    }
}
