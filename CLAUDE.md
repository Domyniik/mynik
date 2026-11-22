# CLAUDE.md — Mynik

> Lê este ficheiro no início de TODAS as sessões. É a fonte de verdade do projeto.

## Visão
**Mynik** (de Domynik — e "My" em inglês) é uma dashboard pessoal que junta toda a vida do Domynik num só app:
finanças, contas a pagar, loja Shopify (Neloce), projetos, notas estilo Notion, carro, documentos, carreira e investimentos.
Também é a **peça principal do portfólio** — código limpo, commits claros e README apresentável importam.

- Idioma da interface: **português (pt-PT)**
- Moeda: **EUR** (com suporte a BRL)
- Timezone: Europe/Madrid
- **Stack 100% grátis**: sem Apple Developer Program, sem serviços pagos

## Arquitetura (desde a v2.0)
```
📱 iPhone / iPad      → Swift (SwiftUI + SwiftData como cache offline)
💻 Mac + Windows      → Tauri v2 (/desktop) com a web Next.js (/web) lá dentro
☁️ Dados e servidor   → Supabase (Postgres + RLS, Auth por magic link, Edge Function, pg_cron)
```
- As duas apps leem e escrevem **as mesmas 25 tabelas tipadas** (last-write-wins por `modified_at`).
  O iPhone usa `sync_pull` / `sync_push`; o desktop lê e escreve direto (PostgREST + Realtime).
- Os cálculos partilhados (score dos produtos, lucro real, KPIs, orçamento, resumo do mês) são **funções SQL**,
  com testes de paridade iPhone ↔ SQL (`MynikTests/Fixtures/parity-*.json`).
- A Shopify só fala com o servidor (Edge Function `mynik-api`); o segredo fica nos *secrets* da função.
- `docs/FEATURES.md` é o checklist de paridade iOS ↔ desktop: uma funcionalidade nova entra nas duas apps.

## Stack
**iPhone (Swift)**
- SwiftUI, Swift 6, `@Observable`, iOS 26; SwiftData com esquema versionado (propriedades opcionais ou com default, relações opcionais, sem `@Attribute(.unique)`)
- Swift Charts · WidgetKit · App Intents · ActivityKit · UserNotifications · EventKit · VisionKit · Foundation Models
- Cliente Supabase (`supabase-swift`); configuração em `Config/Supabase.xcconfig` (fora do git)

**Web e desktop**
- Next.js 16 (exportação estática) · React 19 · Tailwind 4 · shadcn/ui · Recharts · vitest
- Tauri v2 (Rust): tray, atalho global, notificações, iniciar com o sistema, deep link `mynik://`
- Modo de demonstração com PGlite (Postgres no browser) e as mesmas migrações

**Servidor**
- Supabase: migrações em `supabase/migrations` (geradas de `supabase/schema/entities.mjs`), testes em PGlite
- Edge Function `mynik-api` (Deno): Shopify, cotações, câmbio, combustível, Google Ads, iCal
- pg_cron + pg_net: sync da loja de 30 em 30 min

## Estrutura
```
Mynik/            app iPhone (App/, Core/, Features/, Widgets/, Intents/)
MynikTests/       Swift Testing
web/              Next.js: src/app/<rota>/page.tsx reexporta src/components/<módulo>/<x>-page.tsx
                  src/lib/ (db, calc, desktop.ts, format, settings…)
desktop/          Tauri v2: src-tauri/src/lib.rs, tauri.conf.json, ícones
supabase/         migrations/, schema/, functions/mynik-api/, tests/
.github/workflows/desktop.yml   instaladores .dmg (Apple Silicon e Intel) e .exe
scripts/release.sh              publica uma versão do desktop
docs/             ROADMAP.md, FEATURES.md, screenshots
```

## Módulos
1. **Hoje** — saldo do mês, contas a vencer (7 dias), tarefas, hábitos, agenda, metas, vendas da loja hoje; revisão semanal ao domingo.
2. **Finanças** — movimentos por categoria e conta, orçamento, contas a pagar (recorrência + "paguei"), assinaturas, relatórios, importar CSV, EUR/BRL, scanner de faturas; no iPhone também App Intent "gastei X em Y" e Apple Pay pelo Atalhos.
3. **Loja (Shopify — Neloce)** — scopes só de leitura (`read_products`, `read_orders`, `read_analytics`, `read_inventory`). KPIs com comparação, **lucro real**, **ranking de produtos 0–100** (🟢 Vencedor / 🟡 Promissor / 🟠 Em teste / 🔴 Perdedor) com ação sugerida, diagnóstico do funil, carrinhos abandonados, pedidos por enviar, alertas, ciclo de vida, Google Ads por folha pública. Lucro mensal entra nas Finanças.
4. **Projetos & Metas** — Kanban + lista, tarefas, metas ligadas às Finanças.
5. **Notas** — estilo wiki: blocos, menu "/", bases de dados (Tabela/Quadro/Calendário), menções @, templates, importar Notion.
6. **Carro** — abastecimentos e consumo, manutenções, ITV/seguro/imposto com alertas, preços de combustível.
7. **Documentos** — validade e avisos; números e fotos protegidos (Face ID no iPhone, PIN no desktop); fotos só no dispositivo.
8. **Carreira** — candidaturas e follow-ups, cursos e certificações.
9. **Património** — investimentos com cotações, evolução, meta de poupança.
10. **Extras** — hábitos, busca global ⌘K, backup JSON, "Pergunte ao Mynik"; iPhone: widgets, Live Activity, Siri; desktop: tray, ⇧⌘K global, iniciar com o sistema.

## Fases
Fases 1–10: app Swift (v0.1 → v1.4). Fase 11: desktop Tauri + Supabase partilhado (v2.0). Checklist em `docs/ROADMAP.md`.

## Regras de trabalho (OBRIGATÓRIO)
- **Uma fase por sessão.** No início, lê `docs/ROADMAP.md` e diz qual fase/feature vais fazer.
- **Um commit por feature**, em Conventional Commits, mensagem em português:
  `feat(finance): adiciona contas a pagar com recorrência`, `fix(store): ...`, `feat(web): ...`, `feat(desktop): ...`, `feat(supabase): ...`, `docs: ...`
- **Paridade:** uma funcionalidade nova entra no iPhone **e** no desktop, e fica marcada em `docs/FEATURES.md`.
- Antes de cada commit, compila e testa o que mudou:
  - iPhone: `xcodebuild -project Mynik.xcodeproj -scheme Mynik -destination 'generic/platform=iOS Simulator' build` (e `test` num simulador)
  - Web: `cd web && npx tsc --noEmit && npm test && npm run build`
  - Desktop: `cd desktop/src-tauri && cargo check` (ou `cd desktop && npm run build` para o .app/.dmg)
  - Supabase: `cd supabase && npm test`; Edge Function: `deno check supabase/functions/mynik-api/index.ts`
- Mudar o esquema: edita `supabase/schema/entities.mjs`, `npm run generate`, e uma alteração a uma migração já aplicada vai numa **migração nova**.
- Ao fechar uma feature: marca `[x]` em `docs/ROADMAP.md` (e em `docs/FEATURES.md`) e acrescenta uma linha em `CHANGELOG.md`.
- Ao fechar uma fase: atualiza a secção "Estado" do `README.md`, faz `git push` e publica com `scripts/release.sh <versão>`:
  1. põe a versão em `web/`, `desktop/` e `tauri.conf.json`, faz commit e a tag `vX.Y.Z`
  2. o push da tag corre `.github/workflows/desktop.yml`, que compila os `.dmg` (Apple Silicon e Intel) e o `.exe` e os põe na GitHub Release
  3. atualiza a cask em `Domyniik/homebrew-tap` para os `.dmg` (`brew install --cask domyniik/tap/mynik`)
- O iPhone não tem release automática (sem conta paga): instala-se pelo Xcode ou pelo Sideloadly.
- **Segredos nunca no git** (tokens, `.env`, chaves): no iPhone ficam no Keychain e em `Config/*.xcconfig`; no servidor, nos secrets da Edge Function e no Vault; na web só a chave pública em `web/.env.local`. Há sempre um ficheiro `.example`.
- Código pequeno e focado: views/componentes pequenos, lógica em services/`lib`/SQL, sem APIs depreciadas.
- Skills a usar quando disponíveis: `swiftui-pro`, `swiftdata-pro`, `swift-ios-skills` (iPhone); `ecc:react-patterns`, `ecc:nextjs-turbopack`, `ecc:rust-patterns`, `ecc:postgres-patterns` (desktop e servidor).
