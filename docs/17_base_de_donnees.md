# Phase 17 — Bases de données (gros morceau)

## Objectif (v2)
Le système de bases de données façon Notion : des collections d'« entrées » (rows) affichables sous plusieurs vues, avec champs typés, filtres, tris, regroupements, calculs et templates.

## Prérequis
Jalon v1 complet (surtout 2, 5, 8, 16).

## 🎨 DESIGN REQUIS
**Demander à Claude Design** (par vue) :
- Vue **Grille/Table** (façon Excel) : en-têtes, cellules par type, ligne d'ajout, barre de calculs.
- Vue **Kanban** (colonnes type Trello) : colonnes = groupes, cartes déplaçables.
- Vue **Calendrier** : mois/semaine, entrées par date.
- Vue **Galerie** : cartes avec vignette.
- Vue **Liste** compacte.
- Éditeurs de champ, menu filtres/tris/groupes, éditeur de template.

Déposer dans `design/17_bdd/`. Dire `go`.

---

## Découpage interne recommandé (sous-étapes)
> Cette phase est volumineuse → l'exécuter en sous-étapes, chacune validée avant la suivante.

### 17.1 Modèle de données
- `Database`, `DatabaseField` (type + config), `DatabaseRow`, `CellValue`.
- Une base peut être **inline** dans une note (bloc `databaseView`) ou pleine page.

### 17.2 Champs
- Basiques : Texte, Nombre, Date, Case à cocher, URL, **Sélection unique (tags)**, **Sélection multiple**.
- Avancés : Date de création, Date de modification, **Relations** (lier des bases), **Rollups** (agréger depuis une relation).

### 17.3 Vue Grille (Table)
- CRUD de lignes, édition inline par type de cellule, redimensionnement/réordonnancement de colonnes.
- **Calculs** en bas de colonne : somme, moyenne, min/max, comptage rempli/vide, %.

### 17.4 Filtres, tris, regroupements
- Filtres multi-critères (masquer selon condition, ex. « masquer terminées »).
- Tris multi-niveaux (alpha, chrono, numérique).
- **Group by** (tags/statut) — base commune avec le Kanban.

### 17.5 Autres vues
- Kanban (group by → colonnes, drag entre colonnes met à jour le champ).
- Calendrier, Galerie, Liste (partagent le modèle + filtres/tris).

### 17.6 Templates
- Fiches pré-remplies réutilisables en un clic pour nouvelles entrées.

## Détails techniques
- Nouveau sous-module possible `SlateDatabase` (ou dans `SlateFeatures`).
- Moteur de requête (filtre/tri/groupe) **testable indépendamment de l'UI**.
- Relations/Rollups : bien gérer la cohérence et les perfs.
- Réutiliser drag & drop (Phase 10) pour Kanban.

## Sous-agents
- `data-modeler` : modèle base/champs/lignes, relations, rollups, moteur de requête.
- `swiftui-builder` + `design-integrator` : chaque vue.
- `swift-reviewer` : moteur filtre/tri/groupe, calculs, relations/rollups, perfs.

## Critères d'acceptation
- Créer une base, ajouter champs de chaque type, saisir des lignes.
- Basculer entre les 5 vues sur les mêmes données.
- Filtres/tris/group-by/calculs fonctionnels.
- Relations + rollups corrects. Templates opérationnels.

## Vérification
Tests du moteur de requête et des calculs + parcours par vue. Cocher Phase 17.
