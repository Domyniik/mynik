import Foundation
import FoundationModels
import Observation
import OSLog
import SwiftData

/// Uma mensagem do chat "Pergunte ao Mynik".
struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    /// Resposta do modo sem IA (resumo direto dos dados).
    var isOffline = false
}

/// Estado do chat: usa o modelo do dispositivo com ferramentas que leem o SwiftData;
/// sem Apple Intelligence, responde com os resumos certos por palavras-chave.
@MainActor
@Observable
final class AskMynikModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isResponding = false
    private(set) var status: AppleIntelligence.Status = .unknown

    @ObservationIgnored private var session: LanguageModelSession?

    static let suggestions = [
        "Quanto gastei este mês?",
        "Que contas vencem esta semana?",
        "Como correu a loja nos últimos 7 dias?",
        "Quanto gastei em alimentação?",
        "Como estão as minhas metas?",
        "Qual é o consumo do carro?",
    ]

    func refreshStatus() {
        status = AppleIntelligence.status
    }

    func send(_ question: String, container: ModelContainer, converter: CurrencyConverter) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResponding else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        isResponding = true
        defer { isResponding = false }

        let digest = MynikDataDigest(context: container.mainContext, converter: converter)
        // Os dados do tema reconhecido vão já com a pergunta: o modelo pequeno
        // nem sempre chama as ferramentas, e assim nunca responde sem números.
        let context = Self.relevantData(for: trimmed, digest: digest)
        if status.isAvailable,
           let answer = await askModel(Self.prompt(trimmed, data: context), container: container, converter: converter),
           Self.isUsable(answer) {
            messages.append(ChatMessage(role: .assistant, text: answer))
        } else {
            messages.append(ChatMessage(role: .assistant, text: Self.offlineAnswer(trimmed, digest: digest), isOffline: true))
        }
    }

    func reset() {
        messages.removeAll()
        session = nil
    }

    // MARK: - Modelo

    private func askModel(_ question: String, container: ModelContainer, converter: CurrencyConverter) async -> String? {
        let session = session ?? makeSession(container: container, converter: converter)
        self.session = session
        do {
            return try await session.respond(to: question).content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Conversa longa demais: recomeça a sessão e tenta outra vez.
            let fresh = makeSession(container: container, converter: converter)
            self.session = fresh
            return try? await fresh.respond(to: question).content
        } catch {
            Self.logger.error("Pergunte ao Mynik: o modelo falhou — \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static let logger = Logger(subsystem: "com.domynik.mynik", category: "AskMynik")

    private func makeSession(container: ModelContainer, converter: CurrencyConverter) -> LanguageModelSession {
        let today = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(.app))
        let tools: [any Tool] = [
            FinanceTool(container: container, converter: converter),
            BillsTool(container: container, converter: converter),
            StoreTool(container: container, converter: converter),
            LifeTool(container: container, converter: converter),
        ]
        return LanguageModelSession(tools: tools, instructions: """
            És o Mynik, o assistente da dashboard pessoal do utilizador. Hoje é \(today); moeda EUR.
            Responde sempre em português de Portugal, de forma curta e direta.
            Para qualquer número usa as ferramentas; nunca inventes valores.
            Se os dados não existirem, diz isso.
            """)
    }

    // MARK: - Contexto

    static func relevantData(for question: String, digest: MynikDataDigest) -> String? {
        QuestionRouter.route(question) == .unknown ? nil : offlineAnswer(question, digest: digest)
    }

    static func prompt(_ question: String, data: String?) -> String {
        guard let data else { return question }
        return """
            \(question)

            Dados atuais do utilizador (usa estes números; se faltar algo, usa as ferramentas):
            \(data)
            """
    }

    /// Respostas vazias ou só com restos de chamadas a ferramentas não servem.
    static func isUsable(_ answer: String) -> Bool {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 3 && !trimmed.contains("[{") && !trimmed.contains("{}]")
    }

    // MARK: - Sem IA

    static func offlineAnswer(_ question: String, digest: MynikDataDigest) -> String {
        switch QuestionRouter.route(question) {
        case .finances(let monthsAgo): digest.finances(monthsAgo: monthsAgo)
        case .spending(let query, let monthsAgo): digest.spending(matching: query, monthsAgo: monthsAgo)
        case .bills(let days): digest.bills(days: days)
        case .store(let period): digest.store(period: period)
        case .life(let topic): digest.life(topic: topic)
        case .unknown:
            """
            Sem a Apple Intelligence só sei responder a perguntas sobre gastos, contas a pagar, \
            loja, carro, documentos, carreira, metas e património. Experimenta uma das sugestões.
            """
        }
    }
}
