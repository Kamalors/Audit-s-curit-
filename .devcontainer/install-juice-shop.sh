#!/usr/bin/env bash
# Phase 0 - Installation automatique de OWASP Juice Shop 20.4.0
# A partir de la distribution precompilee (meme version que le TP).
set -euo pipefail

JUICE_VERSION="20.4.0"
WORK_ROOT="/workspaces"
[ -d "$WORK_ROOT" ] || WORK_ROOT="$HOME"
JS_DIR="$WORK_ROOT/juice-shop"

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  PKG_ARCH="x64" ;;
  aarch64|arm64) PKG_ARCH="arm64" ;;
  *) echo "Architecture non geree: $ARCH" >&2; exit 1 ;;
esac

TARBALL="juice-shop-${JUICE_VERSION}_node${NODE_MAJOR}_linux_${PKG_ARCH}.tgz"
URL="https://github.com/juice-shop/juice-shop/releases/download/v${JUICE_VERSION}/${TARBALL}"

if [ -f "$JS_DIR/package.json" ]; then
  echo "[install] Juice Shop deja present dans $JS_DIR"
  exit 0
fi

echo "[install] Telechargement de $TARBALL ..."
tmp="$(mktemp -d)"
curl -fSL -o "$tmp/js.tgz" "$URL"
echo "[install] Extraction ..."
tar xzf "$tmp/js.tgz" -C "$tmp"
src="$(find "$tmp" -maxdepth 1 -type d -name 'juice-shop_*' | head -n1)"
mkdir -p "$JS_DIR"
cp -a "$src/." "$JS_DIR/"
rm -rf "$tmp"

echo "[install] Termine. Juice Shop installe dans $JS_DIR"
echo "[install] Demarrez avec : bash .devcontainer/start-juice-shop.sh"
