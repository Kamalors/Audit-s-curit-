# Corrections détaillées (Phase 3)

Patches des trois vulnérabilités dans les sources de Juice Shop 20.4.0.
Chaque correction est accompagnée de sa **vérification** : une correction n'est
validée que si le test qui reproduisait la faille **ne fonctionne plus**.

---

## 1. IDOR / BOLA — `routes/basketItems.ts` (CWE-639)

**Cause.** `quantityCheckBeforeBasketItemUpdate()` recherche l'article par son
identifiant **seul**, sans vérifier qu'il appartient au panier de l'utilisateur :

```ts
// Vulnérable
const item = await BasketItemModel.findOne({ where: { id: req.params.id } })
const user = security.authenticatedUsers.from(req)
// user est récupéré mais jamais comparé au propriétaire de l'article
```

**Correction.** Inclure l'appartenance au panier dans la recherche :

```ts
const user = security.authenticatedUsers.from(req)
const item = await BasketItemModel.findOne({
  where: { id: req.params.id, BasketId: user?.bid }
})
if (item == null) {
  return res.status(404).send('{"error":"No such item found"}')
}
```

> Vérifier l'**existence** d'une ressource n'est pas vérifier les **droits** dessus.
> L'identifiant est contrôlé par le client, donc modifiable : le serveur doit
> vérifier les droits à chaque requête, en lecture **comme** en écriture.

**Vérification.** Rejouer le test d'écriture de 2.1 depuis B sur le panier A →
l'article n'est pas trouvé, requête refusée (404/403), rien n'est modifié.

---

## 2. Injection SQL — `routes/login.ts` (CWE-89)

**Cause.** La requête d'authentification est construite par **concaténation**
(interpolation `${...}`) :

```ts
// Vulnérable
models.sequelize.query(
  `SELECT * FROM Users
   WHERE email = '${req.body.email || ''}'
   AND password = '${security.hash(req.body.password || '')}'
   AND deletedAt IS NULL`,
  { model: UserModel, plain: true })
```

Avec `email = ' OR 1=1--`, la requête devient :

```sql
SELECT * FROM Users WHERE email = '' OR 1=1--' AND password = '...' AND deletedAt IS NULL
```

`OR 1=1` est toujours vrai, `--` commente le test du mot de passe → le premier
utilisateur (souvent l'admin) est retourné.

**Correction.** Requête **paramétrée** (paramètres nommés Sequelize) :

```ts
models.sequelize.query(
  `SELECT * FROM Users
   WHERE email = :email AND password = :pwd
   AND deletedAt IS NULL`,
  { replacements: {
      email: req.body.email || '',
      pwd: security.hash(req.body.password || '')
    },
    model: UserModel, plain: true })
```

> La structure de la requête est envoyée d'abord, les valeurs ensuite : la base
> traite toujours la valeur comme une **donnée**, jamais comme du SQL. La validation
> des entrées est une couche complémentaire, pas un remplacement.

**Vérification.** Rejouer la charge de 2.2 → erreur d'authentification, pas de connexion.

---

## 3. XSS (DOM) — `frontend/src/app/search-result/` (CWE-79)

**Cause.** Le paramètre `q` de l'URL (contrôlé par l'utilisateur) est marqué comme
sûr puis affiché en HTML :

```ts
// search-result.component.ts (vulnérable, ligne ~146)
this.searchValue = this.sanitizer.bypassSecurityTrustHtml(queryParam)
```
```html
<!-- search-result.component.html -->
<span id="searchValue" [innerHTML]="searchValue"></span>
```

`bypassSecurityTrustHtml` **désactive** l'assainissement d'Angular ; `[innerHTML]`
interprète la chaîne comme du HTML → le code est exécuté.

**Correction.** Ne plus contourner l'assainissement et afficher en **texte** :

```ts
public searchValue?: string
// ...
this.searchValue = queryParam   // plus de bypass
```
```html
<span id="searchValue">{{ searchValue }}</span>
```

> `innerHTML` interprète la chaîne comme du HTML (peut exécuter du code) ;
> `textContent` / l'interpolation `{{ }}` l'affichent comme du texte brut.
> Si du HTML est réellement nécessaire, laisser Angular assainir ou utiliser
> **DOMPurify**. Une **Content-Security-Policy** limite l'exploitation mais ne
> corrige pas la cause.

**Pour aller plus loin.** `trustProductDescription()` (ligne ~113) marque aussi la
description produit comme sûre → risque de **XSS stocké** (plus dangereux, sans lien
piégé à envoyer).

**Vérification.** Rejouer la charge de 2.3 → elle apparaît comme **texte**, sans
élément `<iframe>` dans le DOM ni boîte de dialogue.

---

## Synthèse

| Vulnérabilité | Où | Correction principale | Vérification |
|---|---|---|---|
| IDOR/BOLA | `routes/basketItems.ts` | Autorisation par ressource (`BasketId: user?.bid`) | Test d'écriture 2.1 refusé |
| Injection SQL | `routes/login.ts` | Requêtes paramétrées | Charge 2.2 ne connecte plus |
| XSS | `search-result.component.*` | Affichage en texte, pas de bypass, CSP | Charge 2.3 affichée en texte |
