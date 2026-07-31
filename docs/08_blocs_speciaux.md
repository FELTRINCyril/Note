# Phase 8 — Blocs spéciaux

## Objectif
Implémenter les types de blocs non-texte-simple : code (avec coloration), citation, callout, listes (puces/numérotées/tâches à cocher), divider, et **tableaux**.

## Prérequis
Phases 5, 6, 7.

## 🎨 Design
Léger à modéré. Réutiliser les tokens. Un design optionnel des tableaux et callouts peut être demandé ; sinon rendu par défaut soigné.

---

## Spécifications fonctionnelles

### Listes
- **À puces**, **numérotées**, **à cocher (todo)**, et variantes (tirets/pointage évoquées par Cyril → gérées comme styles de puce).
- **Imbrication** : Tab pour indenter, ⇧Tab pour désindenter (via `parent/children` du modèle).
- Renumérotation auto des listes numérotées.
- Case à cocher fonctionnelle (bascule `attributes.checked`), style barré/estompé quand cochée.

### Bloc de code
- Police mono, fond dédié.
- **Choix du langage** (menu) et **coloration syntaxique** (proposer une lib légère à Cyril, ex. Highlightr/Splash, ou un highlighter maison minimal).
- Bouton « copier ».

### Citation & callout
- Citation : barre latérale gauche, texte en retrait.
- Callout : bloc avec icône/emoji + fond coloré + texte.

### Divider
- Ligne de séparation simple (insérable via `/` ou `---`).

### Tableaux
- Insertion d'un tableau (n×m), ajout/suppression de lignes/colonnes.
- Édition de cellule (texte simple d'abord ; texte riche possible plus tard).
- Redimensionnement de colonnes.
- Navigation clavier entre cellules (Tab).

## Détails techniques
- Chaque type = une vue dans `SlateEditor` branchée sur le routeur `BlockView`.
- Listes imbriquées : rendu récursif via `children`.
- Tableau : structure dédiée dans `attributes` (lignes/colonnes/cellules) ou sous-blocs — trancher avec `data-modeler`/`editor-specialist`.
- Coloration code : service dans `SlateServices` (async si nécessaire).

## Sous-agents
- `editor-specialist` : listes/imbrication, code, citation, callout, tableau.
- `data-modeler` : structure de données du tableau si dédiée.
- `swift-reviewer` : indentation, renumérotation, bascule tâche, add/remove lignes-colonnes, persistance.

## Critères d'acceptation
- Les 3 types de listes + imbrication (Tab/⇧Tab) fonctionnent.
- Cases à cocher fonctionnelles et persistées.
- Bloc code avec choix de langage + coloration + copie.
- Tableaux éditables (cellules, lignes, colonnes) et persistés.
- Citation, callout, divider rendus correctement.

## Vérification
Tests logique listes/tableaux + essai manuel de chaque bloc. Cocher Phase 8.
