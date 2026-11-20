# TP – Audit d'une application web (OWASP Juice Shop)

Dépôt **automatisé** pour le TP d'audit de sécurité (UVSQ, M2 IRS, Cybersécurité –
*Audits de sécurité 2026/2027*, Dr. GARAH Abdelhamid).

Il installe et démarre **OWASP Juice Shop 20.4.0** puis automatise l'**observation**
des phases 1 à 3 du TP (reconnaissance, tests de vulnérabilités, audit de code) et
fournit un modèle de rapport (phase 4).

> ⚠️ **Portée légale.** Toutes les manipulations se font **exclusivement sur votre
> propre instance** Juice Shop, sur `localhost`. N'auditez jamais une cible pour
> laquelle vous n'avez pas d'autorisation (cf. phase 4.5 du TP).

---

## Démarrage rapide

### Dans un GitHub Codespace (recommandé)
1. `Use this template` → créez votre dépôt.
2. Ouvrez un **Codespace** (`Create codespace on master`, 2 cores). Le
   `postCreateCommand` installe Juice Shop automatiquement.
3. Démarrez l'application :
   ```bash
   bash .devcontainer/start-juice-shop.sh
   ```
4. Onglet **Ports** → port **3000** → *Open in Browser*.

### En local
```bash
bash .devcontainer/install-juice-shop.sh   # télécharge Juice Shop 20.4.0
bash .devcontainer/start-juice-shop.sh     # démarre sur le port 3000
```

---

## Lancer l'audit automatisé

```bash
# tout d'affilée (phases 1 → 3)
bash scripts/run_audit.sh

# ou phase par phase
bash scripts/phase1_reconnaissance.sh   # en-têtes HTTP, scan nmap
bash scripts/phase2_tests.sh            # IDOR/BOLA, injection SQL, XSS
bash scripts/phase3_audit_code.sh       # localisation des causes dans le code
```

Les **preuves horodatées** (sorties curl, scan nmap, logs des tests) sont
enregistrées dans `preuves/`.

---

## Structure du dépôt

| Chemin | Rôle |
|---|---|
| `.devcontainer/devcontainer.json` | Config Codespace (Node 22, port 3000) |
| `.devcontainer/install-juice-shop.sh` | Phase 0 – installation de Juice Shop 20.4.0 |
| `.devcontainer/start-juice-shop.sh` | Phase 0 – démarrage + vérification d'accès |
| `scripts/phase1_reconnaissance.sh` | Phase 1 – en-têtes HTTP, scan nmap |
| `scripts/phase2_tests.sh` | Phase 2 – tests IDOR / SQLi / XSS |
| `scripts/phase3_audit_code.sh` | Phase 3 – audit de code des 3 failles |
| `scripts/run_audit.sh` | Orchestrateur des phases 1→3 |
| `rapport/rapport_audit.md` | Phase 4 – rapport d'audit (modèle rempli) |
| `rapport/corrections.md` | Patches détaillés des 3 vulnérabilités |
| `preuves/` | Preuves horodatées générées par les scripts |

---

## Les trois vulnérabilités étudiées

| Faille | Cause | CWE | Criticité | CVSS 3.1 |
|---|---|---|---|---|
| IDOR / BOLA | Absence de vérification d'autorisation côté serveur | CWE-639 | Critique | 8.1 |
| Injection SQL | Requête d'authentification construite par concaténation | CWE-89 | Critique | 9.8 |
| XSS (DOM) | Contenu non fiable inséré en HTML (`bypassSecurityTrustHtml`) | CWE-79 | Majeur | 6.1 |

Détails, preuves et corrections : voir [`rapport/`](rapport/).
