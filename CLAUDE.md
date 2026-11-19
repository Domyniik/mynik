# CLAUDE.md — Mynik

> Lê este ficheiro no início de TODAS as sessões. É a fonte de verdade do projeto.

## Visão
**Mynik** (de Domynik — e "My" em inglês) é uma dashboard pessoal nativa para **macOS e iOS** que junta toda a vida do Domynik num só app:
finanças, contas a pagar, loja Shopify (Neloce), projetos, notas estilo Notion, carro, documentos, carreira e investimentos.
Também é a **peça principal do portfólio** — código limpo, commits claros e README apresentável importam.

- Idioma da interface: **português**
- Moeda: **EUR** (com suporte a BRL)
- Timezone: Europe/Madrid

## Stack
- SwiftUI multiplataforma (um target iOS 26 + macOS 26), Swift 6, `@Observable`
- SwiftData — **compatível com CloudKit**: todas as propriedades opcionais ou com default, relações opcionais, **sem `@Attribute(.unique)`**
- Swift Charts · WidgetKit · App Intents · UserNotifications · EventKit
- VisionKit (scanner) · Foundation Models (IA on-device) · MenuBarExtra (Mac)
- Segredos (token Shopify, etc.) **só no Keychain**, nunca no código nem no git

## Estrutura
```
Mynik/
  App/            MynikApp.swift, navegação raiz
  Core/           Models/, Services/ (Keychain, Notifications, Shopify, Currency), Utils/
  Features/
    Today/  Finance/  Store/  Projects/  Notes/
    Car/  Documents/  Career/  Investments/  Settings/
  Widgets/        extensão WidgetKit
  Intents/        App Intents (Siri / Atalhos)
MynikTests/
docs/ROADMAP.md
```
Navegação: `NavigationSplitView` no Mac/iPad, `TabView` no iPhone.

## Módulos
1. **Hoje** — saldo do mês, contas a vencer (7 dias), tarefas, agenda, metas, vendas da loja hoje; revisão semanal ao domingo.
2. **Finanças** — gastos/receitas por categoria e conta, orçamento por categoria, contas a pagar (recorrência + botão "paguei" que cria a transação), assinaturas (total mensal/anual), relatórios com Charts, importar CSV, multi-moeda EUR/BRL, App Intent "gastei X em Y", entrada automática via automação "Transação" do Atalhos (Apple Pay), scanner de faturas.
3. **Loja (Shopify — Neloce)** — Admin GraphQL API (app personalizado, scopes só de leitura: `read_products`, `read_orders`, `read_analytics`, `read_inventory`).
   - KPIs: vendas hoje/7d/30d vs período anterior, pedidos, ticket médio, conversão, **lucro real** (vendas − custo por item − frete − taxas − ads).
   - **Ranking de produtos** com score 0–100 (vendas, receita, margem, funil vista→carrinho→compra, reembolsos, dias sem venda, ROAS) → 🟢 Vencedor / 🟡 Promissor / 🟠 Em teste (<14 dias ou poucos dados) / 🔴 Perdedor, com ação sugerida.
   - Diagnóstico do funil (página/preço vs checkout/frete vs tráfego), carrinhos abandonados, pedidos por enviar, alerta "X dias sem venda", ciclo de vida do produto (teste → decisão), notificação de venda, widget.
   - Respeitar rate limits (custo das queries GraphQL); cache em SwiftData.
   - Lucro líquido da loja entra nas Finanças.
4. **Projetos & Metas** — Kanban + lista, tarefas, metas com valor-alvo ligadas às Finanças.
5. **Notas** — páginas aninhadas, blocos (texto, título, checklist, imagem), Markdown, links entre notas/projetos/gastos.
6. **Carro** — combustível e consumo (L/100km), manutenções, seguro/ITV/IUC com alertas; gastos vão para categoria "Carro".
7. **Documentos** — documentos com data de validade e alerta antes de expirar; fotos protegidas por Face ID.
8. **Carreira** — tracker de candidaturas (empresa, data, estado, follow-up), cursos/certificações.
9. **Investimentos** — total investido, evolução do património, meta de poupança.
10. **Extras** — hábitos, busca global ⌘K, Face ID, backup/export JSON, Live Activity para conta que vence hoje, "Pergunte ao Mynik" (chat sobre os próprios dados), Apple Watch (final).

## Fases (ver docs/ROADMAP.md para o checklist)
1. MVP: estrutura, modelos base, Finanças básicas, tela Hoje
2. Contas a pagar, notificações, orçamento, gráficos, assinaturas
3. Loja Shopify: dashboard + ranking de produtos
4. Projetos, metas e notas
5. Carro, documentos, carreira, investimentos
6. Sync iCloud (CloudKit), widgets, Siri/Atalhos, Apple Pay, MenuBar
7. IA (categorização, "Pergunte ao Mynik"), scanner, Live Activities
8. Polimento (Liquid Glass, acessibilidade), testes, TestFlight

## Regras de trabalho (OBRIGATÓRIO)
- **Uma fase por sessão.** No início, lê `docs/ROADMAP.md` e diz qual fase/feature vais fazer.
- **Um commit por feature**, em Conventional Commits, mensagem em português:
  `feat(finance): adiciona contas a pagar com recorrência`, `fix(store): ...`, `docs: ...`, `refactor: ...`, `test: ...`
- Depois de cada feature: o projeto **tem de compilar** em iOS e macOS (`xcodebuild`) antes do commit.
- Ao fechar uma feature: marca `[x]` em `docs/ROADMAP.md` e acrescenta uma linha em `CHANGELOG.md`.
- Ao fechar uma fase: atualiza a secção "Estado" do `README.md` e faz `git push`.
- Nunca commitar segredos (tokens, `.env`, chaves). Usa Keychain.
- Código pequeno e focado: views em subviews, lógica em services/models, sem APIs depreciadas.
- Skills a usar quando disponíveis: `swiftui-pro`, `swiftdata-pro`, `swiftui-expert-skill`, `swift-ios-skills`.
