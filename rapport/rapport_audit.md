# Rapport d'audit de sécurité – OWASP Juice Shop 20.4.0

**Auditeur :** _(votre nom)_  **Date :** _(à compléter)_
**Périmètre :** instance locale OWASP Juice Shop 20.4.0, `http://localhost:3000`
**Démarche :** audit boîte grise – reconnaissance, tests manuels/automatisés, audit de code.

---

## 1. Synthèse managériale

L'audit de l'application a mis en évidence **trois vulnérabilités**, dont **deux
critiques**. En l'état :

- les **données de tout client** (paniers, articles) peuvent être consultées par un
  autre client authentifié ;
- un **accès administrateur** peut être obtenu **sans mot de passe** via une
  injection SQL ;
- un lien piégé peut exécuter du **code JavaScript** dans le navigateur d'une victime.

Ceci expose l'entreprise à une **fuite de données**, une **compromission de comptes**
et des **sanctions réglementaires**. Les correctifs sont simples et rapides.

**Trois actions prioritaires :**
1. Vérifier les autorisations côté serveur sur chaque ressource du panier (IDOR).
2. Passer l'authentification en requêtes paramétrées (injection SQL).
3. Supprimer le contournement de l'assainissement Angular à l'affichage (XSS).

**Niveau de risque global : Élevé.**

---

## 2. Périmètre et démarche

- **Cible :** `http://localhost:3000` (instance personnelle, autorisée).
- **Hors périmètre :** toute autre cible, les ports internes du Codespace.
- **Outils :** navigateur (DevTools), `curl`, `nmap`, lecture du code source.
- **Preuves :** sorties horodatées conservées dans `preuves/`.

---

## 3. Constats classés par criticité

### 3.1 — [Critique] IDOR / BOLA sur le panier — CWE-639

| | |
|---|---|
| **Titre** | Un utilisateur authentifié peut consulter (et selon la route modifier) le panier d'un autre utilisateur en changeant l'identifiant |
| **Criticité** | Critique (probabilité forte, impact important) — CVSS 3.1 : **8.1** |
| **Vecteur CVSS** | `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N` |
| **Preuve** | Requête `GET /rest/basket/<ID_A>` émise depuis la session du compte B → réponse **200** contenant les articles du compte A. Voir `preuves/phase2_tests_*.txt`, horodatée. |
| **Impact** | Atteinte à la confidentialité (contenu des paniers) et à l'intégrité (quantités). Concerne tous les utilisateurs. |
| **Reproduction** | 1. Créer deux comptes A et B. 2. Relever le `bid` du panier de A. 3. Depuis la session B, rejouer la requête de consultation avec cet identifiant. 4. La réponse contient les articles de A. |
| **Recommandation** | Dans `routes/basketItems.ts`, rechercher la ressource avec son identifiant **ET** le panier de l'utilisateur authentifié (`BasketId: user?.bid`), refuser si aucun résultat. **Vérification :** le test de reproduction retourne 404/403. |

> Note : sur l'instance 20.4.0, la route d'**ajout** (`addBasketItem`) vérifie déjà
> `user.bid` (réponse `401 Invalid BasketId`). La **lecture** `GET /rest/basket/:id`
> reste vulnérable. La correction doit couvrir chaque opération.

### 3.2 — [Critique] Injection SQL dans l'authentification — CWE-89

| | |
|---|---|
| **Titre** | Contournement d'authentification par injection SQL sur la connexion |
| **Criticité** | Critique (probabilité forte, impact majeur) — CVSS 3.1 : **9.8** |
| **Vecteur CVSS** | `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` |
| **Preuve** | `POST /rest/user/login` avec `email = ' OR 1=1--`, `password = x` → réponse **200** avec un jeton JWT pour `admin@juice-sh.op`. Voir `preuves/phase2_tests_*.txt`. |
| **Impact** | Accès administrateur sans identifiants valides ; compromission totale de l'application et des données. |
| **Reproduction** | 1. Page de connexion. 2. E-mail = `' OR 1=1--`, mot de passe = `x`. 3. Connexion acceptée en tant qu'administrateur. |
| **Recommandation** | Dans `routes/login.ts`, remplacer la requête concaténée par une requête **paramétrée** (`replacements: { email, pwd }`). Appliquer validation des entrées et moindre privilège de la base. **Vérification :** la charge ne connecte plus (erreur d'authentification). |

### 3.3 — [Majeur] Cross-Site Scripting (DOM) sur la recherche — CWE-79

| | |
|---|---|
| **Titre** | Exécution de script via le paramètre de recherche (`q`) rendu en HTML |
| **Criticité** | Majeur (probabilité moyenne, impact important) — CVSS 3.1 : **6.1** |
| **Vecteur CVSS** | `CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N` |
| **Preuve** | Charge `<iframe src="javascript:alert(\`xss\`)">` dans la recherche → élément `<iframe>` créé dans le DOM (`#searchValue`) et exécution du script. Code : `search-result.component.ts:146` (`bypassSecurityTrustHtml`) + `[innerHTML]`. |
| **Impact** | Vol de session, actions au nom de la victime, via un lien piégé. XSS **stocké** possible sur les descriptions produits (`:113`). |
| **Reproduction** | 1. Barre de recherche. 2. Saisir la charge. 3. Une boîte `xss` s'affiche / `<iframe>` présent dans le DOM. |
| **Recommandation** | Afficher la valeur en **texte** (`{{ searchValue }}`) sans `bypassSecurityTrustHtml` ; si du HTML est nécessaire, laisser Angular assainir ou utiliser **DOMPurify**. Ajouter une **CSP** en complément (ne corrige pas la cause). **Vérification :** la charge apparaît comme texte, pas d'`<iframe>` ni d'alerte. |

---

## 4. Plan d'action priorisé

| Priorité | Action | Composant | Effort | Vérification |
|---|---|---|---|---|
| 1 | Requêtes paramétrées | `routes/login.ts` | Faible | Charge SQLi rejetée |
| 2 | Contrôle d'autorisation par ressource | `routes/basketItems.ts` | Faible | IDOR en 404/403 |
| 3 | Affichage en texte + CSP | `search-result.component.*` | Faible | Charge XSS en texte |

---

## 5. Grille de criticité utilisée

| | Impact limité | Impact important | Impact majeur |
|---|---|---|---|
| **Probabilité forte** | Majeur | Critique | Critique |
| **Probabilité moyenne** | Mineur | Majeur | Critique |
| **Probabilité faible** | Information | Mineur | Majeur |

---

## 6. Bonnes pratiques retenues

- Tester uniquement des environnements **autorisés**.
- Vérifier les autorisations **côté serveur**, même si l'UI masque des fonctions.
- Ne jamais considérer une entrée utilisateur comme fiable.
- Examiner les **réponses HTTP**, pas seulement le rendu visuel.
- Valider qu'une correction **empêche réellement** la reproduction de la faille.
