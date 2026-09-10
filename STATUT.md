# STATUT — Slate

> Tableau de bord **côté utilisateur**, maintenu hors du workflow de phases (par l'orchestration, pas par Claude Code).
> Source de vérité des cases cochées : `PLAN.md`. Ce fichier ajoute le contexte (commits, qualité, décisions).
> ⚠️ Ne pas supprimer : c'est le récap que consulte Cyril. Il ne prétend pas être la source d'avancement, `PLAN.md` l'est.

**Dernière mise à jour :** fin de la phase 7.

---

## En un coup d'œil

**7 / 21 phases terminées.**

```
Fondations v0  ██████████ 100 %   (3/3)   ✅ terminé
App v1         ████░░░░░░  42 %   (5/12)  ⏳ en cours
Notion v2      ░░░░░░░░░░    0 %   (0/5)   ⬜ à venir
Mobilité v3    ░░░░░░░░░░    0 %   (0/1)   ⬜ à venir
```

- **Où on en est :** phase 7 (typographie & formatage) validée. Les 8 marques inline (gras, italique, souligné, barré, code en ligne, surlignage, couleur de texte, lien), la barre de formatage flottante, les palettes de couleur, le popover de lien, les raccourcis ⌘B/I/U/⇧X/E/K et ⌥⌘0-3, et les titres H1–H6 enfin **réellement éditables**.
- **Prochaine étape :** **Phase 8 — Blocs spéciaux** (code, citation, callout, listes, tableaux). Design déjà livré (artboards P1 E-H), plus aucun aller-retour design nécessaire pour aucune phase.
- **Qualité au dernier point (phase 7) :** 411 tests verts (73 `SlateModel` · 232 `SlateEditor` · 48 `SlateUI` · 57 `SlateFeatures` · 1 `SlateServices`) · build complet sans avertissement nouveau · 0 violation SwiftLint.

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
| 7 | Typographie & formatage | ✅ | 🎨 ✔️ | `PHASE7` |
| 8 | Blocs spéciaux | ⏳ **prochaine** | 🎨 ✔️ | — |
| 9 | Médias & pièces jointes | ⬜ | 🎨 ✔️ | — |
| 10 | Glisser-déposer & colonnes | ⬜ | — | — |
| 11 | Organisation des notes | ⬜ | — | — |
| 12 | Verrouillage de note | ⬜ | — | — |
| 13 | Thèmes & apparence | ⬜ | 🎨 ✔️ | — |
| 14 | Raccourcis clavier | ⬜ | — | — |

### Jalon v2 — Puissance Notion
| # | Phase | Statut | Design | Commit |
|---|---|---|---|---|
| 15 | Markdown natif à la frappe | ⬜ | — | — |
| 16 | Liens internes & sous-pages | ⬜ | — | — |
| 17 | Bases de données | ⬜ | 🎨 ✔️ | — |
| 18 | Fonctionnalités IA | ⬜ | 🎨 ✔️ | — |
| 19 | Espaces de travail (workspaces) | ⬜ | 🎨 ✔️ | — |

### Jalon v3 — Mobilité
| # | Phase | Statut | Design | Commit |
|---|---|---|---|---|
| 20 | Portage iOS | ⬜ | 🎨 ✔️ | — |

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

- **Phase 7 — `FormattingController` -> extension d'`EditorController` :** `docs/07` prévoyait un contrôleur dédié. Livré comme `EditorController+Formatting.swift`, sur le motif déjà en place pour `+Selection` et `+SlashMenu`. Un second contrôleur `@Observable` propriétaire d'une partie de l'état d'édition aurait créé deux sources de vérité pour la sélection. ✅
- **Phase 7 — Couleur de texte inline :** le modèle n'avait que `highlight`, alors que `docs/07` et l'artboard B demandent aussi la couleur de texte. Ajout de `SlateTextColor` / `SlateTextColorAttribute` (nom persisté `slateTextColor`) et de `InlineMark.textColor`, calqués à l'identique sur le motif éprouvé du surlignage. ✅
- **Phase 7 — Ancrage de la barre flottante :** même choix qu'en phase 6, overlay positionné par calcul et non `.popover`, pour ne pas voler la fenêtre clé. Le rectangle de sélection est remonté depuis TextKit 2 (`selectionBoundingRectForFormatting()`) et décalé par l'origine du cadre de bloc déjà connu via `blockFrames` : aucune nouvelle `PreferenceKey`. ✅
- **Phase 7 — `text.link` n'est pas l'accent brut :** `tokens.md` §2 le donne égal à `accent.default`, mais la note de §7 impose une variante lisible dès que l'accent est posé en texte (l'accent vert brut tombe à 2,0:1). Token `textLink` dédié, à **dériver** de l'accent courant en phase 13 quand il deviendra personnalisable. ✅
- **Phase 7 — Bouton destructif :** deux tokens distincts, `semanticError` (glyphes et aplats uniquement) et `semanticErrorFill` (#C4271E, seul aplat portant du texte blanc). Un test verrouille le fait que `#FF3B30` + blanc = 3,94:1, sous l'AA : c'est ce qui justifie la seconde variante plutôt qu'un caprice de nuance. ✅
- **Phase 7 — Recherche de notes du popover de lien :** volontairement **non branchée**. La maquette C montre "chercher une note" et "Créer une note", mais c'est la phase 16 (liens internes). Le champ et la structure sont en place, désactivés. Même règle d'honnêteté d'interface qu'en 5.4/5.5 et 6. ✅
- **Phase 7 — `text.placeholder` corrigé :** l'ancienne valeur (opacité 0,25) donnait 1,83:1, très loin de l'AA. Portée à 0,55 clair / 0,60 sombre (0,70/0,78 en Increase Contrast). `text.disabled` reste à 0,25, c'est son rôle. ✅
- **Phase 7 — `design/tokens.md` resynchronisé :** `design/_design_complet/uploads/tokens.md` était une version plus récente (315 lignes contre 263). Reportée dans `design/tokens.md`, qui reste la source de vérité unique : §16 bis (callouts), §16 ter (`code.syntax.*`), §16 quater (médias), table `text.onAccent` par accent. ✅

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
- **Raccourcis de formatage sans sélection** (caret seul) : sans effet pour l'instant. Appliquer une marque « en attente » qui s'applique au texte tapé ensuite demanderait de gérer les *typing attributes* du `NSTextView`. Les critères d'acceptation de `docs/07` sont tous formulés sur une sélection, donc hors périmètre livré, mais c'est un geste courant : à faire.
- **Ouverture des liens en ⌘+clic non vérifiée** : repose sur le comportement natif d'`NSTextView.clicked(onLink:at:)`, non surchargé. Standard et plausible, mais à confirmer à la main dans Xcode.
- **Interligne des titres uniforme** : `applyTypography` applique 1,5 à tous les niveaux, alors que `tokens.md` §9 spécifie 1,2 à 1,4 selon le niveau. Simplification héritée de la phase 5, pas une régression de la 7.
- **Barre flottante et popovers : positionnement pixel non vérifié** (pas de fenêtre disponible), même limite que le menu `/` en phase 6. La logique de bascule au-dessus/en-dessous est, elle, testée unitairement.
- **`HeadingBlockContentView` est devenu du code mort** : les titres passent désormais par `RichTextBlockView`. Conservé pour ses previews SwiftUI, à supprimer si elles cessent de servir.

## Prochaine action concrète
La **phase 8 — Blocs spéciaux** (code avec coloration syntaxique, citation, callout, listes puces/numéros/tâches, tableaux). Le design est déjà là : artboards **E à H** de `design/_design_complet/Slate P1 - Formatage & blocs.dc.html`, et les composants SwiftUI de référence `design/_design_complet/SlateUI/BlockViews.swift` + `BlockTokens.swift` couvrent callout, citation, code, listes, checklist et divider. Seule la vue de tableau est à écrire de zéro.

Deux décisions ouvertes dans `docs/08` à trancher au passage : la structure de données du tableau (attributs dédiés ou sous-blocs) et la coloration syntaxique (bibliothèque tierce ou colorateur maison minimal). Rappel `CLAUDE.md` §6 : aucune dépendance tierce sans accord préalable de Cyril.
