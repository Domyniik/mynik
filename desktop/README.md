# Mynik desktop (Tauri v2)

A app de Mac e Windows: a web de [`../web`](../web) (Next.js, exportação estática) numa janela nativa, com:

- **Tray** com as vendas de hoje (no Mac também ao lado do ícone), gasto rápido, procurar e "Iniciar com o sistema"
- **Atalho global** ⇧⌘K (Ctrl+Shift+K no Windows) que abre o ⌘K de qualquer app
- **Notificações do sistema**: vendas novas, contas a pagar, prazos, dias sem venda, revisão semanal
- **Fechar a janela deixa o Mynik no tray**; ao iniciar com o sistema abre escondido
- **Login por deep link**: o link do email abre `mynik://auth/callback`

## Instalar

**Mac:** `brew install --cask domyniik/tap/mynik`, ou descarrega o `.dmg` das [Releases](https://github.com/Domyniik/mynik/releases) (`aarch64` = Apple Silicon, `x64` = Intel).
Sem conta paga da Apple a app não é notarizada: na primeira vez, **clique direito em Mynik.app → Abrir → Abrir**
(ou Ajustes do Sistema → Privacidade e Segurança → "Abrir mesmo assim"). Pelo Homebrew isto não é preciso.

**Windows:** descarrega o `Mynik_x.y.z_x64-setup.exe`. O SmartScreen pode avisar ("O Windows protegeu o PC"): **Mais informações → Executar mesmo assim**.

## Desenvolver

```bash
cd desktop && npm install
npm run dev      # arranca a web (porta 3000) e a janela
npm run build    # .app e .dmg em src-tauri/target/release/bundle
```

Precisa de Rust (`brew install rust`) e de `web/.env.local` (ver `web/.env.example`).
No Supabase, em Authentication → URL Configuration, junta `mynik://auth/callback` aos Redirect URLs.

## Publicar

`scripts/release.sh 2.0.0`: tag `v2.0.0` → o workflow [desktop.yml](../.github/workflows/desktop.yml) compila os `.dmg` e o `.exe` na GitHub Release → a cask do Homebrew é atualizada.
