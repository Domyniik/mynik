import Foundation

/// Lê um extrato bancário em CSV e transforma-o em movimentos.
///
/// Reconhece cabeçalhos em português, espanhol e inglês ("Data", "Fecha",
/// "Descrição", "Concepto", "Valor", "Importe", "Débito/Crédito"...).
nonisolated struct BankCSVImporter {
    struct Row: Equatable, Sendable {
        let date: Date
        let title: String
        /// Positivo = receita, negativo = gasto.
        let signedAmount: Decimal

        var kind: TransactionKind { signedAmount < 0 ? .expense : .income }
        var amount: Decimal { abs(signedAmount) }
    }

    struct Result: Sendable {
        let rows: [Row]
        let skippedLines: Int
    }

    enum ImportError: LocalizedError {
        case unreadableFile
        case missingColumns

        var errorDescription: String? {
            switch self {
            case .unreadableFile: "Não foi possível ler o ficheiro."
            case .missingColumns: "Não encontrei colunas de data, descrição e valor."
            }
        }
    }

    private struct Columns {
        var date: Int
        var title: Int
        var amount: Int?
        var debit: Int?
        var credit: Int?
    }

    var calendar = Calendar.current

    // MARK: - Entrada

    func parse(data: Data) throws -> Result {
        // Bancos ibéricos ainda exportam muitas vezes em Windows-1252.
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1)
        else { throw ImportError.unreadableFile }
        return try parse(text: text)
    }

    func parse(text: String) throws -> Result {
        let table = CSVParser.parse(text.replacingOccurrences(of: "\u{FEFF}", with: ""))
        guard let (headerIndex, columns) = findHeader(in: table) else { throw ImportError.missingColumns }

        var rows: [Row] = []
        var skipped = 0
        for line in table.dropFirst(headerIndex + 1) {
            if let row = makeRow(from: line, columns: columns) {
                rows.append(row)
            } else {
                skipped += 1
            }
        }
        return Result(rows: rows, skippedLines: skipped)
    }

    // MARK: - Cabeçalho

    /// Procura nas primeiras linhas (há bancos com linhas de título antes) o cabeçalho.
    private func findHeader(in table: [[String]]) -> (Int, Columns)? {
        for (index, line) in table.prefix(15).enumerated() {
            if let columns = columns(forHeader: line) {
                return (index, columns)
            }
        }
        return nil
    }

    private func columns(forHeader header: [String]) -> Columns? {
        let names = header.map(Self.normalize)

        let dateKeywords = ["data", "date", "fecha"]

        /// Primeira coluna com uma das palavras. Fora a da data, ignora colunas
        /// que falem em data (ex.: "Data valor" não é a coluna do valor).
        func find(_ keywords: [String], excluding used: [Int?] = []) -> Int? {
            names.indices.first { index in
                let name = names[index]
                let mentionsDate = keywords != dateKeywords && dateKeywords.contains { name.contains($0) }
                return !used.contains(index) && !mentionsDate && keywords.contains { name.contains($0) }
            }
        }

        guard let date = find(dateKeywords) else { return nil }
        guard let title = find(["descri", "concept", "detalhe", "movimento", "description", "memo", "payee", "beneficiario"], excluding: [date])
        else { return nil }

        let amount = find(["valor", "montante", "importe", "amount", "quantia", "cantidad"], excluding: [date, title])
        let debit = find(["debito", "debit", "cargo"], excluding: [date, title, amount])
        let credit = find(["credito", "credit", "abono"], excluding: [date, title, amount, debit])

        guard amount != nil || (debit != nil && credit != nil) else { return nil }
        // Se houver débito e crédito separados, ignora uma coluna "valor" genérica.
        if debit != nil, credit != nil {
            return Columns(date: date, title: title, amount: nil, debit: debit, credit: credit)
        }
        return Columns(date: date, title: title, amount: amount, debit: nil, credit: nil)
    }

    // MARK: - Linhas

    private func makeRow(from line: [String], columns: Columns) -> Row? {
        func value(_ index: Int?) -> String? {
            guard let index, line.indices.contains(index) else { return nil }
            return line[index]
        }

        guard let date = value(columns.date).flatMap(parseDate) else { return nil }
        let title = value(columns.title)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else { return nil }

        let signedAmount: Decimal
        if let amountText = value(columns.amount) {
            guard let amount = Self.parseAmount(amountText) else { return nil }
            signedAmount = amount
        } else {
            let debit = value(columns.debit).flatMap(Self.parseAmount).map(abs) ?? 0
            let credit = value(columns.credit).flatMap(Self.parseAmount).map(abs) ?? 0
            signedAmount = credit - debit
        }
        guard signedAmount != 0 else { return nil }

        return Row(date: date, title: title, signedAmount: signedAmount)
    }

    // MARK: - Valores

    /// Aceita "1.234,56", "-12,30", "1,234.56", "-12.30", "12,30 €", "(12,30)".
    static func parseAmount(_ text: String) -> Decimal? {
        var cleaned = text.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" || $0 == "(" }
        var isNegative = cleaned.hasPrefix("-") || cleaned.hasPrefix("(") || text.hasSuffix("-")
        cleaned.removeAll { $0 == "-" || $0 == "(" }
        guard !cleaned.isEmpty else { return nil }

        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")
        let decimalSeparator: Character? = switch (lastComma, lastDot) {
        case let (comma?, dot?): comma > dot ? "," : "."
        case (_?, nil): ","
        case (nil, _?): cleaned.filter { $0 == "." }.count == 1 ? "." : nil
        case (nil, nil): nil
        }

        var normalized = ""
        for character in cleaned {
            if character == decimalSeparator {
                normalized.append(".")
            } else if character.isNumber {
                normalized.append(character)
            }
        }

        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        if value == 0 { isNegative = false }
        return isNegative ? -value : value
    }

    private static let dateFormats = [
        "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "yyyy-MM-dd", "yyyy/MM/dd", "dd/MM/yy", "dd-MM-yy",
    ]

    func parseDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // Ignora horas ("2026-11-19 10:32" ou "2026-11-19T10:32:00").
        let datePart = String(trimmed.split(whereSeparator: { $0 == " " || $0 == "T" }).first ?? "")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false

        for format in Self.dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: datePart) {
                return calendar.startOfDay(for: date)
            }
        }
        return nil
    }

    static func normalize(_ header: String) -> String {
        header.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .app)
            .trimmingCharacters(in: .whitespaces)
    }
}
