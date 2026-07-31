# Phase 10 — Glisser-déposer & colonnes

## Objectif
Réorganiser les blocs par glisser-déposer et disposer du contenu en colonnes côte à côte, façon Notion.

## Prérequis
Phases 5–8.

## 🎨 Design
Modéré. Demander à Claude Design (optionnel mais utile) : indicateur de drop (ligne d'insertion), aperçu du bloc en cours de drag, guides visuels de colonnes. Sinon rendu par défaut.

---

## Spécifications fonctionnelles
### Drag & drop de blocs
- Saisir un bloc par sa poignée ⋮⋮ (Phase 5) et le déplacer verticalement.
- **Ligne d'insertion** indiquant la position de dépôt.
- Réordonne `order` (et `parent` si on entre/sort d'une colonne ou d'une liste).
- Déplacement multi-blocs (sélection Phase 5.6).

### Colonnes
- Déposer un bloc **à côté** d'un autre crée une **mise en colonnes** (`columnList` → `column` → blocs).
- Ajuster la **largeur relative** des colonnes par glissement du séparateur.
- Retirer le dernier bloc d'une colonne dissout la structure proprement.
- Responsive : sur fenêtre étroite (et iOS plus tard), les colonnes s'empilent.

## Détails techniques
- Utiliser l'API drag & drop SwiftUI (`draggable`/`dropDestination`) ou une gestion custom via TextKit selon ce que l'`editor-specialist` juge le plus fiable.
- Modèle `columnList`/`column` déjà prévu (Phase 2). Gérer la cohérence des `order`/`parent` lors des déplacements.
- Attention aux perfs et à la stabilité du focus pendant le drag.

## Sous-agents
- `editor-specialist` : drag & drop, création/dissolution de colonnes, redimensionnement.
- `swift-reviewer` : intégrité de `order`/`parent` après déplacements, cas de dissolution, responsive.

## Critères d'acceptation
- Réordonner des blocs par drag fonctionne, avec indicateur.
- Créer 2+ colonnes en déposant à côté, redimensionner, dissoudre.
- La hiérarchie reste cohérente après manipulations.

## Vérification
Tests d'intégrité du modèle après déplacements + essai manuel. Cocher Phase 10.
