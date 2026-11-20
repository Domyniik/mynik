import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Mynik

@MainActor
struct NoteTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }

    @Test func newNoteStartsWithEmptyTextBlock() {
        let note = NoteEditing.makeNote(title: "Diário", in: context)
        #expect(note.sortedBlocks.map(\.kind) == [.text])
        #expect(note.displayTitle == "Diário")
        #expect(Note().displayTitle == "Sem título")
    }

    @Test func insertsMovesAndDeletesBlocksKeepingOrder() {
        let note = NoteEditing.makeNote(in: context)
        let first = note.sortedBlocks[0]
        first.text = "A"
        let last = NoteEditing.insertBlock(.text, text: "C", in: note, context: context)
        NoteEditing.insertBlock(.heading, text: "B", after: first, in: note, context: context)
        #expect(note.sortedBlocks.map(\.text) == ["A", "B", "C"])
        #expect(note.sortedBlocks.map(\.sortOrder) == [0, 1, 2])

        NoteEditing.moveBlock(last, by: -1, in: note)
        #expect(note.sortedBlocks.map(\.text) == ["A", "C", "B"])
        NoteEditing.moveBlock(first, by: -1, in: note)
        #expect(note.sortedBlocks.map(\.text) == ["A", "C", "B"], "O primeiro bloco não sobe mais")

        NoteEditing.moveBlocks(in: note, from: IndexSet(integer: 2), to: 0)
        #expect(note.sortedBlocks.map(\.text) == ["B", "A", "C"])

        NoteEditing.deleteBlock(first, from: note, context: context)
        #expect(note.sortedBlocks.map(\.text) == ["B", "C"])
        #expect(note.sortedBlocks.map(\.sortOrder) == [0, 1])
    }

    @Test func convertsOnlyTextualBlocks() {
        let note = NoteEditing.makeNote(in: context)
        let block = NoteEditing.insertBlock(.checklist, text: "Comprar pão", in: note, context: context)
        block.isChecked = true
        NoteEditing.convert(block, to: .heading)
        #expect(block.kind == .heading)
        #expect(!block.isChecked)

        let image = NoteEditing.insertBlock(.image, imageData: Data([1, 2, 3]), in: note, context: context)
        NoteEditing.convert(image, to: .text)
        #expect(image.kind == .image)
    }

    @Test func nestedPagesAndCascadeDelete() throws {
        let root = NoteEditing.makeNote(title: "Casa", in: context)
        let child = NoteEditing.makeNote(title: "Obras", parent: root, in: context)
        let grandchild = NoteEditing.makeNote(title: "Cozinha", parent: child, in: context)
        let sibling = NoteEditing.makeNote(title: "Jardim", parent: root, in: context)
        try context.save()

        #expect(grandchild.ancestors.map(\.title) == ["Casa", "Obras"])
        #expect(root.sortedChildren.map(\.title) == ["Obras", "Jardim"])
        #expect(sibling.sortOrder == 1)
        #expect(grandchild.childrenOrNil == nil)

        context.delete(root)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<NoteBlock>()) == 0)
    }

    @Test func searchesTitlesAndBlockText() {
        let recipe = NoteEditing.makeNote(title: "Receitas", in: context)
        recipe.sortedBlocks[0].text = "Bacalhau à Brás"
        let trip = NoteEditing.makeNote(title: "Viagem a Lisboa", in: context)

        #expect(NoteSearch.filter([recipe, trip], matching: "bras").map(\.title) == ["Receitas"])
        #expect(NoteSearch.filter([recipe, trip], matching: "lisboa").map(\.title) == ["Viagem a Lisboa"])
        #expect(NoteSearch.filter([recipe, trip], matching: " ").count == 2)
    }

    @Test func downsamplesLargeImagesToJPEG() throws {
        let png = try #require(Self.makePNG(width: 3200, height: 1600))
        let jpeg = try #require(ImageDownsampler.jpegData(from: png))
        let image = try #require(ImageDownsampler.cgImage(from: jpeg, maxPixelSize: 5000))
        #expect(image.width == 1600)
        #expect(image.height == 800)
        #expect(ImageDownsampler.jpegData(from: Data("não é imagem".utf8)) == nil)
    }

    private static func makePNG(width: Int, height: Int) -> Data? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
