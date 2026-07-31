# Phase 1 — Setup projet Xcode + SwiftData/CloudKit

## Objectif
Créer un projet Xcode qui **compile et se lance** (fenêtre vide), avec les 5 Swift Packages locaux, SwiftData configuré et CloudKit branché (sync iCloud privé).

## Prérequis
Phase 0 (architecture actée).

## 🎨 Design
Non requis.

---

## Étapes

### 1.1 Création du projet
- App macOS, SwiftUI, langage Swift, **cible macOS 15.0**.
- Nom du produit : `Slate` (modifiable). Bundle id : `com.gemaddis.slate` (à ajuster).
- Activer Swift 6 language mode (concurrence stricte).

### 1.2 Swift Packages locaux
Créer les 5 packages décrits en Phase 0 (`SlateModel`, `SlateUI`, `SlateEditor`, `SlateFeatures`, `SlateServices`), les ajouter au projet et déclarer leurs dépendances dans les `Package.swift`.

### 1.3 SwiftData
- Définir un `ModelContainer` central dans `SlateModel` (fonction `makeContainer()`), injecté dans l'app via `.modelContainer(...)`.
- Schéma initial minimal : un seul modèle placeholder (`Note` vide) pour vérifier que ça persiste. Le vrai schéma arrive en Phase 2.

### 1.4 CloudKit
- Activer les capabilities : **iCloud → CloudKit** + **Background Modes → Remote notifications**.
- Créer le container iCloud (`iCloud.com.gemaddis.slate`).
- Configurer `ModelConfiguration` avec `cloudKitDatabase: .private`.
- **Note** : toutes les propriétés des modèles SwiftData synchronisés via CloudKit doivent avoir une valeur par défaut ou être optionnelles (contrainte CloudKit). À documenter pour la Phase 2.
- Prévoir un flag de build pour désactiver CloudKit en dev local (éviter la friction).

### 1.5 Squelette d'app
- `SlateApp.swift` : `WindowGroup` avec un `NavigationSplitView` à 3 colonnes vides (« Sidebar », « Liste », « Détail »).
- `AppState.swift` : `@Observable` avec `selectedWorkspace`, `selectedFolder`, `selectedNote` (tous optionnels/nil).

### 1.6 Qualité dès le départ
- Ajouter SwiftLint (config légère) — **proposer à Cyril avant d'ajouter la dépendance**.
- Configurer un scheme de test par package.

---

## Sous-agents
- `data-modeler` : mise en place du `ModelContainer` + config CloudKit (1.3, 1.4).
- `swiftui-builder` : squelette d'app et `AppState` (1.5).
- `swift-reviewer` : vérifie que le projet compile, se lance, et que la persistance placeholder fonctionne.

## Critères d'acceptation
- L'app se lance sur une fenêtre 3 colonnes vide.
- Une entité placeholder persiste entre deux lancements.
- CloudKit est branché (ou désactivable par flag) sans crash.
- Les 5 packages compilent indépendamment.

## Vérification
`swift-reviewer` : build clean, lancement, un test de persistance basique. Cocher la Phase 1 dans `PLAN.md`.
