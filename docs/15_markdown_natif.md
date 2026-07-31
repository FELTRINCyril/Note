# Phase 15 — Markdown natif à la frappe

## Objectif (v2)
Convertir automatiquement les raccourcis markdown pendant la frappe : `# ` → titre, `**gras**`, `- ` → puce, `1. ` → liste numérotée, `[] ` → tâche, `> ` → citation, `` ``` `` → code, `---` → divider.

## Prérequis
Phases 5–8 (éditeur + blocs + formatage).

## 🎨 Design
Non requis.

---

## Spécifications fonctionnelles
- **Déclencheurs de bloc** en début de ligne :
  - `# ` … `###### ` → H1…H6
  - `- ` ou `* ` → puce ; `1. ` → numérotée ; `[] ` / `[x] ` → tâche
  - `> ` → citation ; ` ``` ` → bloc code ; `---` → divider
- **Formatage inline** à la frappe : `**gras**`, `*italique*`, `` `code` ``, `~~barré~~`, `==surlignage==`.
- La syntaxe est **consommée** (retirée) une fois convertie.
- Annulable (⌘Z) proprement.
- Coller du markdown → conversion optionnelle en blocs (réglage).

## Détails techniques
- `MarkdownShortcutEngine` dans `SlateEditor` : détecte les motifs à la frappe (espace/entrée déclencheurs) et applique conversion de bloc ou marque inline.
- Réutilise le registre de types (Phase 6) et le `FormattingController` (Phase 7).
- Attention aux conflits avec le menu `/` et à l'annulation.

## Sous-agents
- `editor-specialist` : moteur de raccourcis markdown.
- `swift-reviewer` : tests de chaque motif, consommation de la syntaxe, undo, coller markdown.

## Critères d'acceptation
- Tous les motifs listés se convertissent correctement à la frappe.
- ⌘Z annule proprement une conversion.

## Vérification
Suite de tests par motif + essai manuel. Cocher Phase 15.
