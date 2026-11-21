import Compression
import Foundation

/// Leitor mínimo de ficheiros ZIP (sem dependências): lê o diretório central e
/// extrai entradas guardadas sem compressão (0) ou com deflate (8).
/// Não suporta ZIP64 nem cifra, que um export de notas não usa.
nonisolated struct ZipReader {
    enum ZipError: LocalizedError, Equatable {
        case notAZip
        case unsupported(String)
        case corrupted(String)
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .notAZip: "O ficheiro não é um ZIP."
            case .unsupported(let name): "Formato não suportado em \(name)."
            case .corrupted(let name): "O ZIP está danificado (\(name))."
            case .tooLarge: "O ZIP é demasiado grande para importar."
            }
        }
    }

    struct Entry: Equatable, Sendable {
        var path: String
        var method: UInt16
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
        var isDirectory: Bool { path.hasSuffix("/") }
    }

    /// Limite total descomprimido (proteção contra "ZIP bombs").
    static let maxTotalSize = 1_000_000_000

    let data: Data
    let entries: [Entry]

    init(data: Data) throws {
        self.data = data
        self.entries = try Self.readCentralDirectory(data)
        guard entries.reduce(0, { $0 + $1.uncompressedSize }) <= Self.maxTotalSize else { throw ZipError.tooLarge }
    }

    /// Conteúdo de uma entrada.
    func contents(of entry: Entry) throws -> Data {
        let offset = entry.localHeaderOffset
        guard data.uint32(at: offset) == 0x0403_4b50 else { throw ZipError.corrupted(entry.path) }
        let nameLength = Int(data.uint16(at: offset + 26))
        let extraLength = Int(data.uint16(at: offset + 28))
        let start = offset + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else { throw ZipError.corrupted(entry.path) }
        let compressed = data.subdata(in: start..<(start + entry.compressedSize))
        switch entry.method {
        case 0:
            return compressed
        case 8:
            return try Self.inflate(compressed, expectedSize: entry.uncompressedSize, name: entry.path)
        default:
            throw ZipError.unsupported(entry.path)
        }
    }

    // MARK: Diretório central

    private static func readCentralDirectory(_ data: Data) throws -> [Entry] {
        // Fim do diretório central: assinatura nos últimos 22 + 65535 bytes.
        guard data.count >= 22 else { throw ZipError.notAZip }
        let lowerBound = max(0, data.count - 22 - 65_535)
        var eocd: Int?
        var index = data.count - 22
        while index >= lowerBound {
            if data.uint32(at: index) == 0x0605_4b50 { eocd = index; break }
            index -= 1
        }
        guard let eocd else { throw ZipError.notAZip }
        let count = Int(data.uint16(at: eocd + 10))
        let directoryOffset = Int(data.uint32(at: eocd + 16))
        guard directoryOffset != 0xFFFF_FFFF else { throw ZipError.unsupported("ZIP64") }

        var entries: [Entry] = []
        var cursor = directoryOffset
        for _ in 0..<count {
            guard cursor + 46 <= data.count, data.uint32(at: cursor) == 0x0201_4b50 else {
                throw ZipError.corrupted("diretório central")
            }
            let flags = data.uint16(at: cursor + 8)
            let method = data.uint16(at: cursor + 10)
            let compressed = Int(data.uint32(at: cursor + 20))
            let uncompressed = Int(data.uint32(at: cursor + 24))
            let nameLength = Int(data.uint16(at: cursor + 28))
            let extraLength = Int(data.uint16(at: cursor + 30))
            let commentLength = Int(data.uint16(at: cursor + 32))
            let localOffset = Int(data.uint32(at: cursor + 42))
            guard cursor + 46 + nameLength <= data.count else { throw ZipError.corrupted("nome") }
            let nameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength))
            // Bit 11: nome em UTF-8; senão CP437 (aproximado por Latin-1).
            let name = (flags & 0x800 != 0 ? String(data: nameData, encoding: .utf8) : nil)
                ?? String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1) ?? ""
            if flags & 0x1 != 0 { throw ZipError.unsupported(name) }
            entries.append(Entry(path: name, method: method, compressedSize: compressed,
                                 uncompressedSize: uncompressed, localHeaderOffset: localOffset))
            cursor += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func inflate(_ data: Data, expectedSize: Int, name: String) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                    source.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { throw ZipError.corrupted(name) }
        return output
    }
}

private extension Data {
    nonisolated func uint16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[startIndex + offset]) | UInt16(self[startIndex + offset + 1]) << 8
    }

    nonisolated func uint32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(self[startIndex + offset + $1]) << (8 * $1) }
    }
}
