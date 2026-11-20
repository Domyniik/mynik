import Foundation

/// Categorização por regras, sem IA: usada quando a Apple Intelligence não está
/// disponível (ou para não gastar o modelo quando a resposta é óbvia).
///
/// Ordem de decisão:
/// 1. histórico — o último movimento com a mesma descrição (ou o mesmo comerciante);
/// 2. comerciantes conhecidos em Espanha/Portugal (Mercadona → Alimentação, Repsol → Carro...);
/// 3. palavras do dia a dia ("farmácia", "renda", "gasolina"...).
nonisolated struct MerchantCategoryRules: Sendable {
    /// Um movimento anterior: descrição e nome da categoria.
    struct HistoryEntry: Sendable {
        let title: String
        let categoryName: String
        let date: Date
    }

    /// Nome da categoria (das iniciais) → palavras que a identificam.
    /// Uma palavra com espaço no fim só conta como palavra inteira ("dia ", "bp ").
    static let keywords: [(category: String, words: [String])] = [
        ("Assinaturas", [
            "netflix", "spotify", "hbo", "disney", "prime video", "amazon prime", "apple.com/bill",
            "icloud", "apple music", "youtube premium", "google one", "chatgpt", "openai", "anthropic",
            "dazn", "movistar plus", "filmin", "adobe", "microsoft 365", "notion", "github", "patreon",
            "audible",
        ]),
        ("Alimentação", [
            "mercadona", "lidl", "aldi", "carrefour", "dia ", "eroski", "alcampo", "consum", "hipercor",
            "supercor", "bonpreu", "caprabo", "ahorramas", "condis", "continente", "pingo doce",
            "intermarche", "minipreco", "auchan", "glovo", "just eat", "uber eats", "deliveroo",
            "telepizza", "mcdonald", "burger king", "kfc", "starbucks", "restaurante", "cafeteria",
            "panaderia", "padaria", "supermercado", "mercado", "talho", "carniceria", "fruteria",
            "comida", "almoco", "jantar", "cafe ", "bar ",
        ]),
        ("Carro", [
            "repsol", "cepsa", "moeve", "galp", "bp ", "shell", "petronor", "ballenoil", "plenoil",
            "petroprix", "gasolinera", "gasolina", "gasoleo", "combustivel", "combustible", "parking",
            "aparcamiento", "estacionamento", "telpark", "empark", "autopista", "peaje", "portagem",
            "itv ", "taller", "norauto", "feu vert", "midas ",
        ]),
        ("Transporte", [
            "renfe", "cercanias", "metro ", "emt ", "tmb ", "alsa ", "avanza", "uber", "cabify", "bolt ",
            "freenow", "free now", "taxi", "blablacar", "ryanair", "vueling", "iberia", "easyjet",
            "autocarro", "comboio", "bicimad",
        ]),
        ("Saúde", [
            "farmacia", "parafarmacia", "clinica", "hospital", "dentista", "medico", "sanitas",
            "adeslas", "dkv ", "optica", "opticalia", "multiopticas", "fisioterapia",
        ]),
        ("Lazer", [
            "cine ", "cinema", "yelmo", "cinesa", "kinepolis", "teatro", "museo", "museu", "concierto",
            "ticketmaster", "entradas", "steam", "playstation", "nintendo", "xbox", "booking", "airbnb",
            "hotel", "gimnasio", "ginasio", "basic fit", "dreamfit", "viagem",
        ]),
        ("Compras", [
            "amazon", "aliexpress", "shein", "temu", "zara", "pull&bear", "bershka", "stradivarius",
            "massimo dutti", "primark", "h&m", "mango ", "decathlon", "ikea", "leroy merlin", "mediamarkt",
            "media markt", "fnac", "el corte ingles", "apple store", "pccomponentes", "roupa",
        ]),
        ("Casa", [
            "iberdrola", "endesa", "naturgy", "holaluz", "edp ", "totalenergies", "canal de isabel",
            "movistar", "vodafone", "orange", "digi ", "masmovil", "yoigo", "pepephone", "lowi ",
            "renda", "alquiler", "comunidad", "luz ", "agua ", "internet", "gas natural",
        ]),
        ("Salário", ["nomina", "salario", "ordenado", "payroll"]),
        ("Loja", ["shopify", "neloce", "stripe payout"]),
    ]

    private let history: [String: (name: String, date: Date)]
    private let merchantHistory: [String: (name: String, date: Date)]

    init(history: [HistoryEntry] = []) {
        var byTitle: [String: (name: String, date: Date)] = [:]
        var byMerchant: [String: (name: String, date: Date)] = [:]
        for entry in history {
            let key = Self.normalize(entry.title)
            guard !key.isEmpty else { continue }
            if byTitle[key].map({ $0.date <= entry.date }) ?? true {
                byTitle[key] = (entry.categoryName, entry.date)
            }
            let merchant = Self.merchantKey(entry.title)
            if !merchant.isEmpty, byMerchant[merchant].map({ $0.date <= entry.date }) ?? true {
                byMerchant[merchant] = (entry.categoryName, entry.date)
            }
        }
        self.history = byTitle
        self.merchantHistory = byMerchant
    }

    /// Categoria sugerida pelo histórico (a mais fiável: foi o próprio utilizador que a escolheu).
    func historySuggestion(for title: String, among categoryNames: [String]) -> Suggestion? {
        let available = Self.index(categoryNames)
        if let name = history[Self.normalize(title)]?.name, let match = available[name.searchKey] {
            return Suggestion(categoryName: match, source: .history)
        }
        let merchant = Self.merchantKey(title)
        if !merchant.isEmpty, let name = merchantHistory[merchant]?.name, let match = available[name.searchKey] {
            return Suggestion(categoryName: match, source: .history)
        }
        return nil
    }

    /// Categoria sugerida pelo comerciante ou por palavras conhecidas.
    func keywordSuggestion(for title: String, among categoryNames: [String]) -> Suggestion? {
        let key = Self.normalize(title)
        guard !key.isEmpty else { return nil }
        let available = Self.index(categoryNames)
        let padded = " \(key) "
        for (category, words) in Self.keywords {
            guard let match = available[category.searchKey] else { continue }
            if words.contains(where: { padded.contains(Self.pad($0)) }) {
                return Suggestion(categoryName: match, source: .rules)
            }
        }
        // Uma categoria do utilizador cujo nome aparece na descrição ("Ginásio" em "Mensalidade ginásio").
        let direct = categoryNames.first { name in
            let nameKey = Self.normalize(name)
            return nameKey.count >= 3 && padded.contains(" \(nameKey) ")
        }
        return direct.map { Suggestion(categoryName: $0, source: .rules) }
    }

    /// Histórico primeiro, depois comerciantes e palavras.
    func suggest(for title: String, among categoryNames: [String]) -> Suggestion? {
        historySuggestion(for: title, among: categoryNames)
            ?? keywordSuggestion(for: title, among: categoryNames)
    }

    // MARK: - Texto

    /// Descrição comparável: minúsculas, sem acentos, só letras/números e espaços simples.
    static func normalize(_ text: String) -> String {
        let folded = text.searchKey.lowercased()
        let kept = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "&./"))
        let cleaned = String(String.UnicodeScalarView(folded.unicodeScalars.map { kept.contains($0) ? $0 : " " }))
        return cleaned.split(separator: " ").joined(separator: " ")
    }

    /// Primeira palavra significativa (o comerciante): "COMPRA MERCADONA VALENCIA 1234" → "mercadona".
    static func merchantKey(_ text: String) -> String {
        let ignored: Set<String> = [
            "compra", "pago", "pagamento", "tarjeta", "cartao", "card", "apple", "pay", "en", "em",
            "de", "da", "do", "the", "con", "com",
        ]
        return normalize(text)
            .split(separator: " ")
            .first { word in word.count >= 3 && !ignored.contains(String(word)) && !word.allSatisfy(\.isNumber) }
            .map(String.init) ?? ""
    }

    private static func index(_ names: [String]) -> [String: String] {
        Dictionary(names.map { ($0.searchKey, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func pad(_ word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        // Com espaço no fim só vale a palavra inteira; sem espaço pode ser o início de uma palavra.
        return word.hasSuffix(" ") ? " \(trimmed) " : " \(trimmed)"
    }
}

extension MerchantCategoryRules {
    /// Resultado de uma sugestão e de onde veio.
    nonisolated struct Suggestion: Equatable, Sendable {
        let categoryName: String
        let source: CategorySuggestionSource
    }
}

/// Origem de uma categoria sugerida (mostrada no formulário).
nonisolated enum CategorySuggestionSource: String, Sendable {
    case history
    case rules
    case appleIntelligence

    var label: String {
        switch self {
        case .history: "Sugerida pelo histórico"
        case .rules: "Sugerida pelo nome do comerciante"
        case .appleIntelligence: "Sugerida pela Apple Intelligence"
        }
    }

    var symbolName: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .rules: "storefront"
        case .appleIntelligence: "sparkles"
        }
    }
}
