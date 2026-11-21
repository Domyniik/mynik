#!/usr/bin/env bash
# Publica uma versão do Mynik para macOS:
#   1. compila a app (Release, universal) a partir de um commit limpo
#   2. cria a release no GitHub com Mynik-<versão>.zip
#   3. atualiza a cask em Domyniik/homebrew-tap
#
# Uso: scripts/release.sh <versão> [commit]
#   scripts/release.sh 0.2.0            # usa origin/main
#   scripts/release.sh 0.1.0 0ee1452    # usa um commit específico
#
# Instalação depois de publicar:
#   brew install --cask domyniik/tap/mynik
set -euo pipefail

VERSION="${1:?Uso: scripts/release.sh <versão> [commit]}"
REF="${2:-origin/main}"
TAG="v$VERSION"
APP_REPO="Domyniik/mynik"
TAP_REPO="Domyniik/homebrew-tap"

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
WORK="$(mktemp -d)"
SRC="$WORK/src"

cleanup() {
    git -C "$ROOT" worktree remove --force "$SRC" 2>/dev/null || true
}
trap cleanup EXIT

git -C "$ROOT" fetch -q origin
COMMIT="$(git -C "$ROOT" rev-parse "$REF^{commit}")"
echo "▸ Mynik $VERSION a partir de ${COMMIT:0:7}"

# Compila numa worktree limpa, para não depender do estado da pasta de trabalho.
git -C "$ROOT" worktree add --detach -q "$SRC" "$COMMIT"
cd "$SRC"
# Configuração do Supabase (fora do git): sem ela, a versão publicada não tem login nem sync.
if [[ -f "$ROOT/Config/Supabase.xcconfig" ]]; then
    cp "$ROOT/Config/Supabase.xcconfig" "$SRC/Config/Supabase.xcconfig"
else
    echo "⚠︎ Sem Config/Supabase.xcconfig: esta versão sai sem login nem sync."
fi
xcodegen generate --quiet

# Assinatura: certificado "Apple Development" (Personal Team, grátis), definido
# no project.yml. É o que permite o App Group partilhado com os widgets; a app
# continua sem notarização (a cask remove a quarentena).
echo "▸ A compilar (Release, arm64 + x86_64)…"
xcodebuild \
    -project Mynik.xcodeproj \
    -scheme Mynik \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$WORK/build" \
    MARKETING_VERSION="$VERSION" \
    build -quiet

APP="$WORK/build/Build/Products/Release/Mynik.app"
codesign --verify --deep --strict "$APP"
test -d "$APP/Contents/PlugIns/MynikWidgets.appex"
ZIP="$WORK/Mynik-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "▸ $(basename "$ZIP") · sha256 $SHA256"

echo "▸ A publicar a release $TAG…"
gh release create "$TAG" "$ZIP" \
    --repo "$APP_REPO" \
    --target "$COMMIT" \
    --title "Mynik $VERSION" \
    --notes "Instalar no Mac: \`brew install --cask domyniik/tap/mynik\`

Ver o [CHANGELOG](https://github.com/$APP_REPO/blob/$TAG/CHANGELOG.md)."

echo "▸ A atualizar a cask em $TAP_REPO…"
gh repo clone "$TAP_REPO" "$WORK/tap" -- -q
CASK="$WORK/tap/Casks/mynik.rb"
sed -i '' \
    -e "s/^  version \".*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" \
    "$CASK"
git -C "$WORK/tap" commit -q -am "mynik $VERSION"
git -C "$WORK/tap" push -q

echo "✓ Publicado. Para atualizar: brew update && brew upgrade --cask mynik"
