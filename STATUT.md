# STATUT — Slate

> Tableau de bord **côté utilisateur**, maintenu hors du workflow de phases (par l'orchestration, pas par Claude Code).
> Source de vérité des cases cochées : `PLAN.md`. Ce fichier ajoute le contexte (commits, qualité, décisions).
> ⚠️ Ne pas supprimer : c'est le récap que consulte Cyril. Il ne prétend pas être la source d'avancement, `PLAN.md` l'est.

**Dernière mise à jour :** fin de la phase 4.

---

## En un coup d'œil

**4 / 21 phases terminées.**

```
Fondations v0  ██████████ 100 %   (3/3)   ✅ terminé
App v1         ██░░░░░░░░  17 %   (2/12)  ⏳ en cours
Notion v2      ░░░░░░░░░░    0 %   (0/5)   ⬜ à venir
Mobilité v3    ░░░░░░░░░░    0 %   (0/1)   ⬜ à venir
```

- **Où on en est :** phase 4 (liste de notes + regroupement par date) validée.
- **Prochaine étape :** 🎨 **Phase 5 — Éditeur de blocs**, la plus complexe du projet (découpée en sous-étapes). Design requis.
- **Qualité au dernier point (phase 4) :** 140 tests verts · build sans avertissement · 0 violation SwiftLint · commit `5e9abb3`.

Légende : ✅ terminé · ⏳ prochaine · ⬜ à venir · 🎨 design requis · ✔️ design livré

---

## Détail par phase

### Jalon v0 — Fondations
| # | Phase | Statut | Design | Commit |
|---|---|---|---|---|
| 0 | Architecture & structure | ✅ | — | — |
| 1 | Setup projet Xcode + SwiftData/CloudKit | ✅ | — | — |
| 2 | Modèle de données | ✅ | — | `d82630a` |

### Jalon v1 — App utilisable façon Notes+
| # | Phase | Statut | Design | Commit |
|---|---|---|---|---|
| 3 | Coquille app & barre latérale | ✅ | 🎨 ✔️ | `6e924b9` |
| 4 | Liste des notes & regroupement par date | ✅ | 🎨 ✔️ | `5e9abb3` |
| 5 | Éditeur de blocs (cœur) | ⏳ **prochaine** | 🎨 **à livrer** | — |
| 6 | Menu de commandes `/` | ⬜ | — | — |
| 7 | Typographie & formatage | ⬜ | 🎨 à livrer | — |
| 8 | Blocs spéciaux | ⬜ | — | — |
| 9 | Médias & pièces jointes | ⬜ | 🎨 à livrer | — |
| 10 | Glisser-déposer & colonnes | ⬜ | — | — |
| 11 | Organisation des notes | ⬜ | — | — |
| 12 | Verrouillage de note | ⬜ | — | — |
| 13 | Thèmes & apparence | ⬜ | 🎨 à livrer | — |
| 14 | Raccourcis clavier | ⬜ | — | — |

### Jalon v2 — Puissance Notion
| # | Phase | Statut | Design | Commit |
|---|---|---|---|---|
| 15 | Markdown natif à la frappe | ⬜ | — | — |
| 16 | Liens internes & sous-pages | ⬜ | — | — |
| 17 | Bases de données | ⬜ | 🎨 à livrer | — |
| 18 | Fonctionnalités IA | ⬜ | 🎨 à livrer | — |
| 19 | Espaces de travail (workspaces) | ⬜ | 🎨 à livrer | — |

### Jalon v3 — Mobilité
| # | Phase | Statut | Design | Commit |
|---|---|---|---|---|
| 20 | Portage iOS | ⬜ | 🎨 à livrer | — |

---

## Décisions tranchées
- **Phase 2/4 — `snippetText` :** calcul dans `SlateModel`, `refreshDerivedText()` appelé au point de sauvegarde unique (phase 5). ✅
- **Phase 3/4 — Couleur de dossier :** `colorIndex` optionnel + enum fermé 8 cas alignés sur la palette ; index hors bornes → nil ; repli hachage. ✅
- **Phase 3 — ⌘2 :** contournement par largeur nulle conservé, à revisiter. ✅

## Décisions en attente (phase 4, à valider)
1. **Aplat de sélection** dérivé par règle générale → 2 valeurs par thème au lieu du `#0A6BE6` unique. *Reco : accepter* (la règle protège le contraste quand l'accent deviendra personnalisable en phase 13).
2. **Increase Contrast** produit un bleu nettement plus sombre. *Reco : accepter* (c'est le but du mode).
3. **Date à J-7** affiche « 27 juil. » alors que ses voisines du même groupe affichent « Lundi ». *Reco : aligner le format sur le groupe* (tout « 7 jours précédents » en nom de jour).

---

## Points ouverts non bloquants
- **Vérification visuelle (thème sombre + comparaison au design)** toujours impossible : autoriser **Switchboard** dans *Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran*, puis le quitter/relancer. C'est le seul élément de vérification que Claude Code ne peut pas produire sans ça — à débloquer idéalement avant la phase 5.

---

## Prochaine action concrète
Demander à Claude Design l'écran **E4 — Éditeur** (voir `DESIGN_HANDOFF.md`, phase 5) avec `01-brief-design.md` + `tokens.md`, déposer dans `design/05_editeur/`, puis envoyer le `go` + validations à Claude Code.
