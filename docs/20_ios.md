# Phase 20 — Portage iOS

## Objectif (v3)
Rendre l'app disponible sur iPhone (et iPad) à partir du code SwiftUI existant, avec adaptations tactiles et layouts compacts.

## Prérequis
Jalon v1 stable (idéalement v2 avancé).

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- Layouts **compacts iPhone** : navigation par pile (sidebar → liste → note en push), barre d'onglets éventuelle.
- Adaptations iPad (split view, multitâche).
- Barre d'outils d'édition tactile (formatage au-dessus du clavier), poignées de bloc au doigt.

Déposer dans `design/20_ios/`. Dire `go`.

---

## Spécifications fonctionnelles
- Nouvelle **cible iOS** partageant les packages (`SlateModel`, `SlateUI`, `SlateEditor`, `SlateFeatures`, `SlateServices`).
- `NavigationSplitView` → comportement adaptatif : colonnes sur iPad/large, pile sur iPhone.
- **Interactions tactiles** : sélection, drag & drop de blocs au doigt, barre de formatage au-dessus du clavier, menus contextuels tactiles.
- CloudKit → sync transparente entre Mac et iPhone (déjà en place).
- Verrouillage via Face ID/Touch ID iOS.
- Gestion clavier logiciel (safe areas, scroll to caret).

## Détails techniques
- Isoler le code spécifique plateforme derrière `#if os(macOS)` / `#if os(iOS)` ou des abstractions dans `SlateUI`.
- Adapter le `RichTextBlockView` : `UIViewRepresentable`/`UITextView` (TextKit 2) côté iOS en miroir de la version `NSTextView`.
- Revoir tous les raccourcis souris/hover pour équivalents tactiles.
- Tester sur simulateur iPhone + iPad.

## Sous-agents
- `swiftui-builder` : adaptation des vues et navigation compacte.
- `editor-specialist` : `RichTextBlockView` iOS + interactions tactiles.
- `design-integrator` : layouts iOS.
- `swift-reviewer` : parité fonctionnelle mac/iOS, sync, tactile, safe areas.

## Critères d'acceptation
- L'app se lance et est utilisable sur iPhone et iPad.
- Édition de blocs complète au doigt.
- Sync iCloud Mac ↔ iPhone opérationnelle.

## Vérification
Tests sur simulateurs + parcours complet tactile. Cocher Phase 20.
