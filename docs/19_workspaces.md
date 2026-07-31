# Phase 19 — Espaces de travail (Workspaces)

## Objectif (v2)
Plusieurs workspaces isolés les uns des autres (ex. Pro, Perso), chacun avec ses espaces/dossiers/notes/bases et ses réglages.

## Prérequis
Phase 2 (`Workspace` déjà modélisé), v1 complet.

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- Le **sélecteur de workspace** (en haut de la sidebar : nom, icône, bascule rapide).
- L'écran de **gestion des workspaces** (créer, renommer, icône, couleur, supprimer).

Déposer dans `design/19_workspaces/`. Dire `go`.

---

## Spécifications fonctionnelles
- Créer / renommer / supprimer des workspaces ; icône + couleur d'accent par workspace.
- **Isolation** : la sidebar, la liste, la recherche ne montrent que le contenu du workspace actif.
- Bascule rapide entre workspaces (menu + raccourci).
- Réglages par workspace (accent, apparence par défaut, éventuellement mot de passe de verrouillage).
- `AppState.selectedWorkspace` pilote tous les `@Query` (filtrage par workspace).

## Détails techniques
- Rétro-adapter les requêtes existantes pour filtrer par `selectedWorkspace` (souvent le plus gros du travail).
- Migration : si des données existent hors workspace, les rattacher à un workspace par défaut.
- Sync CloudKit reste par utilisateur ; les workspaces sont une partition logique.

## Sous-agents
- `data-modeler` : filtrage par workspace, migration, isolation des requêtes.
- `swiftui-builder` + `design-integrator` : sélecteur + gestion.
- `swift-reviewer` : étanchéité de l'isolation (aucune fuite entre workspaces), bascule, migration.

## Critères d'acceptation
- Créer plusieurs workspaces, basculer, contenu bien isolé.
- Réglages et accent par workspace.
- Aucune donnée ne fuit d'un workspace à l'autre.

## Vérification
Tests d'isolation des requêtes + parcours multi-workspace. Cocher Phase 19.
