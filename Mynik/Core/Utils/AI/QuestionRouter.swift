import Foundation

/// Modo sem IA do "Pergunte ao Mynik": reconhece o tema da pergunta por
/// palavras-chave e escolhe o resumo certo dos dados.
nonisolated enum QuestionRouter {
    enum Route: Equatable, Sendable {
        case finances(monthsAgo: Int)
        case spending(query: String, monthsAgo: Int)
        case bills(days: Int)
        case store(StorePeriod)
        case life(LifeTopic)
        case unknown
    }

    static func route(_ question: String) -> Route {
        let text = " " + MerchantCategoryRules.normalize(question) + " "
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        let monthsAgo = has("mes passado", "mes anterior", "ultimo mes") ? 1 : 0

        if has("loja", "vend", "pedido", "shopify", "neloce", "encomenda") {
            let period: StorePeriod = has("hoje") ? .today : has("mes", "30 dias") ? .month : .week
            return .store(period)
        }
        if has(" conta da ", " conta de ", " contas ", "pagar", "vence", "fatura", "factura", "assinatura") && !has("contas bancarias") {
            return .bills(days: has("mes", "30 dias") ? 30 : 7)
        }
        if has("carro", "combustivel", "gasolina", "consumo", "itv", "seguro") { return .life(.car) }
        if has("documento", "passaporte", "dni", "nie", "cartao de cidadao") { return .life(.documents) }
        if has("candidatura", "carreira", "emprego", "entrevista", "follow") { return .life(.career) }
        if has("meta", "objetivo", "poupar para") { return .life(.goals) }
        if has("patrimonio", "investi", "acoes", "etf", "cripto") { return .life(.wealth) }
        if has("prazo", "agenda") { return .life(.agenda) }

        // "Quanto gastei em Mercadona?" / "...com alimentação?"
        for marker in [" gastei em ", " gastei com ", " gasto em ", " gasto com ", " gastos com ", " gastos em "] {
            if let range = text.range(of: marker) {
                // Tira as palavras de ligação e de tempo, palavra a palavra.
                let filler: Set<String> = ["o", "a", "os", "as", "no", "na", "nos", "nas", "este", "esta", "mes", "passado", "anterior", "ultimo", "semana"]
                let rest = text[range.upperBound...]
                    .split(separator: " ")
                    .map(String.init)
                    .filter { !filler.contains($0) }
                    .joined(separator: " ")
                if !rest.isEmpty { return .spending(query: rest, monthsAgo: monthsAgo) }
            }
        }
        if has("gast", "saldo", "receita", "dinheiro", "orcamento", "financ", "poupei", "mes") {
            return .finances(monthsAgo: monthsAgo)
        }
        return .unknown
    }
}
