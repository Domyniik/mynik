#!/usr/bin/env bash
# Publica uma versão da app desktop do Mynik (Tauri, Mac + Windows):
#   1. põe a versão em web/, desktop/ e no tauri.conf.json, faz commit e tag vX.Y.Z
#   2. o push da tag corre o workflow .github/workflows/desktop.yml, que compila
#      os .dmg (Apple Silicon e Intel) e o .exe e os publica na GitHub Release
#   3. espera pelo workflow e atualiza a cask em Domyniik/homebrew-tap
#
# Uso: scripts/release.sh <versão>        (ex.: scripts/release.sh 2.0.0)
# Instalar no Mac depois de publicar: brew install --cask domyniik/tap/mynik
set -euo pipefail

VERSION="${1:?Uso: scripts/release.sh <versão>}"
TAG="v$VERSION"
APP_REPO="Domyniik/mynik"
TAP_REPO="Domyniik/homebrew-tap"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "✗ Há alterações por gravar. Faz commit primeiro." >&2
    exit 1
fi

echo "▸ Versão $VERSION"
sed -i '' -E "s/^version = \".*\"/version = \"$VERSION\"/" desktop/src-tauri/Cargo.toml
for f in desktop/src-tauri/tauri.conf.json desktop/package.json web/package.json; do
    sed -i '' -E "1,10s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" "$f"
done
(cd desktop/src-tauri && cargo update -p mynik --offline -q 2>/dev/null || true)
if [[ -n "$(git status --porcelain)" ]]; then
    git commit -qam "chore: versão $VERSION"
fi
git tag "$TAG"
git push -q origin HEAD "$TAG"

echo "▸ A compilar no GitHub Actions (Mac e Windows)…"
sleep 10
RUN_ID="$(gh run list --repo "$APP_REPO" --workflow desktop.yml --branch "$TAG" --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$RUN_ID" --repo "$APP_REPO" --exit-status

echo "▸ A atualizar a cask em $TAP_REPO…"
gh release download "$TAG" --repo "$APP_REPO" --pattern "*.dmg" --dir "$WORK"
ARM_SHA="$(shasum -a 256 "$WORK/Mynik_${VERSION}_aarch64.dmg" | awk '{print $1}')"
INTEL_SHA="$(shasum -a 256 "$WORK/Mynik_${VERSION}_x64.dmg" | awk '{print $1}')"

gh repo clone "$TAP_REPO" "$WORK/tap" -- -q
cat > "$WORK/tap/Casks/mynik.rb" <<CASK
cask "mynik" do
  arch arm: "aarch64", intel: "x64"

  version "$VERSION"
  sha256 arm:   "$ARM_SHA",
         intel: "$INTEL_SHA"

  url "https://github.com/$APP_REPO/releases/download/v#{version}/Mynik_#{version}_#{arch}.dmg"
  name "Mynik"
  desc "Dashboard pessoal: finanças, contas a pagar, loja, projetos e notas"
  homepage "https://github.com/$APP_REPO"

  depends_on macos: ">= :big_sur"

  app "Mynik.app"

  # A app não é notarizada pela Apple: retira a quarentena para abrir sem bloqueio.
  postflight_steps do
    if_path_exists "{{appdir}}/Mynik.app" do
      run "/usr/bin/xattr",
          args: ["-dr", "com.apple.quarantine", "{{appdir}}/Mynik.app"]
    end
  end

  uninstall quit: "com.domynik.mynik.desktop"

  zap trash: [
    "~/Library/Application Support/com.domynik.mynik.desktop",
    "~/Library/Caches/com.domynik.mynik.desktop",
    "~/Library/WebKit/com.domynik.mynik.desktop",
  ]
end
CASK
git -C "$WORK/tap" commit -q -am "mynik $VERSION (app desktop Tauri)"
git -C "$WORK/tap" push -q

echo "✓ Publicado. Para atualizar: brew update && brew upgrade --cask mynik"
