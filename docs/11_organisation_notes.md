# Phase 11 — Organisation des notes

## Objectif
Actions de gestion des notes façon Notes d'Apple : dupliquer, déplacer (vers un autre dossier), épingler, marquer favori, supprimer avec corbeille.

## Prérequis
Phases 3, 4.

## 🎨 Design
Léger. Menus contextuels et confirmations via composants `SlateUI`.

---

## Spécifications fonctionnelles
- **Dupliquer** : copie profonde d'une note (tous les blocs + pièces jointes), suffixe « copie ».
- **Déplacer** : vers un autre dossier (menu de sélection de dossier / drag vers la sidebar).
- **Épingler / désépingler** : `isPinned`, remonte en section Épinglées (Phase 4).
- **Favori** : `isFavorite`, apparaît dans la section Favoris (Phase 3).
- **Supprimer → Corbeille** : `isTrashed = true` + `trashedAt`. Vue Corbeille dédiée.
- **Corbeille** : restaurer, supprimer définitivement, purge auto après N jours (ex. 30).
- Actions accessibles via : menu contextuel (clic droit), swipe dans la liste, barre d'outils.
- Support multi-sélection dans la liste (agir en lot).

## Détails techniques
- Service `NoteActionsService` (ou méthodes sur un view-model) dans `SlateFeatures`/`SlateServices`.
- Duplication profonde : bien recréer les relations et régénérer les `id`.
- Corbeille : `@Query` filtré `isTrashed == true` ; tâche de purge au lancement.

## Sous-agents
- `data-modeler` : duplication profonde, corbeille, purge.
- `swiftui-builder` : menus, swipes, vue Corbeille, confirmations.
- `swift-reviewer` : intégrité de la copie profonde, restauration, purge, multi-sélection.

## Critères d'acceptation
- Dupliquer produit une copie fidèle et indépendante.
- Déplacer, épingler, favori mettent à jour sidebar/liste immédiatement.
- Suppression → corbeille → restauration / suppression définitive fonctionnent.

## Vérification
Tests de duplication profonde et cycle de corbeille + essai manuel. Cocher Phase 11.
