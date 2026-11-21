import Auth
import Foundation
import PostgREST

/// Tabela `records` do Supabase como `SyncRemote` (ver supabase/migrations).
nonisolated struct SupabaseSyncRemote: SyncRemote {
    static let table = "records"
    /// Linhas por pedido no pull (o PostgREST devolve no máximo 1000).
    static let pageSize = 1000
    /// Limite aproximado de cada pedido de push (as notas podem levar imagens).
    static let maxPushBytes = 2_000_000

    let config: SupabaseConfig
    let auth: AuthClient

    func pull(since: Date?) async throws -> [SyncRow] {
        let client = try await makeClient()
        let userID = try await auth.session.user.id.uuidString.lowercased()
        var rows: [SyncRow] = []
        var offset = 0
        while true {
            var query = client.from(Self.table)
                .select("entity,key,payload,deleted,modified_at,updated_at")
                .eq("user_id", value: userID)
            if let since {
                query = query.gte("updated_at", value: PostgresTimestamp.string(from: since))
            }
            let response = try await query
                .order("updated_at")
                .order("entity")
                .order("key")
                .range(from: offset, to: offset + Self.pageSize - 1)
                .execute()
            let page = try JSONDecoder().decode([RemoteRow].self, from: response.data)
            rows += try page.map { try $0.syncRow() }
            guard page.count == Self.pageSize else { return rows }
            offset += Self.pageSize
        }
    }

    func push(_ rows: [SyncRow]) async throws {
        let client = try await makeClient()
        let userID = try await auth.session.user.id.uuidString.lowercased()
        var batch: [RemoteRow] = []
        var batchBytes = 0
        for row in rows {
            let remote = try RemoteRow(row, userID: userID)
            let size = row.payload?.count ?? 0
            if !batch.isEmpty, batchBytes + size > Self.maxPushBytes || batch.count >= 500 {
                try await upsert(batch, with: client)
                batch.removeAll()
                batchBytes = 0
            }
            batch.append(remote)
            batchBytes += size
        }
        if !batch.isEmpty { try await upsert(batch, with: client) }
    }

    private func upsert(_ batch: [RemoteRow], with client: PostgrestClient) async throws {
        try await client.from(Self.table)
            .upsert(batch, onConflict: "user_id,entity,key", returning: .minimal)
            .execute()
    }

    private func makeClient() async throws -> PostgrestClient {
        let token = try await auth.session.accessToken
        return PostgrestClient(
            url: config.restURL,
            headers: ["apikey": config.anonKey, "Authorization": "Bearer \(token)"]
        )
    }
}

/// Linha como o PostgREST a lê e escreve.
private nonisolated struct RemoteRow: Codable, Sendable {
    var user_id: String?
    var entity: String
    var key: String
    var payload: RawJSON?
    var deleted: Bool
    var modified_at: String
    var updated_at: String?

    init(_ row: SyncRow, userID: String) throws {
        user_id = userID
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

    // Só se envia o que a tabela aceita: o `updated_at` é sempre do servidor.
    enum CodingKeys: String, CodingKey {
        case user_id, entity, key, payload, deleted, modified_at, updated_at
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(user_id, forKey: .user_id)
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
