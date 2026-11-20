import Foundation

/// Extrai comerciante, total e data do texto de uma fatura/talão (linhas do OCR).
///
/// Pensado para talões espanhóis e portugueses: "TOTAL", "IMPORTE", "A PAGAR",
/// datas dia/mês/ano e valores com vírgula decimal.
nonisolated enum ReceiptParser {
    struct Result: Equatable, Sendable {
        var merchant: String?
        var amount: Decimal?
        var date: Date?
        var currencyCode = Currency.defaultCode
    }

    static func parse(lines rawLines: [String], calendar: Calendar = .current) -> Result {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let joined = lines.joined(separator: " ").uppercased()
        var result = Result()
        result.currencyCode = joined.contains("R$") || joined.contains("BRL") ? "BRL" : Currency.defaultCode
        result.merchant = merchant(in: lines)
        result.amount = total(in: lines)
        result.date = lines.lazy.compactMap { date(in: $0, calendar: calendar) }.first
        return result
    }

    // MARK: - Total

    private static let totalWords = ["total a pagar", "a pagar", "importe total", "total eur", "total €", "total", "importe", "a liquidar", "valor pago"]
    private static let ignoredTotalWords = ["subtotal", "sub-total", "base imp", "iva", "i.v.a", "desconto", "descuento", "cambio", "troco", "entregado", "total articulos", "total artigos", "nº art"]

    static func total(in lines: [String]) -> Decimal? {
        // De baixo para cima: o total final costuma estar perto do fim.
        for (index, line) in lines.enumerated().reversed() {
            let key = line.searchKey.lowercased()
            guard totalWords.contains(where: { key.contains($0) }),
                  !ignoredTotalWords.contains(where: { key.contains($0) })
            else { continue }
            if let amount = amounts(in: line).last { return amount }
            // O valor pode vir na linha seguinte (colunas lidas em separado).
            if index + 1 < lines.count, let amount = amounts(in: lines[index + 1]).first { return amount }
        }
        // Sem palavra "total": o maior valor com cêntimos.
        return lines.flatMap(amounts(in:)).max()
    }

    /// Valores com duas casas decimais numa linha: "12,50", "1.234,56", "€ 3.20".
    static func amounts(in line: String) -> [Decimal] {
        let pattern = /(\d{1,3}(?:[.\s]\d{3})+|\d+)[.,](\d{2})(?!\d)/
        return line.matches(of: pattern).compactMap { match in
            let integer = String(match.output.1).filter(\.isNumber)
            return Decimal(string: "\(integer).\(match.output.2)", locale: Locale(identifier: "en_US_POSIX"))
        }.filter { $0 > 0 && $0 < 100_000 }
    }

    // MARK: - Data

    static func date(in line: String, calendar: Calendar = .current) -> Date? {
        if let match = line.firstMatch(of: /(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})/) {
            return makeDate(year: Int(match.output.1), month: Int(match.output.2), day: Int(match.output.3), calendar: calendar)
        }
        if let match = line.firstMatch(of: /(?:^|\D)(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})(?!\d)/) {
            guard var year = Int(match.output.3) else { return nil }
            if year < 100 { year += 2000 }
            return makeDate(year: year, month: Int(match.output.2), day: Int(match.output.1), calendar: calendar)
        }
        return nil
    }

    private static func makeDate(year: Int?, month: Int?, day: Int?, calendar: Calendar) -> Date? {
        guard let year, let month, let day, (2000...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day // rejeita 31/02
        else { return nil }
        return date
    }

    // MARK: - Comerciante

    private static let ignoredMerchantWords = [
        "factura", "fatura", "ticket", "talao", "recibo", "simplificada", "cif", "nif", "nipc", "tel", "telf",
        "fecha", "data", "hora", "calle", "c/", "avda", "rua", "www", "http", "@", "bienvenido", "obrigado", "gracias",
    ]

    static func merchant(in lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let key = line.searchKey.lowercased()
            let letters = line.filter(\.isLetter).count
            let digits = line.filter(\.isNumber).count
            guard letters >= 3, digits <= letters,
                  !ignoredMerchantWords.contains(where: { key.contains($0) }),
                  amounts(in: line).isEmpty
            else { continue }
            return prettify(line)
        }
        return nil
    }

    /// "MERCADONA, S.A." → "Mercadona, S.A."; mantém o que já tem maiúsculas e minúsculas.
    private static func prettify(_ line: String) -> String {
        guard line == line.uppercased() else { return line }
        return line.split(separator: " ").map { word in
            word.count <= 2 || word.contains(".") ? String(word) : word.prefix(1) + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}
