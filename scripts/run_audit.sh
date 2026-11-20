#!/usr/bin/env bash
# Orchestrateur : execute les phases 1 -> 3 d'affilee contre l'instance locale.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "######## AUDIT AUTOMATISE - OWASP Juice Shop (localhost) ########"
echo "Rappel : n'auditez que votre propre instance (Phase 4.5 du TP)."
echo

if ! curl -s -o /dev/null http://localhost:3000; then
  echo "Juice Shop n'est pas accessible sur le port 3000."
  echo "Demarrez-le d'abord : bash .devcontainer/start-juice-shop.sh"
  exit 1
fi

bash "$DIR/phase1_reconnaissance.sh"
echo; echo
bash "$DIR/phase2_tests.sh"
echo; echo
bash "$DIR/phase3_audit_code.sh"

echo
echo "######## Termine. Preuves dans preuves/, rapport dans rapport/ ########"
