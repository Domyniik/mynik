import Foundation
import SwiftData
import Testing
@testable import Mynik

/// ZIP sem compressão para os testes (o leitor não valida o CRC).
private func storedZip(_ files: [(String, Data)]) -> Data {
    func le16(_ value: Int) -> Data { withUnsafeBytes(of: UInt16(value).littleEndian) { Data($0) } }
    func le32(_ value: Int) -> Data { withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) } }
    var body = Data()
    var directory = Data()
    for (name, content) in files {
        let nameData = Data(name.utf8)
        let offset = body.count
        body += le32(0x0403_4b50) + le16(20) + le16(0x800) + le16(0) + le16(0) + le16(0) + le32(0)
        body += le32(content.count) + le32(content.count) + le16(nameData.count) + le16(0) + nameData + content
        directory += le32(0x0201_4b50) + le16(20) + le16(20) + le16(0x800) + le16(0) + le16(0) + le16(0) + le32(0)
        directory += le32(content.count) + le32(content.count) + le16(nameData.count) + le16(0) + le16(0)
        directory += le16(0) + le16(0) + le32(0) + le32(offset) + nameData
    }
    let end = le32(0x0605_4b50) + le16(0) + le16(0) + le16(files.count) + le16(files.count)
        + le32(directory.count) + le32(body.count) + le16(0)
    return body + directory + end
}

@MainActor
struct NotionImportTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
    }

    static let id1 = "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d"
    static let id2 = "abcdefabcdefabcdefabcdefabcdef12"
    static let id3 = "0123456789abcdef0123456789abcdef"

    static var export: [(String, Data)] {
        let page = """
        # Viagem Japão

        Plano para **abril**. Ver [Livros](Viagem%20Japão%20\(id1)/Livros%20\(id2).csv).

        ## Lista
        - [ ] Passaporte
        - [x] Voos

        ```swift
        print("olá")
        ```

        ![Mapa](Viagem%20Japão%20\(id1)/mapa.png)
        ![Web](https://exemplo.pt/foto.jpg)
        """
        let csv = "\u{FEFF}Name,Estado,Páginas,Lido,Data\nDuna,Lido,600,Yes,\"November 21, 2026\"\nSapiens,Para ler,450,No,\nDuna 2,Lido,,No,2026/12/01\n"
        let row = """
        # Duna

        Estado: Lido
        Páginas: 600

        Muito bom.
        """
        return [
            ("Export-xyz/Viagem Japão \(id1).md", Data(page.utf8)),
            ("Export-xyz/Viagem Japão \(id1)/Livros \(id2).csv", Data(csv.utf8)),
            ("Export-xyz/Viagem Japão \(id1)/Livros \(id2)/Duna \(id3).md", Data(row.utf8)),
            ("Export-xyz/Viagem Japão \(id1)/mapa.png", pngData()),
            ("__MACOSX/lixo.md", Data("x".utf8)),
        ]
    }

    static func pngData() -> Data {
        // PNG 1×1 válido.
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
    }

    @Test func readsStoredZip() throws {
        let zip = try ZipReader(data: storedZip([("a.txt", Data("olá".utf8)), ("pasta/", Data())]))
        #expect(zip.entries.map(\.path) == ["a.txt", "pasta/"])
        #expect(try zip.contents(of: zip.entries[0]) == Data("olá".utf8))
        #expect(throws: ZipReader.ZipError.notAZip) { try ZipReader(data: Data("nada".utf8)) }
    }

    #if os(macOS)
    @Test func readsDeflatedZipMadeBySystemTool() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "zip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let text = String(repeating: "Notas ao estilo wiki. ", count: 500)
        try Data(text.utf8).write(to: folder.appending(path: "nota.md"))
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-q", "export.zip", "nota.md"]
        try process.run()
        process.waitUntilExit()

        let zip = try ZipReader(data: Data(contentsOf: folder.appending(path: "export.zip")))
        let entry = try #require(zip.entries.first)
        #expect(entry.method == 8)
        #expect(String(data: try zip.contents(of: entry), encoding: .utf8) == text)
    }
    #endif

    @Test func pureHelpers() {
        #expect(NotionImporter.cleanName("Plano \(Self.id1)") == "Plano")
        #expect(NotionImporter.cleanName("Sem id") == "Sem id")
        #expect(NotionImporter.convertPageLinks("Ver [Doc](Doc%20\(Self.id1).md) e ![i](a.png)") == "Ver [[Doc]] e ![i](a.png)")
        #expect(NotionImporter.resolve("../img%201.png", relativeTo: "A/B") == "A/img 1.png")
        #expect(NotionImporter.parseDate("November 21, 2026 → November 23, 2026") != nil)
        #expect(NotionImporter.parseDate("ontem") == nil)
        #expect(NotionImporter.inferProperty(named: "X", values: ["Yes", "No", ""]).type == .checkbox)
        #expect(NotionImporter.inferProperty(named: "X", values: ["1", "2,5"]).type == .number)
        #expect(NotionImporter.inferProperty(named: "X", values: ["A", "B", "A"]).options == ["A", "B"])
        #expect(NotionImporter.inferProperty(named: "X", values: (1...20).map { "Frase longa número \($0)" }).type == .text)
    }

    @Test func importsPagesDatabasesRowsAndImages() throws {
        let files = try NotionImporter.readFiles(fromZip: storedZip(Self.export))
        #expect(files.texts.count == 3)
        #expect(files.images.count == 1)

        let root = NoteEditing.makeNote(title: "Importado", in: context)
        let summary = try NotionImporter.importFiles(files, into: context, parent: root)
        #expect(summary == .init(pages: 2, databases: 1, rows: 3, images: 1))

        let page = try #require(root.sortedChildren.first)
        #expect(page.title == "Viagem Japão")
        let kinds = page.sortedBlocks.map(\.kind)
        #expect(kinds.contains(.heading2) && kinds.contains(.checklist) && kinds.contains(.code) && kinds.contains(.image))
        #expect(page.plainText.contains("[[Livros]]"))
        #expect(page.plainText.contains("https://exemplo.pt/foto.jpg"))

        let database = try #require(page.sortedChildren.first)
        #expect(database.isDatabase && database.title == "Livros")
        #expect(database.databaseProperties.map(\.type) == [.select, .number, .checkbox, .date])
        let rows = database.sortedChildren
        #expect(rows.map(\.title) == ["Duna", "Sapiens", "Duna 2"])
        let duna = rows[0]
        #expect(duna.plainText.contains("Muito bom."))
        #expect(!duna.plainText.contains("Estado:"))
        let date = try #require(NoteDatabase.dateProperty(of: database))
        #expect(duna.value(for: date) == "2026-11-21")
        let read = database.databaseProperties[2]
        #expect(duna.value(for: read) == "true" && rows[1].value(for: read).isEmpty)
    }

    @Test func emptyZipIsRejected() throws {
        let files = try NotionImporter.readFiles(fromZip: storedZip([("x.txt", Data("a".utf8))]))
        #expect(throws: NotionImporter.ImportError.self) { try NotionImporter.importFiles(files, into: context) }
    }
}
