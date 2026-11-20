#!/usr/bin/env bash
# Phase 3 - Audit de code : localise dans les sources Juice Shop les mecanismes
# a l'origine des 3 vulnerabilites observees en phase 2.
set -uo pipefail

WORK_ROOT="/workspaces"
[ -d "$WORK_ROOT" ] || WORK_ROOT="$HOME"
JS_DIR="$(find "$WORK_ROOT" -maxdepth 2 -type f -name package.json -path '*juice-shop*' -printf '%h\n' 2>/dev/null | head -n1)"
JS_DIR="${JS_DIR:-$WORK_ROOT/juice-shop}"

if [ ! -d "$JS_DIR" ]; then
  echo "Sources Juice Shop introuvables sous $WORK_ROOT" >&2
  exit 1
fi
cd "$JS_DIR"
echo "=== Phase 3 : Audit de code (sources: $JS_DIR) ==="

echo
echo "--- 3.1 Controle d'acces (IDOR/BOLA) : routes/basketItems.ts ---"
echo "Fonctions qui recuperent l'utilisateur authentifie / comparent a user.bid :"
grep -n "authenticatedUsers\|user.bid\|findOne" routes/basketItems.ts || true
echo ">> addBasketItem compare Number(user.bid) a l'id envoye."
echo ">> quantityCheckBeforeBasketItemUpdate cherche l'article par id SEUL :"
echo ">>   findOne({ where: { id: req.params.id } })  -> aucune verif d'appartenance."
echo ">> Correction : where: { id: req.params.id, BasketId: user?.bid }"

echo
echo "--- 3.2 Injection SQL : routes/login.ts ---"
grep -n "SELECT\|sequelize.query\|req.body.email" routes/login.ts || true
echo ">> Requete construite par concatenation (interpolation \${req.body.email})."
echo ">> Correction : requete parametree (replacements: { email, pwd })."

echo
echo "--- 3.3 XSS : frontend/src/app/search-result/ ---"
grep -n "bypassSecurityTrustHtml" frontend/src/app/search-result/search-result.component.ts || true
grep -n "searchValue" frontend/src/app/search-result/search-result.component.html 2>/dev/null \
  || find frontend/src/app/search-result -name '*.html' -exec grep -n "searchValue" {} +
echo ">> queryParam (parametre q de l'URL) passe dans bypassSecurityTrustHtml"
echo ">> puis affiche via [innerHTML] -> DOM-XSS."
echo ">> Correction : afficher en texte ({{ searchValue }}) sans bypass, ou DOMPurify."

echo
echo "=== Phase 3 terminee. Voir rapport/corrections.md pour les patches detailles. ==="
