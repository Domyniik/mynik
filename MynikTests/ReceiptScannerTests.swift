import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mynik

struct ReceiptParserTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    @Test func parsesSpanishSupermarketTicket() throws {
        let lines = [
            "MERCADONA, S.A.",
            "C/ Gran Vía 12, Madrid",
            "CIF A-46103834",
            "FACTURA SIMPLIFICADA 2311-014-123456",
            "Fecha: 14/11/2026 18:42",
            "LECHE ENTERA 6X1L     5,34",
            "PAN BARRA             0,65",
            "BASE IMPONIBLE       21,00",
            "IVA 10%               2,10",
            "TOTAL (€)            23,10",
            "TARJETA BANCARIA     23,10",
        ]
        let result = ReceiptParser.parse(lines: lines, calendar: calendar)
        #expect(result.merchant == "Mercadona, S.A.")
        #expect(result.amount == Decimal(string: "23.10"))
        #expect(result.currencyCode == "EUR")
        let date = try #require(result.date)
        #expect(calendar.dateComponents([.day, .month, .year], from: date) == DateComponents(year: 2026, month: 11, day: 14))
    }

    @Test func totalOnTheNextLine() {
        let lines = ["Restaurante O Tasco", "Total a pagar", "1.234,56 €", "Obrigado"]
        #expect(ReceiptParser.total(in: lines) == Decimal(string: "1234.56"))
    }

    @Test func ignoresSubtotalAndChange() {
        let lines = ["Subtotal 10,00", "Total 12,10", "Entregado 20,00", "Cambio 7,90"]
        #expect(ReceiptParser.total(in: lines) == Decimal(string: "12.10"))
    }

    @Test func fallsBackToLargestAmount() {
        #expect(ReceiptParser.total(in: ["Café 1,20", "Tosta 3,50"]) == Decimal(string: "3.50"))
        #expect(ReceiptParser.total(in: ["Sem valores"]) == nil)
    }

    @Test(arguments: [
        ("2026-03-05", 2026, 3, 5),
        ("05/03/26", 2026, 3, 5),
        ("Data 5.3.2026", 2026, 3, 5),
    ])
    func readsDates(text: String, year: Int, month: Int, day: Int) throws {
        let date = try #require(ReceiptParser.date(in: text, calendar: calendar))
        #expect(calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: year, month: month, day: day))
    }

    @Test func rejectsImpossibleDates() {
        #expect(ReceiptParser.date(in: "31/02/2026", calendar: calendar) == nil)
        #expect(ReceiptParser.date(in: "Tel 91/234/5678", calendar: calendar) == nil)
    }

    @Test func draftFromScanIsAnExpense() {
        let draft = TransactionDraft(scanned: .init(merchant: "Lidl", amount: 9.99, date: nil))
        #expect(draft.kind == .expense)
        #expect(draft.title == "Lidl")
        #expect(draft.amount == Decimal(string: "9.99"))
        #expect(draft.isValid)
    }
}

/// OCR real do Vision sobre uma fatura desenhada no teste.
struct ReceiptScannerTests {
    @Test func recognizesRenderedReceipt() async throws {
        let data = try Self.renderReceipt(["LIDL SUPERMERCADOS", "Fecha 02/11/2026", "PLATANOS 1,89", "TOTAL 12,45"])
        let result = try await ReceiptScanner.scan(imageData: data)
        #expect(result.amount == Decimal(string: "12.45"))
        #expect(result.merchant?.lowercased().contains("lidl") == true)
        #expect(result.date != nil)
    }

    @Test func rejectsGarbageData() async {
        await #expect(throws: ReceiptScanner.ScanError.self) {
            _ = try await ReceiptScanner.scan(imageData: Data([0, 1, 2, 3]))
        }
    }

    static func renderReceipt(_ lines: [String]) throws -> Data {
        let width = 900, lineHeight = 90, height = lineHeight * (lines.count + 1)
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 48, nil)
        for (index, text) in lines.enumerated() {
            let attributed = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            ])
            context.textPosition = CGPoint(x: 40, y: height - lineHeight * (index + 1))
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
