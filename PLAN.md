# PLAN.md — Roadmap maître de Slate

> Document d'orchestration. Chaque ligne de phase pointe vers un document détaillé dans `docs/`.
> Coche `[x]` une phase quand elle est **terminée ET vérifiée**.
> 🎨 = un design de Claude Design est nécessaire avant de coder l'UI (voir `DESIGN_HANDOFF.md`).
>
> **Rappel du protocole (détaillé dans `CLAUDE.md`)** : une phase à la fois → annonce → `go` → sous-agents → vérif → coche → stop.

---

## Vue d'ensemble des jalons

- **v0 — Fondations** (Phases 0–2) : architecture, projet Xcode, modèle de données. *Aucun design requis.*
- **v1 — App utilisable façon Notes+** (Phases 3–14) : coquille, éditeur de blocs complet, organisation, thèmes, raccourcis. *Cœur du produit.*
- **v2 — Puissance Notion** (Phases 15–19) : markdown natif, liens internes, bases de données, IA, workspaces.
- **v3 — Mobilité** (Phase 20) : portage iOS.

---

## PRIMAIRE + Fondations

### Jalon v0 — Fondations
- [x] **Phase 0 — Architecture & structure** → `docs/00_architecture.md` (+ `docs/GLOSSAIRE.md`)
- [x] **Phase 1 — Setup projet Xcode + SwiftData/CloudKit** → `docs/01_setup_projet.md`
- [ ] **Phase 2 — Modèle de données (blocs, dossiers, notes, workspaces)** → `docs/02_modele_donnees.md`

### Jalon v1 — App utilisable
- [ ] 🎨 **Phase 3 — Coquille app & barre latérale** (dossiers, sous-dossiers, favoris, réglages) → `docs/03_sidebar_navigation.md`
- [ ] 🎨 **Phase 4 — Liste des notes & regroupement par date** (aujourd'hui, hier, 7j, 30j, mois, années) → `docs/04_liste_notes.md`
- [ ] 🎨 **Phase 5 — Éditeur de blocs (cœur)** (rendu, focus, saisie, navigation clavier) → `docs/05_editeur_blocs.md`
- [ ] **Phase 6 — Menu de commandes `/`** → `docs/06_slash_commandes.md`
- [ ] 🎨 **Phase 7 — Typographie & formatage** (gras, italique, souligné, barré, code inline, surlignage, liens, H1–H6) → `docs/07_typographie_formatage.md`
- [ ] **Phase 8 — Blocs spéciaux** (code, citation, listes puces/numéros/tâches, tableaux, callout) → `docs/08_blocs_speciaux.md`
- [ ] 🎨 **Phase 9 — Médias & pièces jointes** (images insérer/redimensionner, fichiers) → `docs/09_medias_pieces_jointes.md`
- [ ] **Phase 10 — Glisser-déposer & colonnes** (réorganiser les blocs, mise en colonnes) → `docs/10_dragdrop_colonnes.md`
- [ ] **Phase 11 — Organisation des notes** (dupliquer, déplacer, épingler, supprimer, corbeille) → `docs/11_organisation_notes.md`
- [ ] **Phase 12 — Verrouillage de note** (mot de passe / Touch ID / Face ID) → `docs/12_verrouillage.md`
- [ ] 🎨 **Phase 13 — Thèmes & apparence** (sombre/clair, couleur d'accent personnalisable) → `docs/13_themes_apparence.md`
- [ ] **Phase 14 — Raccourcis clavier** (navigation complète sans souris) → `docs/14_raccourcis_clavier.md`

---

## SECONDAIRE

### Jalon v2 — Puissance Notion
- [ ] **Phase 15 — Markdown natif à la frappe** (`#`, `**`, `-`, `[]`…) → `docs/15_markdown_natif.md`
- [ ] **Phase 16 — Liens internes & sous-pages** (mentions `@`, création à la volée) → `docs/16_liens_internes.md`
- [ ] 🎨 **Phase 17 — Bases de données** (grille, kanban, calendrier, galerie, liste ; champs ; filtres/tris/groupes ; calculs ; templates) → `docs/17_base_de_donnees.md`
- [ ] 🎨 **Phase 18 — Fonctionnalités IA** (génération, RAG Q&A, transcription, résumés, bibliothèque de prompts) → `docs/18_ia.md`
- [ ] 🎨 **Phase 19 — Espaces de travail (Workspaces)** (Pro/Perso isolés) → `docs/19_workspaces.md`

### Jalon v3 — Mobilité
- [ ] 🎨 **Phase 20 — Portage iOS** (cible iOS, adaptations tactiles, layout compact) → `docs/20_ios.md`

---

## Ordre recommandé & dépendances

```
0 → 1 → 2                 (fondations, séquentiel strict)
        ↓
   3 → 4 → 5 → 6 → 7 → 8 → 9 → 10   (v1, séquentiel : chaque brique s'appuie sur la précédente)
                                ↓
                        11 → 12 → 13 → 14   (peuvent partiellement se paralléliser)
                                        ↓
   15 → 16 → 17 → 18 → 19        (v2 ; 17 et 18 sont gros, à découper en sous-étapes)
                        ↓
                       20         (v3, une fois v1 stable)
```

Points de vigilance :
- **Phase 2 (modèle de données)** conditionne tout. À faire soigneusement, avec `swift-reviewer` en fin de phase.
- **Phase 5 (éditeur)** est la plus complexe → sera elle-même découpée en sous-étapes internes dans son doc.
- **Phases 17 & 18** sont volumineuses → chacune a un plan interne en sous-sections dans son doc.

---

## Checkpoints Design 🎨 (résumé)

| Phase | Écrans / composants à demander à Claude Design |
|---|---|
| 3 | Fenêtre principale 3 colonnes, barre latérale (arbre, favoris, réglages) |
| 4 | Colonne liste de notes, en-têtes de regroupement par date, aperçus |
| 5 | Zone d'édition, curseur de bloc, poignée de bloc, états focus |
| 7 | Barre de formatage flottante, styles de texte H1–H6 |
| 9 | Bloc image (états, redimensionnement), bloc fichier joint |
| 13 | Thèmes clair/sombre, palette d'accents, tokens de couleur/typo |
| 17 | Vues base de données (grille, kanban, calendrier, galerie, liste) |
| 18 | Panneau IA, menu de prompts, résultats de recherche RAG |
| 19 | Sélecteur de workspace |
| 20 | Layouts iOS (compact, feuilles, barre d'onglets) |

Détails complets → `DESIGN_HANDOFF.md`.
