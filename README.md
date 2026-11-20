# Mynik

> *A tua vida, num só lugar.*

**Dashboard pessoal nativa para iOS e macOS:** finanças, contas a pagar, analytics da loja Shopify, projetos, notas, carro, documentos e carreira, tudo num só app sincronizado por iCloud.

![Swift](https://img.shields.io/badge/Swift-6-F05138) ![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2026%20%7C%20macOS%2026-blue) ![SwiftData](https://img.shields.io/badge/SwiftData-CloudKit-green)

## Destaques
- 📱💻 **Um só código** para iPhone e Mac (SwiftUI multiplataforma)
- 💶 **Finanças**: orçamento, contas a pagar com alertas, assinaturas, gastos automáticos via Apple Pay
- 🛍️ **Shopify Analytics**: lucro real e ranking de produtos (vencedores vs perdedores) com diagnóstico do funil
- ☁️ **Sync iCloud** com SwiftData + CloudKit
- 🤖 **IA on-device** (Foundation Models) para categorizar gastos e responder perguntas sobre os dados
- 🧩 Widgets, Siri/Atalhos, Live Activities, Menu Bar no Mac

## Stack
SwiftUI · SwiftData · CloudKit · Swift Charts · WidgetKit · App Intents · VisionKit · Foundation Models · Shopify Admin GraphQL API

## Estado
✅ **Fase 1 (MVP) concluída**: projeto multiplataforma, modelos SwiftData, navegação adaptativa (barra lateral no Mac/iPad, separadores no iPhone), Finanças (lista, adicionar e editar gastos/receitas) e tela Hoje (saldo do mês, últimos gastos, contas a vencer).

✅ **Fase 2 (Finanças completas) concluída**: contas a pagar com recorrência e botão "paguei", notificações de vencimento, orçamento mensal por categoria, relatórios com Swift Charts, assinaturas (total mensal/anual), importação de extratos CSV (com deteção de duplicados; exemplo em [docs/exemplo-extrato.csv](docs/exemplo-extrato.csv)) e multi-moeda EUR/BRL com taxa do BCE.

✅ **Fase 3 (Loja Shopify — Neloce) concluída**: ligação à Admin GraphQL API (credenciais do app no Keychain, respeito pelo limite por custo), cache em SwiftData, KPIs com comparação e **lucro real** (sem IVA, custo dos artigos, envios, taxas e anúncios), gráfico diário, **ranking de produtos** com score 0–100 e ação sugerida, diagnóstico do funil, carrinhos abandonados, pedidos por enviar, alertas e notificações de venda locais, ciclo de vida do produto e lucro mensal lançado nas Finanças. Sem loja ligada, o módulo mostra uma loja de exemplo.

✅ **Fase 4 (Projetos, metas e notas) concluída**: projetos com tarefas em **Kanban** (arrastar entre colunas) ou lista, prioridade e prazo, tarefas avulsas; **metas** com valor-alvo e prazo ligadas às Finanças (saldo de uma conta ou movimentos de uma categoria, com quanto juntar por mês); **notas** estilo Notion com páginas aninhadas e blocos (texto, título, checklist, imagem), **Markdown** (atalhos ao escrever, exportar e colar) e ligações entre notas, projetos e movimentos, incluindo menções `[[Título]]`. Tarefas do dia e metas aparecem na tela Hoje.

✅ **Fase 5 (Vida) concluída**: **carro** com abastecimentos e consumo (L/100 km), manutenções, prazos de ITV, seguro e imposto com avisos (gastos na categoria Carro) e **preços de combustível em Espanha** perto de ti (API do Ministerio, com cache offline); **documentos** com validade e avisos antes de expirar, números e fotos protegidos por **Face ID / Touch ID**; **carreira** com candidaturas por estado, taxa de resposta, follow-ups e cursos/certificações; **património** com total investido, cotações do dia (Yahoo Finance + câmbio do BCE), aportes, evolução diária e meta de poupança. Os prazos aparecem em "A vencer" na tela Hoje.

🚧 Próxima: **Fase 6 (Ecossistema Apple: widgets, Siri/Atalhos, MenuBar)**. Ver [ROADMAP](docs/ROADMAP.md) e [CHANGELOG](CHANGELOG.md).

## Instalar (Mac)
```bash
brew install --cask domyniik/tap/mynik
```
Requer macOS 26 (Tahoe). Para atualizar: `brew update && brew upgrade --cask mynik`.

Para publicar uma versão nova: `scripts/release.sh <versão>` (compila, cria a release no GitHub e atualiza a [tap](https://github.com/Domyniik/homebrew-tap)).

## Como correr
Requer Xcode 27+. O projeto é gerado com [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open Mynik.xcodeproj
```

## Screenshots
_Em breve._

---
Desenvolvido por **Domynik**, com Claude Code como par de programação.
