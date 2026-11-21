import Foundation

/// Valor JSON qualquer, com os números guardados como `Decimal`.
///
/// Serve para pôr o registo dentro da linha enviada ao Supabase (coluna `jsonb`)
/// e tirá-lo de lá sem passar por `Double`, que arredondaria os valores em euros.
nonisolated enum RawJSON: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Decimal)
    case string(String)
    case array([RawJSON])
    case object([String: RawJSON])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([RawJSON].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: RawJSON].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(RawJSON.self, from: data)
    }

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
