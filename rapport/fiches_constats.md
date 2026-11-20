# Fiches de constat — Audit OWASP Juice Shop 20.4.0

**Cible :** `http://localhost:3000` (instance personnelle autorisée)
**Date de l'audit :** 2026-11-20 (preuves générées par `scripts/run_audit.sh`)
**Auditeur :** _(votre nom)_

> Les preuves ci-dessous proviennent d'une exécution réelle des scripts. Les jetons
> JWT sont tronqués et les comptes de test sont éphémères (`audit_a_*`, `audit_b_*`).

---

## Fiche 1 — IDOR / BOLA sur le panier (Critique)

| | |
|---|---|
| **Titre** | Un utilisateur authentifié peut consulter le panier d'un autre utilisateur en modifiant l'identifiant dans l'URL |
| **Criticité** | **Critique** (probabilité forte, impact important) |
| **CVSS 3.1** | **8.1** — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N` |
| **CWE** | CWE-639 (Authorization Bypass Through User-Controlled Key) |

**Preuve (2026-11-20, horodatée) :**
Comptes de test : A = panier `bid=8`, B = panier `bid=9`.
Requête émise **depuis la session de B** sur le panier de A :

```
GET /rest/basket/8   (Authorization: Bearer <token_B>)
→ HTTP 200
{"status":"success","data":{"id":8,"UserId":28,"Products":[
  {"id":1,"name":"Apple Juice (1000ml)","price":1.99,
   "BasketItem":{"ProductId":1,"BasketId":8,"quantity":1}}]}}
```

B, authentifié sur son propre compte, obtient **le contenu du panier de A** (code 200).

**Impact :** atteinte à la confidentialité (contenu des paniers d'autres clients) ;
l'intégrité est également menacée sur les routes qui ne contrôlent pas l'appartenance.
Concerne tous les utilisateurs.

**Observation complémentaire :** l'**ajout** au panier de A est refusé (`401 Invalid
BasketId`) — la route `addBasketItem` vérifie `user.bid`. La **lecture**
(`GET /rest/basket/:id`) et la mise à jour de quantité restent vulnérables faute de
contrôle d'appartenance (cf. `routes/basketItems.ts:68`).

**Reproduction :**
1. Créer deux comptes A et B.
2. Relever le `bid` du panier de A (réponse du `login`).
3. Depuis la session B, requêter `GET /rest/basket/<bid_A>`.
4. Constater la réponse 200 contenant les articles de A.

**Recommandation :** dans `routes/basketItems.ts`, rechercher la ressource avec
`{ id: req.params.id, BasketId: user?.bid }` et refuser (404/403) si aucun résultat.
**Vérification :** le test de reproduction retourne 404/403.

---

## Fiche 2 — Injection SQL dans l'authentification (Critique)

| | |
|---|---|
| **Titre** | Contournement d'authentification par injection SQL sur `/rest/user/login` |
| **Criticité** | **Critique** (probabilité forte, impact majeur) |
| **CVSS 3.1** | **9.8** — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` |
| **CWE** | CWE-89 (SQL Injection) |

**Preuve (2026-11-20, horodatée) :**

```
POST /rest/user/login
{"email":"' OR 1=1--","password":"x"}
→ HTTP 200
{"authentication":{"token":"<JWT_ADMIN_TOKEN>","bid":1,"umail":"admin@juice-sh.op"}}
```

Sans identifiants valides, l'application délivre un **jeton de session pour le compte
administrateur** `admin@juice-sh.op`.

**Impact :** accès administrateur, compromission totale de l'application et des données.

**Reproduction :**
1. Page de connexion.
2. E-mail = `' OR 1=1--`, mot de passe = `x`.
3. Connexion acceptée en tant qu'administrateur.

**Cause (code) :** `routes/login.ts:34` — requête construite par concaténation :
`SELECT * FROM Users WHERE email = '${req.body.email}' ...`.

**Recommandation :** requête **paramétrée** (`replacements: { email, pwd }`), validation
des entrées, moindre privilège de la base. **Vérification :** la charge produit une
erreur d'authentification, pas une connexion.

---

## Fiche 3 — Cross-Site Scripting (DOM) sur la recherche (Majeur)

| | |
|---|---|
| **Titre** | Exécution de script via le paramètre de recherche `q` rendu en HTML |
| **Criticité** | **Majeur** (probabilité moyenne, impact important) |
| **CVSS 3.1** | **6.1** — `CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N` |
| **CWE** | CWE-79 (Cross-site Scripting) |

**Preuve (2026-11-20, horodatée) :**
Charge utile injectée dans la recherche :

```
q = <iframe src="javascript:alert(`xss`)">
GET /rest/products/search?q=<payload encodé>  → HTTP 200
```

Le frontend Angular rend ensuite ce paramètre via `bypassSecurityTrustHtml` + `[innerHTML]`,
créant un élément `<iframe>` réel dans le DOM (`#searchValue`) et exécutant le script
(boîte de dialogue `xss`). À vérifier dans l'onglet **Elements** des DevTools.

**Cause (code) :**
- `search-result.component.ts:146` → `this.searchValue = this.sanitizer.bypassSecurityTrustHtml(queryParam)`
- `search-result.component.ts:113` → même traitement sur la description produit (**XSS stocké** potentiel)

**Impact :** vol de session, actions au nom de la victime via un lien piégé ; XSS stocké
plus dangereux (sans lien à envoyer) sur les descriptions produits.

**Reproduction :**
1. Barre de recherche → saisir la charge.
2. DevTools → Elements → rechercher `iframe` / `javascript:alert`.
3. Constater l'élément `<iframe>` et/ou l'alerte.

**Recommandation :** afficher en **texte** (`{{ searchValue }}`) sans
`bypassSecurityTrustHtml` ; si du HTML est requis, assainir (Angular / DOMPurify).
Ajouter une **CSP** en complément. **Vérification :** la charge s'affiche comme texte,
pas d'`<iframe>` ni d'alerte.

---

## Récapitulatif

| # | Faille | CWE | Criticité | CVSS | Statut (preuve 2026-11-20) |
|---|---|---|---|---|---|
| 1 | IDOR / BOLA | CWE-639 | Critique | 8.1 | Lecture confirmée (HTTP 200) |
| 2 | Injection SQL | CWE-89 | Critique | 9.8 | Confirmée (jeton admin) |
| 3 | XSS (DOM) | CWE-79 | Majeur | 6.1 | Confirmée (DOM `<iframe>`) |

Corrections détaillées : [`corrections.md`](corrections.md) · Rapport complet : [`rapport_audit.md`](rapport_audit.md)
