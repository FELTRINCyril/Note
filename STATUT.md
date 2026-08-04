# STATUT — Slate

> Tableau de bord **côté utilisateur**, maintenu hors du workflow de phases (par l'orchestration, pas par Claude Code).
> Source de vérité des cases cochées : `PLAN.md`. Ce fichier ajoute le contexte (commits, qualité, décisions).
> ⚠️ Ne pas supprimer : c'est le récap que consulte Cyril. Il ne prétend pas être la source d'avancement, `PLAN.md` l'est.

**Dernière mise à jour :** fin de la phase 5.

---

## En un coup d'œil

**5 / 21 phases terminées.**

```
Fondations v0  ██████████ 100 %   (3/3)   ✅ terminé
App v1         ███░░░░░░░  25 %   (3/12)  ⏳ en cours
Notion v2      ░░░░░░░░░░    0 %   (0/5)   ⬜ à venir
Mobilité v3    ░░░░░░░░░░    0 %   (0/1)   ⬜ à venir
```

- **Où on en est :** phase 5 (éditeur de blocs) validée, la plus complexe du projet. Six sous-étapes 5.1 → 5.6, puis trois défauts bloquants trouvés en revue et corrigés avant validation.
- **Prochaine étape :** **Phase 6 — Menu de commandes `/`**. Aucun design requis.
- **Qualité au dernier point (phase 5) :** 315 tests verts · build sans avertissement · 0 violation SwiftLint · commit `964379c`.

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
| 5 | Éditeur de blocs (cœur) | ✅ | 🎨 ✔️ | `964379c` |
| 6 | Menu de commandes `/` | ⏳ **prochaine** | — | — |
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
- **Phase 4 — Aplat de sélection :** règle générale conservée (2 valeurs par thème au lieu du `#0A6BE6` unique), pour protéger le contraste quand l'accent deviendra personnalisable. ✅
- **Phase 4 — Increase Contrast :** bleu nettement plus sombre accepté, c'est le but du mode. ✅
- **Phase 4 — Date à J-7 :** format aligné sur le groupe, tout « 7 jours précédents » en nom de jour. ✅
- **Phase 5 — Architecture d'édition :** un `RichTextBlockView` par bloc via `NSViewRepresentable` / TextKit 2 (option 2 du doc). Aucun bloquant rencontré. ✅
- **Phase 5 — Gouttière :** dans le flux, colonne de texte strictement à 720 pt, décalage optique d'environ 24 pt accepté. L'approche flottante a été écartée : sous 48 pt de marge, un overlay serait rogné ou déborderait sur la colonne de liste. ✅
- **Phase 5 — Offset de caret :** type distinct `RichTextOffset` / `RichTextRange` plutôt qu'une conversion ponctuelle, pour rendre la confusion UTF-16 / graphèmes impossible à la compilation. ✅

## Décisions en attente
1. **Sous-titre de note** : la spec E4 en montre un, le modèle `Note` n'a pas ce champ. L'ajouter est une décision produit avec évolution de schéma. Rendu sans sous-titre en attendant.
2. **Deux formateurs de date** coexistent : celui de la liste (jamais jour + heure ensemble) et celui de l'en-tête d'éditeur (toujours les deux, exigé par E4). *Reco : les laisser séparés*, ils répondent à deux besoins d'affichage réellement différents.

---

## Points ouverts non bloquants
- **Vérification visuelle (thème sombre + comparaison au design)** toujours impossible : autoriser **Switchboard** dans *Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran*, puis le quitter/relancer.
- **À vérifier à la main dans Xcode** (non testable sans fenêtre) : conservation de la colonne visuelle aux flèches, sélection de bloc par Échap, et sur une note de 500+ blocs le nombre de `NSTextView` réellement vivants (quelques dizaines attendues, pas 500) via Instruments.
- **Saut de barre de défilement** possible en remontant dans une note très longue : `LazyVStack` doit estimer la hauteur des blocs non matérialisés, or TextKit 2 ne la connaît qu'une fois le bloc monté. Corriger proprement demanderait un cache de hauteurs.
- **`ModelContext.insert` de SwiftData est non linéaire** (ratio 12,7 mesuré, indépendamment de notre code). Sans effet sur la frappe (0,86 ms par insertion sur une note de 500 blocs), mais l'import en masse d'une phase ultérieure devra utiliser une insertion par lot.

---

## Prochaine action concrète
Lancer la **phase 6 — Menu de commandes `/`** : aucun design à demander, le doc `docs/06_slash_commandes.md` suffit. Les points d'accroche sont déjà en place (le bouton `+` et `insertBlockBelow` de la phase 5.4, et l'opération de conversion pure de la 5.5 que le menu `/` réutilisera).
