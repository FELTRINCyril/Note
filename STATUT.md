# STATUT — Slate

> Tableau de bord **côté utilisateur**, maintenu hors du workflow de phases (par l'orchestration, pas par Claude Code).
> Source de vérité des cases cochées : `PLAN.md`. Ce fichier ajoute le contexte (commits, qualité, décisions).
> ⚠️ Ne pas supprimer : c'est le récap que consulte Cyril. Il ne prétend pas être la source d'avancement, `PLAN.md` l'est.

**Dernière mise à jour :** fin de la phase 6.

---

## En un coup d'œil

**6 / 21 phases terminées.**

```
Fondations v0  ██████████ 100 %   (3/3)   ✅ terminé
App v1         ███░░░░░░░  33 %   (4/12)  ⏳ en cours
Notion v2      ░░░░░░░░░░    0 %   (0/5)   ⬜ à venir
Mobilité v3    ░░░░░░░░░░    0 %   (0/1)   ⬜ à venir
```

- **Où on en est :** phase 6 (menu de commandes `/`) validée. 13 commandes, filtrage flou FR + EN, navigation clavier complète. Une incohérence entre livraisons parallèles trouvée et corrigée avant la revue (voir Décisions), puis une garde manquante ajoutée après revue.
- **Prochaine étape :** **Phase 7 — Typographie & formatage**. 🎨 **Design requis** avant de coder l'UI (barre de formatage flottante, styles H1–H6).
- **Qualité au dernier point (phase 6) :** 370 tests verts (dont 202 sur `SlateEditor`) · build sans avertissement nouveau · 0 violation SwiftLint.

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
| 6 | Menu de commandes `/` | ✅ | — | `b7433ed` |
| 7 | Typographie & formatage | ⏳ **prochaine** | 🎨 à livrer | — |
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
- **Phase 5 — Sous-titre de note :** *aucun champ ajouté au modèle `Note`*. Un sous-titre est un **style de paragraphe**, il relèvera de la phase 7 (typographie & formatage). L'en-tête d'éditeur reste tel quel. ✅ (tranché le 04/08/2026)
- **Phase 5 — Deux formateurs de date :** **laissés séparés**. Celui de la liste (jamais jour + heure ensemble) et celui de l'en-tête d'éditeur (toujours les deux, exigé par E4) répondent à deux besoins d'affichage réellement différents ; les fusionner créerait un formateur à modes. ✅ (tranché le 04/08/2026)

- **Phase 6 — Ancrage du menu `/` :** overlay SwiftUI positionné par calcul, **pas** un `.popover`. Un popover macOS prend la fenêtre clé, ce qui couperait la frappe : or tout l'intérêt du menu est de se filtrer pendant qu'on tape. L'overlay réutilise `EditorController.blockFrames` (déjà alimenté depuis la 5.6), aucune nouvelle `PreferenceKey`, le `NSTextView` reste premier répondant. ✅
- **Phase 6 — Espace dans la requête :** ferme le menu **seulement si la requête ne matche plus rien** (et toujours si l'espace suit immédiatement le `/`). La règle initiale "toute espace ferme" rendait morts une vingtaine d'alias multi-mots du registre et les titres eux-mêmes ("Titre 1") : incohérence entre deux livraisons parallèles, trouvée à la relecture croisée. ✅
- **Phase 6 — Portée du registre :** seuls les types de bloc au rendu **réel** sont proposés (13 commandes). Callout, tableau, image, fichier, colonnes n'y figurent pas tant que leur phase n'est pas faite - même règle d'honnêteté d'interface qu'en 5.4/5.5. Le registre est fait pour qu'une phase ultérieure y ajoute une ligne. ✅
- **Phase 6 — État après une commande `/` :** le bloc reste **en édition, caret placé**, contrairement au menu de bloc (5.4/5.5) qui laisse le bloc simplement sélectionné. Écart volontaire : ici l'utilisateur est en train de taper, l'interrompre pour le forcer à recliquer serait absurde. ✅
- **Phase 6 — `divider` :** traité hors `BlockConversion` (qui le refuserait en silence, il ne porte pas de texte et ne peut pas accueillir le caret). Le séparateur prend la place, puis un paragraphe vide focalisé le suit. ✅

## Décisions en attente
*(aucune)*

---

## Points ouverts non bloquants
- **Vérification visuelle (thème sombre + comparaison au design)** toujours impossible : autoriser **Switchboard** dans *Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran*, puis le quitter/relancer.
- **À vérifier à la main dans Xcode** (non testable sans fenêtre) : conservation de la colonne visuelle aux flèches, sélection de bloc par Échap, et sur une note de 500+ blocs le nombre de `NSTextView` réellement vivants (quelques dizaines attendues, pas 500) via Instruments.
- **Saut de barre de défilement** possible en remontant dans une note très longue : `LazyVStack` doit estimer la hauteur des blocs non matérialisés, or TextKit 2 ne la connaît qu'une fois le bloc monté. Corriger proprement demanderait un cache de hauteurs.
- **Menu `/` : ancrage au coin du bloc**, pas à la position réelle du caret. Exact pour le cas dominant (`/` en début de bloc vide), approximatif si le `/` est tapé loin dans un bloc déjà multi-lignes. Améliorable en remontant le rectangle du caret depuis TextKit 2, non fait pour l'instant.
- **Menu `/` : rognage éventuel en bas de la zone de défilement non vérifié** (pas de fenêtre disponible). C'est le risque assumé de l'overlay face au popover. À regarder à la main dans Xcode : ouvrir le menu sur le dernier bloc d'une note longue.
- **`ModelContext.insert` de SwiftData est non linéaire** (ratio 12,7 mesuré, indépendamment de notre code). Sans effet sur la frappe (0,86 ms par insertion sur une note de 500 blocs), mais l'import en masse d'une phase ultérieure devra utiliser une insertion par lot.

---

## Prochaine action concrète
La **phase 7 — Typographie & formatage** est marquée 🎨 : il faut le design **avant** de coder l'UI. Ouvrir Claude Design et demander la **barre de formatage flottante** (états, position par rapport à la sélection) et les **styles de texte H1–H6**, puis déposer le livrable dans `design/07_typographie/`. Détail de la demande dans `DESIGN_HANDOFF.md`.

Le sous-titre de note y sera traité comme un **style de paragraphe** (décision ci-dessus), donc à inclure dans la demande de design au même titre que les niveaux de titre.
