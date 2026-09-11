# STATUT — Slate

> Tableau de bord **côté utilisateur**, maintenu hors du workflow de phases (par l'orchestration, pas par Claude Code).
> Source de vérité des cases cochées : `PLAN.md`. Ce fichier ajoute le contexte (commits, qualité, décisions).
> ⚠️ Ne pas supprimer : c'est le récap que consulte Cyril. Il ne prétend pas être la source d'avancement, `PLAN.md` l'est.

**Dernière mise à jour :** fin de la phase 8.

---

## En un coup d'œil

**8 / 21 phases terminées.**

```
Fondations v0  ██████████ 100 %   (3/3)   ✅ terminé
App v1         █████░░░░░  50 %   (6/12)  ⏳ en cours
Notion v2      ░░░░░░░░░░    0 %   (0/5)   ⬜ à venir
Mobilité v3    ░░░░░░░░░░    0 %   (0/1)   ⬜ à venir
```

- **Où on en est :** phase 8 (blocs spéciaux) validée. Listes à puces/numérotées/à cocher éditables avec imbrication Tab/⇧Tab et renumérotation, bloc de code avec coloration syntaxique maison et débordement horizontal, citation, callout en 4 variantes, séparateur, et tableaux (insertion, lignes/colonnes, redimensionnement, navigation clavier). Deux fuites de données réelles trouvées en revue et corrigées (voir Décisions).
- **Prochaine étape :** **Phase 9 — Médias & pièces jointes**. Design déjà livré (artboards P2 A-D).
- **Qualité au dernier point (phase 8) :** 494 tests verts (96 `SlateModel` · 271 `SlateEditor` · 55 `SlateUI` · 57 `SlateFeatures` · 15 `SlateServices`) · build complet de l'app sans avertissement · 0 violation SwiftLint en mode `--strict`.

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
| 7 | Typographie & formatage | ✅ | 🎨 ✔️ | `3e62e82` |
| 8 | Blocs spéciaux | ✅ | 🎨 ✔️ | `PHASE8` |
| 9 | Médias & pièces jointes | ⏳ **prochaine** | 🎨 ✔️ | — |
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

- **Phase 8 — Coloration syntaxique maison, aucune dépendance tierce :** `docs/08` laissait le choix entre une bibliothèque (Highlightr, Splash) et un colorateur minimal. Retenu : maison, dans `SlateServices/SyntaxHighlighting/`. `CLAUDE.md` §6 interdit d'ajouter une dépendance tierce sans accord préalable, et le besoin réel est modeste (5 langages, 6 rôles de token) là où ces bibliothèques embarquent des centaines de langages et leurs propres thèmes, qu'il faudrait de toute façon remapper sur les tokens `code.syntax.*`. C'est un lexeur, pas un parseur : sur du code tordu il se trompe parfois de teinte, sans conséquence. ✅
- **Phase 8 — Tableau en sous-blocs, pas en grille d'attributs :** `table` -> `tableRow` -> `tableCell`. Raison technique dure : `BlockAttributes` est une propriété `@Model` sérialisée en Codable, et une grille imbriquée y produirait un conteneur *unkeyed*, ce qui déclenche le `fatalError` du composite coder de SwiftData (`docs/DEV_ENV.md`, piège n°2, déjà rencontré en phase 2 sur `RichText`). Suit en plus le précédent de `columnList`/`column`. ✅
- **Phase 8 — Suppression de la dernière ligne/colonne refusée par le modèle :** `Block+Table.swift` garde l'invariant "un tableau a toujours au moins 1 ligne et 1 colonne" et lève `.cannotRemoveLastRow`/`.cannotRemoveLastColumn`. Que devient le texte de la dernière cellule, faut-il confirmer : ce sont des questions d'interface, pas de modèle. L'éditeur traduit ce refus en dissolution du tableau entier. ✅
- **Phase 8 — `refreshDerivedText()` rendu récursif (bug préexistant) :** il ne lisait que `note.blocks` à plat, donc le texte de **tout bloc imbriqué** n'entrait jamais dans `plainText`/`snippetText` - y compris les items de liste imbriqués, en place depuis la phase 5. La recherche ne les aurait jamais trouvés. Corrigé, et `tableCell` ajouté à `textBearingTypes` pour que le contenu des cellules soit trouvable. ✅
- **Phase 8 — Purge réelle du store à la suppression d'un bloc (fuite de données) :** `BlockOperations` ne faisait que **détacher** un bloc du graphe en mémoire, sans jamais le supprimer du `ModelContext`. Chaque bloc supprimé depuis la phase 5 restait donc persisté indéfiniment, invisible dans l'interface mais bien réel, et destiné à être synchronisé vers CloudKit. Le cas du tableau était le plus grave (table + lignes + cellules orphelines d'un coup). Corrigé sur les trois chemins : menu de bloc, suppression multi-blocs, dissolution de tableau. Les enfants promus survivent bien (leur `parent` change avant la cascade), verrouillé par test. ✅
- **Phase 8 — Variante de callout :** `BlockAttributes.calloutVariant: String?` ajouté (identifiant neutre, `nil` = neutre, résolu par `SlateUI` via `SlateCalloutVariant`, repli sur `.neutral` pour une valeur inconnue). Sans ce champ, une seule variante sur les quatre du design aurait été livrable : un sélecteur sans persistance aurait été un contrôle d'apparence fonctionnelle sans effet, ce que le projet s'interdit. ✅
- **Phase 8 — Trois ponts par `rawValue` verrouillés par test :** `SyntaxTokenRole` <-> `SlateSyntaxToken`, `calloutVariant` <-> `SlateCalloutVariant`, `SyntaxLanguage` <-> `BlockAttributes.language`. Une divergence de renommage ne lèverait aucune erreur : elle rendrait simplement l'affichage monochrome ou la variante fausse. C'est le risque structurel du découpage `SlateModel` neutre / `SlateUI` porteur des couleurs. ✅
- **Phase 8 — `Tab` a deux usages disjoints :** indentation de liste via `RichTextEditingTextView.insertTab(_:)` (AppKit) et navigation entre cellules via `TableBlockContentView.onKeyPress` (SwiftUI). Deux mondes de vue séparés, aucune collision possible. ✅

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
- **Suppression générique d'un bloc simple hors éditeur** : `BlockOperations.remove(_:from:)` continue de ne faire que détacher ; c'est désormais `EditorController` qui purge le contexte. Tout futur appelant de `BlockOperations` devra faire de même, ou la logique de purge devra descendre dans `BlockOperations`.
- **Callout : les trois variantes non neutres ont un glyphe et un libellé figés** (conformément au design, qui ne laisse l'icône libre que pour la variante neutre). `CalloutBlockView` de `SlateUI` n'a pas de point d'injection d'icône : l'éditeur reconstruit la même mise en page avec les mêmes tokens plutôt que de réutiliser le composant.
- **Tableau : pas de sélecteur n x m à l'insertion** (3x3 fixe, puis menu contextuel). Aucune maquette ne le spécifiait.
- **Texte de cellule de tableau en texte simple**, pas en texte riche : la spec le remet explicitement à plus tard. L'édition de cellule n'est pas débouncée non plus (sauvegarde à chaque frappe), négligeable sur un tableau usuel mais à revoir pour un très gros tableau.
- **Citation non réellement en italique** : `QuoteBlockView.italic()` est un modificateur SwiftUI, sans effet sur le rendu interne d'un `NSTextView`. Non exigé par les critères d'acceptation.
- **Pas de previews SwiftUI sur les nouvelles vues éditables** (liste, tâche, citation, code, callout, tableau) : chacune demanderait un `ModelContainer` de test, comme `RichTextBlockView`.
- **Accessibilité de `SlateUI` non localisée** : les `accessibilityLabel` de `QuoteBlockView`, `ChecklistItemView`, `DividerBlockView`, `BlockHandle` sont des chaînes françaises en dur. Le package n'a aucun catalogue `.xcstrings`. Dette antérieure à la phase 8.
- **Pas de protection anti-cycle dans `refreshDerivedText()`** : aucun chemin de code ne peut construire un cycle parent/enfant aujourd'hui, le risque est théorique.
- **`---` vers séparateur** non implémenté : raccourci markdown réservé à la phase 15.
- **Rendu visuel de la phase 8 non vérifié** (coloration syntaxique, débordement du bloc de code, glisser de redimensionnement de colonne, menu contextuel de cellule, apparition de la barre d'outils au survol) : aucune fenêtre disponible. Seule la logique pure est couverte par les tests.

## Prochaine action concrète
La **phase 9 — Médias & pièces jointes** (images : insertion, redimensionnement, légende, alignement ; fichiers joints : icône par type, ouverture, révélation dans le Finder). Design déjà livré : artboards **A à D** de `design/_design_complet/Slate P2 - Médias & pièces jointes.dc.html`, avec les tokens §16 quater.

Le modèle est déjà prêt : `Attachment` existe (`@Attribute(.externalStorage) data`, `uti`, `width`, `height`) et `Block.attachment` est en place avec sa cascade depuis la phase 2. C'est la phase la plus à risque côté stockage : le doc insiste sur la séparation binaire/métadonnées (`externalStorage` et/ou `CKAsset`, jamais de gros binaire en base) et sur l'empreinte mémoire. Un `AttachmentService` est à créer dans `SlateServices`.
