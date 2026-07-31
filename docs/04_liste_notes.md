# Phase 4 — Liste des notes & regroupement par date

## Objectif
La colonne du milieu : liste des notes du dossier sélectionné, avec regroupement temporel exactement comme Notes d'Apple (Aujourd'hui, Hier, 7 derniers jours, 30 derniers jours, puis par mois, puis par années).

## Prérequis
Phases 2 et 3.

## 🎨 DESIGN REQUIS
**Demander à Claude Design :**
- La cellule de note : titre, extrait (snippet), date/heure, indicateurs (épinglé 📌, verrouillé 🔒, favori).
- Les **en-têtes de regroupement** par date (styles, espacements).
- La section **Épinglées** en haut.
- Les états : sélectionnée, survol, vide (aucune note).
- La barre de recherche + tri.

Déposer dans `design/04_liste_notes/`. Dire `go`.

---

## Spécifications fonctionnelles
- Liste des notes du dossier courant (`AppState.selectedFolder`), ou d'une vue agrégée (« Toutes les notes »).
- **Section Épinglées** en haut (notes `isPinned`), toujours au-dessus des groupes de date.
- **Regroupement par date** basé sur `modifiedAt` (option : `createdAt`) :
  - `Aujourd'hui`
  - `Hier`
  - `7 jours précédents`
  - `30 jours précédents`
  - puis par **mois** de l'année en cours (« Juin », « Mai »…)
  - puis par **année** (« 2025 », « 2024 »…)
- Tri à l'intérieur d'un groupe : par date décroissante (option : par titre).
- Aperçu : titre (1re ligne) + snippet (blocs texte suivants) + date formatée relative.
- Recherche plein texte (titre + contenu des blocs) filtrant la liste.
- Sélection → `AppState.selectedNote` → ouvre l'éditeur (Phase 5).
- Actions rapides (swipe / menu contextuel) : épingler, verrouiller, dupliquer, déplacer, supprimer (câblées en Phase 11/12).

## Détails techniques
- Logique de regroupement dans un helper testable de `SlateFeatures` (`NoteDateGrouper`) — **couvrir par tests unitaires** (bords : minuit, changement d'année, fuseaux).
- `@Query` filtré + tri, puis regroupement en mémoire.
- Formatage des dates via `Date.FormatStyle` localisé FR/EN.

## Sous-agents
- `swiftui-builder` : `NoteListView`, cellule, en-têtes de section, recherche.
- `design-integrator` : cellules et en-têtes selon le design.
- `swift-reviewer` : tests du `NoteDateGrouper` (cas limites), tri, recherche.

## Critères d'acceptation
- Les notes se rangent dans les bons groupes de date, comme Notes.
- Les épinglées apparaissent en haut.
- Recherche et tri fonctionnels.
- Sélection ouvre la note.

## Vérification
Tests unitaires du regroupement + capture comparée au design. Cocher Phase 4.
