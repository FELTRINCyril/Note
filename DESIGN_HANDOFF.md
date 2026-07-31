# DESIGN_HANDOFF.md — Passerelle Claude Design ↔ Claude Code

> Ce document explique **comment travailler avec Claude Design en parallèle de Claude Code**.
> Claude Code te préviendra à chaque phase 🎨 : tu iras chercher le design ici, puis tu le déposeras dans `design/`.
>
> 📎 **Document maître pour Claude Design** : `design/01-brief-design.md` (direction artistique, inventaire d'écrans, composants, accessibilité) + `design/tokens.md` (tokens exhaustifs). Donne ces deux fichiers à Claude Design en premier. Ce présent document sert d'**index build → écran** (quel écran pour quelle phase).

---

## Comment ça marche (le flux)

1. Claude Code arrive sur une phase marquée 🎨 dans `PLAN.md`.
2. Il **s'arrête avant de coder l'UI** et te dit exactement quoi demander à Claude Design.
3. Tu ouvres **Claude Design** (dans un autre chat) et tu lui donnes le brief de la phase (copie la section correspondante ci-dessous).
4. Tu déposes ce que Claude Design produit dans le sous-dossier indiqué (`design/NN_nom/`).
5. Tu reviens sur Claude Code et tu dis **`go`**. L'agent `design-integrator` intègre le design dans le code.

## Format idéal à demander à Claude Design

Par ordre de préférence pour l'intégration :
1. **Code SwiftUI** directement (vues/composants) — le plus rapide à intégrer.
2. **Tokens + specs** : couleurs (hex, clair+sombre), typo (tailles/poids), espacements, rayons, ombres, + description des composants et états.
3. **Maquettes visuelles** (images/exports) + annotations — Claude Code les recode.

Dans tous les cas, demande **les états** (normal, survol, focus, sélectionné, désactivé, vide) et **les deux thèmes** (clair + sombre).

## Le fichier pivot : `design/tokens.md`
C'est la **source de vérité unique** du design system (couleurs, typo, espacements). La Phase 13 le consolide, mais dès la Phase 3 commence à le remplir. Tout le code de `SlateUI` en découle. Un gabarit de départ est déjà créé dans `design/tokens.md`.

---

## Briefs par phase (à copier vers Claude Design)

### 🎨 Phase 3 — `design/03_sidebar/`
Fenêtre principale 3 colonnes (sidebar | liste | éditeur) façon Notes d'Apple. Barre latérale : sections Favoris et Espaces/Dossiers (arbre récursif pliable avec chevrons et indentation), lignes avec icône + nom, états survol/sélection, boutons nouveau dossier / nouvelle note, accès réglages, sélecteur de workspace (placeholder). Clair + sombre.

### 🎨 Phase 4 — `design/04_liste_notes/`
Colonne liste de notes : cellule (titre, extrait sur 1–2 lignes, date relative, indicateurs épinglé/verrouillé/favori), section Épinglées en haut, en-têtes de regroupement par date (Aujourd'hui, Hier, 7 jours, 30 jours, mois, années), barre de recherche + tri, état vide, état sélectionné/survol. Clair + sombre.

### 🎨 Phase 5 — `design/05_editeur/`
Zone d'édition d'une note : en-tête (icône + cover + titre + sous-titre), largeur de colonne de texte, marges. Poignée de bloc ⋮⋮ (drag + menu) et bouton + à gauche des blocs. États d'un bloc : normal, survol, focus, sélectionné, placeholder « Tapez / pour les commandes ». Clair + sombre.

### 🎨 Phase 7 — `design/07_formatage/`
Barre de formatage flottante apparaissant sur sélection (gras, italique, souligné, barré, code inline, surlignage couleur, lien). Palette de surlignage/couleur de texte. Styles typographiques H1–H6 + code inline. Popover d'édition de lien. Clair + sombre.

### 🎨 Phase 9 — `design/09_medias/`
Bloc image (états : drop zone vide, chargement, affichée ; poignées de redimensionnement ; alignement ; légende). Bloc fichier joint (icône par type, nom, taille, actions). Zone de drag & drop dans l'éditeur. Clair + sombre.

### 🎨 Phase 13 — `design/13_themes/` + `design/tokens.md`
Système de design complet : palette clair ET sombre (fond, surfaces, texte primaire/secondaire, séparateurs, accent, couleurs de surlignage), typographie (échelle titre/H1–H6/corps/mono/légende), espacements, rayons, ombres, palette d'accents proposés + UI de personnalisation. **Consolider dans `design/tokens.md`.**

### 🎨 Phase 17 — `design/17_bdd/`
Vues de base de données : Grille/Table (en-têtes, cellules par type, barre de calculs en bas), Kanban (colonnes + cartes déplaçables), Calendrier (mois/semaine), Galerie (cartes vignette), Liste. Éditeurs de champ, menu filtres/tris/group-by, éditeur de template. Clair + sombre.

### 🎨 Phase 18 — `design/18_ia/`
Panneau/assistant IA (champ de prompt, réponse en streaming), menu IA dans l'éditeur (rédiger/résumer/traduire/corriger), bibliothèque de prompts (catégories, recherche), affichage des réponses RAG avec sources citées. Clair + sombre.

### 🎨 Phase 19 — `design/19_workspaces/`
Sélecteur de workspace en haut de sidebar (nom, icône, bascule rapide) + écran de gestion (créer/renommer/icône/couleur/supprimer). Clair + sombre.

### 🎨 Phase 20 — `design/20_ios/`
Layouts iOS : iPhone compact (navigation en pile sidebar→liste→note, barre d'onglets éventuelle), iPad (split view). Barre d'outils d'édition tactile au-dessus du clavier, poignées de bloc au doigt. Clair + sombre.

---

## Rappel
Les phases **non listées ici** n'ont pas besoin de Claude Design : Claude Code utilise directement `design/tokens.md` et les composants `SlateUI` existants.
