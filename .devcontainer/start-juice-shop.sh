#!/usr/bin/env bash
# Phase 0 - Demarrage de OWASP Juice Shop en arriere-plan + verification d'acces.
set -euo pipefail

WORK_ROOT="/workspaces"
[ -d "$WORK_ROOT" ] || WORK_ROOT="$HOME"
JS_DIR="$(find "$WORK_ROOT" -maxdepth 2 -type f -name package.json -path '*juice-shop*' -printf '%h\n' 2>/dev/null | head -n1)"
JS_DIR="${JS_DIR:-$WORK_ROOT/juice-shop}"
PORT=3000
LOG="/tmp/juice-shop.log"

if [ ! -f "$JS_DIR/package.json" ]; then
  echo "Juice Shop introuvable. Lancez d'abord : bash .devcontainer/install-juice-shop.sh" >&2
  exit 1
fi

if curl -s -o /dev/null "http://localhost:${PORT}"; then
  echo "Juice Shop semble deja demarre sur le port ${PORT}."
  exit 0
fi

echo "[start] Lancement de Juice Shop (logs: $LOG) ..."
( cd "$JS_DIR" && NODE_ENV=unsafe nohup node build/app.js >"$LOG" 2>&1 & )

echo -n "[start] Attente de la disponibilite du port ${PORT} "
for i in $(seq 1 60); do
  if curl -s -o /dev/null "http://localhost:${PORT}"; then
    echo ""
    echo "Juice Shop est accessible sur le port ${PORT}"
    echo "Ouvrez l'onglet Ports -> port ${PORT} -> Open in Browser."
    exit 0
  fi
  echo -n "."
  sleep 2
done

echo ""
echo "[start] Echec: le port ${PORT} ne repond pas apres 120s. Consultez $LOG" >&2
tail -n 30 "$LOG" >&2 || true
exit 1
