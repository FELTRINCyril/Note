# Comment démarrer — mode d'emploi

Ce projet est piloté par deux outils en parallèle : **Claude Code** (qui écrit le code) et **Claude Design** (qui produit les maquettes). Voici le flux complet.

---

## Étape 0 — Ouvrir le projet dans Claude Code
Ouvre ce dossier dans Claude Code et écris simplement :

> **« Lis `CLAUDE.md` et `PLAN.md`, puis lance la phase 0. »**

Claude Code va d'abord copier les sous-agents (`cp sous-agents/*.md .claude/agents/`), lire la roadmap, puis t'annoncer la première phase.

---

## Le cycle de chaque phase (toujours le même)

1. **Claude Code annonce la phase** : son numéro, ce qu'il va construire, les sous-agents qu'il va lancer, et **si un design est nécessaire**.
2. **Deux cas :**
   - **Phase SANS 🎨** → tu réponds **`go`**, il code, il teste, il coche la phase, il s'arrête.
   - **Phase AVEC 🎨** → il **s'arrête avant de coder l'UI** et te dit exactement quoi demander à Claude Design (voir ci-dessous). Tu fais le design, tu le déposes, **puis** tu dis `go`.
3. À la fin de la phase, Claude Code fait un récap et **attend ton `go`** pour la suivante. Il n'enchaîne jamais tout seul.

---

## Quand et comment faire le design 🎨

**Tu sauras qu'il faut un design** parce que Claude Code te le dira explicitement (« 🎨 Cette phase a besoin du design… »). Les phases concernées sont aussi marquées 🎨 dans `PLAN.md`.

Quand ça arrive :

1. Ouvre **Claude Design** (dans un autre chat).
2. Donne-lui en premier ces deux fichiers :
   - `design/01-brief-design.md` (la direction artistique + les écrans + les composants)
   - `design/tokens.md` (les variables couleurs/typo/etc., déjà pré-remplies en style macOS)
3. Puis copie-lui le **brief précis de l'écran** que Claude Code t'a indiqué (ils sont listés dans `DESIGN_HANDOFF.md`, section « Briefs par phase »).
   Exemple à coller : *« À partir de `01-brief-design.md` et `tokens.md`, produis-moi l'écran E2 (barre latérale) en thème clair et sombre, avec tous ses états. »*
4. Récupère ce que Claude Design produit (idéalement du **code SwiftUI**, sinon des specs/maquettes) et **dépose-le dans le dossier indiqué**, par ex. `design/03_sidebar/`.
5. Reviens sur Claude Code et dis **`go`**. Il intègre le design (via l'agent `design-integrator`) et code la phase.

---

## Phrases-types à dire à Claude Code

| Situation | Ce que tu dis |
|---|---|
| Démarrer | « Lis `CLAUDE.md` et `PLAN.md`, lance la phase 0. » |
| Valider une phase annoncée | « **go** » |
| Design prêt et déposé | « Le design est dans `design/NN_xxx/`, **go**. » |
| Passer à la suite | « **go**, phase suivante. » |
| Faire une pause / revenir plus tard | « On s'arrête là. » (l'avancement est coché dans `PLAN.md`) |
| Reprendre une session | « Où en est-on dans `PLAN.md` ? Reprends la prochaine phase non cochée. » |
| Changer un choix | « Je veux renommer l'app en X » / « ajoute la lib Y » (il te demandera validation) |

---

## Repères
- **L'avancement** est toujours visible : les cases cochées dans `PLAN.md`.
- **L'ordre** est déjà fixé (phases 0 → 20). Tu peux sauter une phase secondaire, mais garde l'ordre pour les fondations (0 → 1 → 2) et l'éditeur.
- **Tu n'as jamais à te souvenir des détails** : chaque phase a son doc dans `docs/`, Claude Code le lit pour toi.
- **Rien ne part sans ton `go`.** Tu gardes la main à chaque étape.

---

## Résumé en une image
```
Toi ──"go"──► Claude Code annonce la phase
                     │
          phase 🎨 ? ─── non ──► code → test → coche → récap → attend "go"
                     │
                    oui
                     │
          Claude Code te dit quoi demander
                     │
        Toi ──► Claude Design (avec 01-brief-design.md + tokens.md)
                     │
        Toi ──► déposes le résultat dans design/NN_xxx/
                     │
        Toi ──"go"──► Claude Code intègre + code → test → coche → attend "go"
```
