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

🚧 Próxima: **Fase 2 (Finanças completas)**. Ver [ROADMAP](docs/ROADMAP.md) e [CHANGELOG](CHANGELOG.md).

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
