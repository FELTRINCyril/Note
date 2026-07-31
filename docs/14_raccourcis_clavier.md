# Phase 14 — Raccourcis clavier

## Objectif
Navigation et gestion complètes au clavier, sans souris : parcourir dossiers/notes, gérer les blocs, formater, exécuter les actions.

## Prérequis
Toutes les phases v1 (3–13). Consolide leurs raccourcis.

## 🎨 Design
Non requis (hors éventuelle feuille d'aide « raccourcis »).

---

## Spécifications fonctionnelles
### Navigation globale
- Focus sidebar / liste / éditeur (ex. ⌘1/⌘2/⌘3).
- Note suivante/précédente (↑/↓ dans la liste), ouvrir (Entrée).
- Recherche globale (⌘⇧F ou ⌘F), palette de commandes globale (⌘K optionnel).
- Nouvelle note (⌘N), nouveau dossier (⌘⇧N).

### Édition / blocs (rappel + consolidation)
- Nouveau bloc (Entrée), fusion (Backspace), navigation caret (flèches).
- Indenter/désindenter (Tab/⇧Tab).
- Déplacer un bloc (⌘⇧↑/↓).
- Dupliquer/supprimer un bloc.
- Ouvrir le menu `/`.

### Formatage (rappel Phase 7)
- ⌘B/I/U, ⌘⇧X, ⌘E, ⌘K.

### Actions note
- Épingler, verrouiller, dupliquer, supprimer (raccourcis dédiés).

## Détails techniques
- Centraliser dans un `KeyboardShortcuts` (registre + `.keyboardShortcut` SwiftUI et/ou commandes via `Commands`/menu bar macOS).
- Ajouter les entrées de **menu bar macOS** correspondantes (Fichier, Édition, Format, Affichage) — attendu sur macOS natif.
- Éviter les conflits ; documenter la liste dans `docs/RACCOURCIS.md`.
- Feuille d'aide « raccourcis » (⌘/) optionnelle.

## Sous-agents
- `swiftui-builder` : menu bar macOS, registre de raccourcis, câblage des actions.
- `swift-reviewer` : absence de conflits, couverture (chaque action clé a un raccourci), test de navigation 100% clavier.

## Critères d'acceptation
- On peut créer/naviguer/éditer/formater/gérer une note entièrement au clavier.
- Menu bar macOS complet et cohérent.
- Liste des raccourcis documentée.

## Vérification
Parcours complet au clavier + revue des conflits. Cocher Phase 14 → **fin du jalon v1**.
