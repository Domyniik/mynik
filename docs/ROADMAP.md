# Roadmap — Mynik

## Fase 1 — MVP
- [x] Projeto Xcode multiplataforma (iOS 26 + macOS 26) e estrutura de pastas
- [x] Modelos SwiftData: Transaction, Category, Account, Bill
- [x] Navegação (SplitView no Mac, TabView no iPhone)
- [x] Finanças: lista, adicionar e editar gastos/receitas
- [x] Tela Hoje: saldo do mês, últimos gastos, contas a vencer

## Fase 2 — Finanças completas
- [x] Contas a pagar com recorrência + botão "paguei"
- [x] Notificações de vencimento
- [x] Orçamento por categoria
- [x] Gráficos (Swift Charts)
- [x] Assinaturas (total mensal/anual)
- [x] Importar CSV do banco
- [x] Multi-moeda EUR/BRL

## Fase 3 — Loja Shopify (Neloce)
- [x] Setup do token (Keychain) + cliente GraphQL
- [x] Cache local (StoreProduct, StoreOrder, DailyStat)
- [x] KPIs + lucro real + gráfico diário
- [x] Ranking de produtos (score 0–100 + classificação + ação)
- [x] Diagnóstico do funil
- [x] Carrinhos abandonados e pedidos por enviar
- [x] Alertas (dias sem venda) e notificação de venda
- [x] Ciclo de vida do produto
- [x] Lucro da loja → Finanças

## Fase 4 — Projetos, metas e notas
- [x] Projetos (Kanban + lista) e tarefas
- [x] Metas com valor-alvo ligadas às Finanças
- [x] Notas: páginas aninhadas e blocos
- [x] Markdown e links entre itens

## Fase 5 — Vida
- [x] Carro (combustível, manutenção, seguro/ITV/IUC)
- [x] Documentos com validade e Face ID
- [x] Carreira (candidaturas, cursos)
- [x] Investimentos / património

## Fase 6 — Ecossistema Apple
- [x] Sync iCloud (CloudKit) → **trocado por export/import JSON**: o CloudKit exige o Apple Developer Program (pago). Cópia completa de todos os dados, partilhável por AirDrop, iCloud Drive ou Ficheiros, com fusão sem duplicados (por `uid`). Não há sync automático.
- [x] Widgets (iOS + Mac) — saldo do mês e contas a vencer; resumo partilhado por App Group (no Mac, assinado com o certificado grátis da Personal Team)
- [x] App Intents: Siri / Atalhos ("gastei X em Y")
- [x] Automação Apple Pay → transação (ação para a automação "Transação" dos Atalhos; guia no README)
- [x] MenuBarExtra no Mac
- [ ] EventKit (Calendário/Lembretes) na tela Hoje

## Fase 7 — IA e extras
- [ ] Categorização automática (Foundation Models)
- [ ] "Pergunte ao Mynik"
- [ ] Scanner de faturas (VisionKit)
- [ ] Live Activities / Dynamic Island
- [ ] Revisão semanal, hábitos, busca ⌘K

## Fase 8 — Polimento e lançamento
- [ ] Liquid Glass, dark mode, acessibilidade
- [ ] Face ID para abrir o app
- [ ] Backup/export JSON
- [ ] Testes (Swift Testing)
- [ ] TestFlight
- [ ] Screenshots + README final para o portfólio
