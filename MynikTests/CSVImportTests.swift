import Foundation
import Testing
@testable import Mynik

struct CSVImportTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var importer: BankCSVImporter { BankCSVImporter(calendar: calendar) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func parsesQuotedFieldsAndDetectsDelimiter() {
        let rows = CSVParser.parse("a;\"b; c\";\"diz \"\"olá\"\"\"\n1;2;3\n\n")
        #expect(rows == [["a", "b; c", "diz \"olá\""], ["1", "2", "3"]])
        #expect(CSVParser.detectDelimiter(in: "date,description,amount") == ",")
    }

    @Test(arguments: [
        ("1.234,56", Decimal(string: "1234.56")),
        ("-12,30", Decimal(string: "-12.3")),
        ("1,234.56", Decimal(string: "1234.56")),
        ("-12.30", Decimal(string: "-12.3")),
        ("12,30 €", Decimal(string: "12.3")),
        ("(5,00)", Decimal(string: "-5")),
        ("1.000.000", Decimal(string: "1000000")),
        ("abc", nil),
    ])
    func parsesAmounts(text: String, expected: Decimal?) {
        #expect(BankCSVImporter.parseAmount(text) == expected)
    }

    @Test func readsPortugueseStatementWithTitleLines() throws {
        let csv = """
        Extrato de conta à ordem;;;
        Data movimento;Data valor;Descrição;Valor;Saldo
        01/11/2026;01/11/2026;TRF SALARIO;1.850,00;2.310,45
        03/11/2026;03/11/2026;"MERCADONA; VALENCIA";-62,40;2.248,05
        linha estragada;;;;
        """

        let result = try importer.parse(text: csv)

        #expect(result.rows.count == 2)
        #expect(result.skippedLines == 1)
        #expect(result.rows[0] == .init(date: date(2026, 11, 1), title: "TRF SALARIO", signedAmount: 1850))
        #expect(result.rows[1].title == "MERCADONA; VALENCIA")
        #expect(result.rows[1].kind == .expense)
        #expect(result.rows[1].amount == Decimal(string: "62.4"))
    }

    @Test func readsSpanishDebitCreditColumns() throws {
        let csv = """
        Fecha;Concepto;Cargo;Abono
        2026-11-04;Bizum Ana;;25,00
        2026-11-05;Amazon;19,99;
        """

        let result = try importer.parse(text: csv)

        #expect(result.rows.map(\.signedAmount) == [25, Decimal(string: "-19.99")])
        #expect(result.rows.first?.date == date(2026, 11, 4))
    }

    @Test func readsEnglishCommaSeparatedFile() throws {
        let csv = "Date,Description,Amount\n19/11/2026,Coffee,-2.50\n"
        let result = try importer.parse(text: csv)
        #expect(result.rows.first?.signedAmount == Decimal(string: "-2.5"))
    }

    @Test func decodesWindows1252Files() throws {
        let csv = "Data;Descrição;Valor\n19/11/2026;Farmácia;-12,30\n"
        let data = try #require(csv.data(using: .windowsCP1252))
        let result = try importer.parse(data: data)
        #expect(result.rows.first?.title == "Farmácia")
    }

    @Test func failsWithoutRecognisableColumns() {
        #expect(throws: BankCSVImporter.ImportError.self) {
            try importer.parse(text: "foo;bar\n1;2\n")
        }
    }

    @Test func detectsDuplicatesIgnoringCaseAndTime() {
        let detector = DuplicateDetector(
            existing: [(date(2026, 11, 3).addingTimeInterval(3600 * 15), Decimal(-62.4), "Mercadona Valencia")],
            calendar: calendar
        )
        #expect(detector.isDuplicate(.init(date: date(2026, 11, 3), title: "MERCADONA VALENCIA", signedAmount: Decimal(-62.4))))
        #expect(!detector.isDuplicate(.init(date: date(2026, 11, 4), title: "MERCADONA VALENCIA", signedAmount: Decimal(-62.4))))
    }
}

@MainActor
struct CategoryGuesserTests {
    @Test func reusesMostRecentCategoryForSameTitle() {
        let food = Mynik.Category(name: "Alimentação", symbolName: "cart", color: .orange, kind: .expense)
        let other = Mynik.Category(name: "Outros", symbolName: "ellipsis.circle", color: .gray, kind: .expense)
        let history = [
            FinanceTransaction(title: "Mercadona Valencia", amount: 10, kind: .expense, date: .distantPast, category: other),
            FinanceTransaction(title: "Mercadona Valencia", amount: 10, kind: .expense, date: .now, category: food),
        ]
        let guesser = CategoryGuesser(history: history)

        #expect(guesser.category(for: .init(date: .now, title: "MERCADONA VALENCIA", signedAmount: -5))?.name == "Alimentação")
        // Receita com o mesmo nome não herda uma categoria de despesa.
        #expect(guesser.category(for: .init(date: .now, title: "MERCADONA VALENCIA", signedAmount: 5)) == nil)
    }
}
