import Foundation

/// Resultado da leitura de um CSV, pronto a mostrar antes de importar.
struct CSVImportPreview {
    struct Item: Identifiable {
        let id: Int
        let row: BankCSVImporter.Row
        let isDuplicate: Bool
    }

    let fileName: String
    let items: [Item]
    let skippedLines: Int

    var newItems: [Item] { items.filter { !$0.isDuplicate } }
    var duplicateCount: Int { items.count - newItems.count }

    init(fileName: String, result: BankCSVImporter.Result, existing: [FinanceTransaction]) {
        self.fileName = fileName
        self.skippedLines = result.skippedLines

        let detector = DuplicateDetector(
            existing: existing.map { ($0.date, $0.signedAmount, $0.title) }
        )
        items = result.rows.enumerated().map { index, row in
            Item(id: index, row: row, isDuplicate: detector.isDuplicate(row))
        }
    }
}
