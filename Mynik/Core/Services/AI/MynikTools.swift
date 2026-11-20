import Foundation
import FoundationModels
import SwiftData

/// Ferramentas que o modelo do dispositivo chama para ler os dados do Mynik.
///
/// Correm fora do ator principal (`@concurrent`), por isso só guardam o contentor
/// (que é `Sendable`) e leem os dados no `MainActor`.
nonisolated struct FinanceTool: Tool {
    let container: ModelContainer
    let converter: CurrencyConverter

    let name = "consultarFinancas"
    let description = """
        Receitas, gastos, saldo e gastos por categoria de um mês. \
        Com 'filtro', devolve quanto se gastou numa categoria ou comerciante.
        """

    @Generable
    struct Arguments {
        @Guide(description: "0 = este mês, 1 = mês passado, 2 = há dois meses", .range(0...24))
        var mesesAtras: Int
        @Guide(description: "Categoria ou comerciante (ex.: Alimentação, Mercadona). Vazio para o resumo do mês.")
        var filtro: String
    }

    func call(arguments: Arguments) async throws -> String {
        let (container, converter) = (container, converter)
        return await MainActor.run {
            let digest = MynikDataDigest(context: container.mainContext, converter: converter)
            let filter = arguments.filtro.trimmingCharacters(in: .whitespacesAndNewlines)
            return filter.isEmpty
                ? digest.finances(monthsAgo: arguments.mesesAtras)
                : digest.spending(matching: filter, monthsAgo: arguments.mesesAtras)
        }
    }
}

nonisolated struct BillsTool: Tool {
    let container: ModelContainer
    let converter: CurrencyConverter

    let name = "consultarContasAPagar"
    let description = "Contas a pagar ainda não pagas que vencem nos próximos dias (inclui as em atraso)."

    @Generable
    struct Arguments {
        @Guide(description: "Quantos dias à frente consultar", .range(1...90))
        var dias: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let (container, converter) = (container, converter)
        return await MainActor.run {
            MynikDataDigest(context: container.mainContext, converter: converter).bills(days: arguments.dias)
        }
    }
}

nonisolated struct StoreTool: Tool {
    let container: ModelContainer
    let converter: CurrencyConverter

    let name = "consultarLoja"
    let description = "Vendas, pedidos, lucro real, ticket médio e conversão da loja Shopify (Neloce)."

    @Generable
    struct Arguments {
        @Guide(description: "Período a consultar", .anyOf(["hoje", "7 dias", "30 dias"]))
        var periodo: String
    }

    func call(arguments: Arguments) async throws -> String {
        let period: StorePeriod = switch arguments.periodo {
        case "hoje": .today
        case "30 dias": .month
        default: .week
        }
        let (container, converter) = (container, converter)
        return await MainActor.run {
            MynikDataDigest(context: container.mainContext, converter: converter).store(period: period)
        }
    }
}

nonisolated struct LifeTool: Tool {
    let container: ModelContainer
    let converter: CurrencyConverter

    let name = "consultarVida"
    let description = """
        Dados pessoais: carro (consumo, km, prazos), documentos a expirar, carreira (follow-ups), \
        metas de poupança, património/investimentos ou agenda geral de prazos.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Tema", .anyOf(LifeTopic.allCases.map(\.rawValue)))
        var tema: String
    }

    func call(arguments: Arguments) async throws -> String {
        let topic = LifeTopic(rawValue: arguments.tema) ?? .agenda
        let (container, converter) = (container, converter)
        return await MainActor.run {
            MynikDataDigest(context: container.mainContext, converter: converter).life(topic: topic)
        }
    }
}
