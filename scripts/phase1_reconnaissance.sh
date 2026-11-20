#!/usr/bin/env bash
# Phase 1 - Reconnaissance, surface d'attaque et scan (localhost uniquement).
# Toutes les preuves sont horodatees et enregistrees dans preuves/.
set -euo pipefail

BASE="${BASE:-http://localhost:3000}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/preuves"
mkdir -p "$OUT"
TS="$(date +%Y%m%d_%H%M%S)"
STAMP="$(date -Iseconds)"

echo "=== Phase 1 : Reconnaissance (cible $BASE, $STAMP) ==="

# 1.4 - En-tetes HTTP de securite
echo "--- 1.4 En-tetes HTTP ---"
HDR="$OUT/phase1_headers_${TS}.txt"
{
  echo "# Capture horodatee : $STAMP"
  echo "# Cible : $BASE"
  echo "## GET $BASE"
  curl -sS -D - -o /dev/null "$BASE"
  echo
  echo "## OPTIONS $BASE"
  curl -sS -D - -o /dev/null -X OPTIONS "$BASE"
  echo
  echo "## Titre de la page"
  curl -sS "$BASE" | grep -o "<title>[^<]*</title>" || true
} | tee "$HDR"

echo
echo "--- Presence des en-tetes de securite ---"
for h in "X-Content-Type-Options" "X-Frame-Options" "Content-Security-Policy" "Strict-Transport-Security"; do
  if grep -iq "^$h:" "$HDR"; then
    echo "  [present] $h"
  else
    echo "  [absent ] $h"
  fi
done

# 1.5 - Scan Nmap (si disponible)
echo
echo "--- 1.5 Scan Nmap ---"
if command -v nmap >/dev/null 2>&1; then
  SCAN="$OUT/scan_nmap_${TS}.txt"
  echo "Scan des services sur le port 3000 ..."
  nmap -sV -p 3000 -oN "$SCAN" localhost | grep -vE '^SF|unrecognized|NEXT SERVICE FINGERPRINT' || true
  echo "Resultat brut conserve : $SCAN"
else
  echo "nmap non installe. Installation :"
  echo "   sudo apt-get update && sudo apt-get install -y nmap"
fi

echo
echo "=== Phase 1 terminee. Preuves dans $OUT ==="
