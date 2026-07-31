# Phase 0 — Architecture & structure du projet

## Objectif
Poser les fondations : l'organisation en modules, les patterns, et les règles qui tiendront tout le projet. Aucun code fonctionnel ici, uniquement la structure et un squelette qui compile.

## Prérequis
Aucun. C'est la première phase.

## 🎨 Design
Non requis.

---

## Architecture cible

Monorepo Xcode avec des **Swift Packages locaux** pour séparer les responsabilités et garder des temps de compilation courts. L'app macOS (et plus tard iOS) est une coquille fine qui assemble les modules.

```
Slate/                        ← dossier racine (ce dépôt)
├─ Slate.xcodeproj            (ou Slate.xcworkspace)
├─ App/                       ← cible macOS (et iOS plus tard)
│  ├─ SlateApp.swift          point d'entrée @main
│  ├─ AppState.swift          état global @Observable
│  └─ Assets.xcassets
├─ Packages/
│  ├─ SlateModel/             modèles SwiftData + logique de données
│  ├─ SlateEditor/            éditeur de blocs (le cœur)
│  ├─ SlateUI/                composants d'UI réutilisables + design system
│  ├─ SlateFeatures/          features assemblées (sidebar, liste, réglages…)
│  └─ SlateServices/          services transverses (sync, IA, verrouillage, export)
└─ Tests/                     tests unitaires par package
```

### Rôle de chaque module
- **SlateModel** — types SwiftData (`Workspace`, `Space`, `Folder`, `Note`, `Block`, `Attachment`, `Tag`…), conteneur `ModelContainer`, requêtes, migrations, config CloudKit. Ne dépend de rien d'autre.
- **SlateUI** — design system : tokens (couleurs, typo, espacements), composants atomiques (boutons, champs, icônes), thèmes clair/sombre. Dépend de rien (ou seulement de SwiftUI).
- **SlateEditor** — moteur d'édition par blocs : modèle de rendu, gestion du focus/caret, menu `/`, formatage inline, drag & drop, colonnes. Dépend de SlateModel + SlateUI.
- **SlateFeatures** — écrans complets qui assemblent tout : barre latérale, liste de notes, panneau réglages, base de données, IA. Dépend de tous les autres.
- **SlateServices** — synchronisation CloudKit, verrouillage biométrique, import/export, intégration IA, transcription. Dépend de SlateModel.

### Dépendances (sens autorisé)
```
App → SlateFeatures → SlateEditor → SlateModel
                    → SlateUI
                    → SlateServices → SlateModel
```
Jamais de dépendance inverse (SlateModel ne connaît pas l'UI).

---

## Patterns

- **State** : Observation framework (`@Observable`), injecté via `@Environment` ou passé explicitement. `AppState` global pour la sélection courante (workspace / dossier / note actifs).
- **MVVM léger** : une vue peut avoir un petit view-model `@Observable` quand la logique le justifie ; sinon la vue lit directement le modèle SwiftData via `@Query`.
- **Navigation** : `NavigationSplitView` à 3 colonnes (sidebar | liste | détail), état de sélection dans `AppState`.
- **Concurrence** : Swift 6, `@MainActor` sur l'UI, acteurs pour les services lourds (sync, IA, transcription).

---

## Livrables de la phase
- Le projet Xcode créé (fait en Phase 1, ici on décrit seulement la cible).
- Ce document validé comme référence d'architecture.
- Un `docs/GLOSSAIRE.md` optionnel définissant le vocabulaire (Block, Space, Note vs Page…).

## Sous-agents
- Aucun code à générer. Cette phase est surtout de la lecture/validation par l'orchestrateur.

## Critères d'acceptation
- L'arborescence des modules est comprise et actée.
- Le sens des dépendances est clair.

## Vérification
Relecture de la cohérence avec `CLAUDE.md` (§1 et §5). Passer à la Phase 1.
