# Phase 3 — Coquille app & barre latérale

## Objectif
Construire la fenêtre principale à 3 colonnes façon Notes d'Apple, avec une barre latérale fonctionnelle : arborescence pliable de dossiers/sous-dossiers, favoris, accès rapide aux réglages.

## Prérequis
Phase 2 (modèle de données).

## 🎨 DESIGN REQUIS
**Avant de coder l'UI, demander à Claude Design :**
- La fenêtre principale à 3 colonnes (sidebar | liste de notes | éditeur), proportions et comportements de collapse.
- La **barre latérale** : sections (Favoris, Espaces, Dossiers récursifs), style des lignes, icônes, indentation des sous-dossiers, chevrons de pliage, état sélectionné/survol.
- Le bouton/accès **réglages** et le sélecteur de workspace (placeholder).
- Boutons d'action : nouveau dossier, nouvelle note.

Déposer le livrable dans `design/03_sidebar/`. Dire `go` une fois prêt. Détails de format → `DESIGN_HANDOFF.md`.

---

## Spécifications fonctionnelles
- `NavigationSplitView` 3 colonnes. Colonnes repliables (comme Notes).
- Barre latérale :
  - Section **Favoris** (notes marquées favorites).
  - Section **Espaces / Dossiers** : arbre récursif pliable. Un dossier peut contenir sous-dossiers + notes.
  - Compteurs optionnels (nb de notes par dossier).
  - Menu contextuel (clic droit) : nouveau sous-dossier, renommer, changer d'icône, supprimer.
- Création : « + » pour nouveau dossier / nouvelle note dans le dossier sélectionné.
- Réorganisation par glisser-déposer des dossiers (peut être reporté à une sous-étape).
- Sélection d'un dossier → met à jour `AppState.selectedFolder` → alimente la colonne liste (Phase 4).
- Persistance de l'état plié/déplié.

## Détails techniques
- Vue `SidebarView` dans `SlateFeatures`, alimentée par `@Query` sur `Space`/`Folder`.
- Arbre récursif : vue `FolderRow` qui s'auto-appelle pour les `subfolders`.
- Utiliser les composants de `SlateUI` (lignes, icônes) et les tokens design.

## Sous-agents
- `design-integrator` : transforme le livrable Claude Design en composants `SlateUI` + tokens.
- `swiftui-builder` : `SidebarView`, `FolderRow` récursive, menus contextuels, création/renommage.
- `swift-reviewer` : navigation, cascade de sélection, persistance du pliage.

## Critères d'acceptation
- Arbre de dossiers/sous-dossiers affiché, pliable, persistant.
- Création/renommage/suppression de dossiers fonctionnels.
- Favoris affichés.
- Sélectionner un dossier change bien la colonne du milieu.

## Vérification
`swift-reviewer` + capture d'écran comparée au design. Cocher Phase 3.
