# STATUT — Slate

> Tableau de bord **côté utilisateur**, maintenu hors du workflow de phases (par l'orchestration, pas par Claude Code).
> Source de vérité des cases cochées : `PLAN.md`. Ce fichier ajoute le contexte (commits, qualité, décisions).
> ⚠️ Ne pas supprimer : c'est le récap que consulte Cyril. Il ne prétend pas être la source d'avancement, `PLAN.md` l'est.

**Dernière mise à jour :** fin de la phase 11.

---

## En un coup d'œil

**11 / 21 phases terminées.**

```
Fondations v0  ██████████ 100 %   (3/3)   ✅ terminé
App v1         ████████░░  75 %   (9/12)  ⏳ en cours
Notion v2      ░░░░░░░░░░    0 %   (0/5)   ⬜ à venir
Mobilité v3    ░░░░░░░░░░    0 %   (0/1)   ⬜ à venir
```

- **Où on en est :** phase 11 (organisation des notes) validée. Menus contextuels avec sélection multiple et libellés comptés, duplication profonde réellement indépendante, déplacement vers un dossier, épinglage, favori, corbeille complète avec restauration, suppression définitive nommée et purge automatique à 30 jours.
- **Prochaine étape :** **Phase 12 — Verrouillage de note** (Touch ID, mot de passe, Keychain). Design déjà livré (artboards P3 B-C).
- **Qualité au dernier point (phase 11) :** 641 tests verts (96 `SlateModel` · 325 `SlateEditor` · 84 `SlateUI` · 57 `SlateServices` · 79 `SlateFeatures`) · build complet de l'app sans avertissement · 0 violation SwiftLint en mode `--strict`.

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
| 8 | Blocs spéciaux | ✅ | 🎨 ✔️ | `89c3d55` |
| 9 | Médias & pièces jointes | ✅ | 🎨 ✔️ | `4c27bf6` |
| 10 | Glisser-déposer & colonnes | ✅ | 🎨 ✔️ | `6462112` |
| 11 | Organisation des notes | ✅ | 🎨 ✔️ | `d568887` |
| 12 | Verrouillage de note | ⏳ **prochaine** | 🎨 ✔️ | — |
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

- **Phase 9 — Stockage par `externalStorage`, pas de `CKAsset` manuel :** `Attachment.data` porte déjà `@Attribute(.externalStorage)` depuis la phase 2, et SwiftData le traduit lui-même en `CKAsset` à la synchronisation. Rien à écrire côté CloudKit : la base ne contient que métadonnées et référence. Vérifié en revue qu'aucun chemin ne recopie un binaire dans un champ ordinaire, ni dans `BlockAttributes`, ni dans `plainText`/`snippetText`. ✅
- **Phase 9 — Bornes d'import :** côté le plus long à 2000 px, qualité JPEG 0,72, PNG conservé si l'image a un canal alpha, refus au-delà de 2 Go. 2000 px couvre le palier de débord (960 pt en Retina 2x = 1920 px) sans stocker les 4000 à 6000 px d'un capteur récent. La lecture de taille passe par `resourceValues`, et le redimensionnement par `CGImageSourceCreateThumbnailAtIndex` : le fichier n'est jamais chargé en entier juste pour être mesuré. ✅
- **Phase 9 — Un GIF n'est jamais recompressé :** `CGImageDestination` n'encode qu'une image par appel, donc repasser un GIF par le pipeline détruirait silencieusement son animation. Il est seulement borné en taille comme tout fichier. ✅
- **Phase 9 — Un `block.attachment = nil` laisse la ligne orpheline :** même classe de bug que celle corrigée en phase 8 sur les blocs, mais sur des binaires, donc bien plus coûteuse. `AttachmentService.removeAttachment`/`replaceAttachment` encapsulent le bon ordre d'opérations. L'ordre compte : `context.delete(old)` **avant** de détacher la relation provoque un crash SwiftData réel (`Never access a full future backing data`). ✅
- **Phase 9 — Garde contre la suppression d'un bloc pendant un import en vol :** l'import est asynchrone ; si l'utilisateur supprime le bloc entre-temps, le retour d'import touchait un `Block` déjà retiré du contexte et faisait planter le process. Piège découvert au passage : **`block.isDeleted` redevient `false` après un `save()`** qui a pourtant supprimé l'objet (SwiftData ne le maintient à `true` que dans la fenêtre non sauvegardée). Le seul signal fiable est `block.modelContext == nil`. ✅
- **Phase 9 — Alignement et palier de largeur sont un seul réglage :** le design n'expose qu'une barre unique mêlant les deux, d'où un unique `imageAlignment` (5 cas) plutôt que deux champs parallèles. ✅
- **Phase 9 — Locale paramétrable plutôt que figée :** `formattedFileSize` et les libellés de type forçaient `fr_FR` pour rendre les tests déterministes. Un utilisateur anglais aurait lu "1,8 Mo" au lieu de "1.8 MB". La locale est devenue un paramètre (défaut `.current`) : le déterminisme d'un test vient de la locale qu'il injecte, jamais d'une locale figée en production. ✅

- **Phase 10 — `DropDelegate` historique plutôt que `dropDestination` :** le `dropDestination(for:action:isTargeted:)` moderne ne donne la position du pointeur qu'au dépôt final (`isTargeted` n'est qu'un booléen), or la ligne d'insertion doit suivre le pointeur en continu. `DropDelegate.dropUpdated(info:)` est le seul point d'entrée SwiftUI qui fournit `info.location` à chaque déplacement. ✅
- **Phase 10 — Sortie de colonne sans toucher au chemin par défaut :** `EditorContentColumn` enveloppe toute la liste de blocs d'un coup et est partagé par l'en-tête de note ; le modifier à la racine aurait risqué toute la mise en page de l'éditeur. Retenu : le conteneur publie sa largeur mesurée dans l'environnement (mesure passive en arrière-plan, jamais un `GeometryReader` en corps de vue qui forcerait une taille infinie), et le bloc qui déborde applique un `frame` sur son propre contenu. Le bord gauche ne bouge donc jamais, ce qui préserve l'alignement vertical des poignées de chrome et la marge commune exigée par la spec E4. ✅
- **Phase 10 — Garde anti-cycle au dépôt :** déposer un bloc dans son propre sous-arbre est refusé. Ce n'est pas une précaution théorique : le glisser-déposer est le **premier chemin du projet capable de créer un cycle parent/enfant**, et `refreshDerivedText()` est récursif depuis la phase 8 sans protection - ce qui était acceptable tant qu'aucun chemin ne pouvait en produire un. ✅
- **Phase 10 — Dissolution des colonnes :** une colonne vidée disparaît ; s'il ne reste qu'une colonne, le `columnList` disparaît aussi et son contenu remonte au niveau du document. Les blocs de structure retirés sont **réellement purgés du `ModelContext`** par `EditorController`, `ColumnStructure` se contentant de détacher - même partage de responsabilité qu'en phase 8, et même piège évité. ✅
- **Phase 10 — Un bug de cache trouvé en chemin :** `BlockOrdering.detachPreservingChildren(_:)` n'invalide pas le cache par contrat ; enchaîner deux détachements sans lecture intermédiaire faisait réapparaître un bloc fantôme à la racine. Corrigé en réutilisant `BlockOrdering.insert(_:after:)`, qui invalide déjà, plutôt qu'en réécrivant une insertion maison. ✅
- **Phase 10 — Gestes non concurrents :** redimensionnement d'image, de colonne de tableau, de colonnes, et sélection de plage passent tous par `DragGesture`, un mécanisme distinct de `.draggable`/`onDrop(delegate:)`. Le `DropDelegate` est attaché une seule fois, sur le conteneur qui porte déjà l'espace de coordonnées de la liste de blocs : aucune interception croisée possible par construction. ✅

- **Phase 11 — Service simple, adaptateur côté interface :** `NoteActionsService` opère sur **une note à la fois, sans `throws` artificiel** (aucune de ces opérations ne peut réellement échouer côté modèle), et `SlateFeatures` fournit un adaptateur qui boucle pour les lots. Le traitement par lots est une préoccupation d'interface ; ajouter du `throws` à des opérations infaillibles aurait été du bruit à chaque site d'appel. ✅
- **Phase 11 — Duplication profonde :** parcours récursif générique de `Block.children`, donc tableaux et colonnes sont couverts par le même algorithme, sans cas particulier. Tous les identifiants sont régénérés (les partager serait une corruption silencieuse), `RichText` et `BlockAttributes` sont des types valeur donc leur copie est déjà indépendante, et les dérivés sont recalculés plutôt que recopiés. L'indépendance est prouvée dans les deux sens par test. ✅
- **Phase 11 — Purge automatique, prédicat défensif :** filtrage SwiftData sur `isTrashed`, puis exigence en mémoire que `trashedAt` ne soit pas nul - une note en corbeille sans date n'est **jamais** purgée, même si cet état ne devrait pas exister. Bornes testées exactement : J-31 purgé, J-30 et J-29 conservés. C'est la seule suppression irréversible et automatique de l'app, d'où ce niveau de précaution. ✅
- **Phase 11 — Confirmation de suppression reconstruite à la main :** le design exige que le bouton destructif ait le focus **sans** être déclenché par Entrée. Un `NSAlert` natif lie toujours son bouton par défaut à Entrée, d'où une confirmation reconstruite. Non vérifiable sans fenêtre. ✅
- **Phase 11 — Favori ajouté au menu contextuel** bien que la maquette A ne le montre pas : `docs/11` en fait un livrable et un critère d'acceptation, et la section Favoris de la barre latérale existe depuis la phase 3 - sans cette action elle serait impossible à remplir, ce qui est plus gênant qu'un écart de maquette. ✅

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
- ~~REPORT PHASE 9~~ **SOLDÉ en phase 10** - dépôt de fichiers n'importe où dans l'éditeur (artboard C de P2 : ligne d'insertion entre deux blocs, badge de comptage à partir de 2 fichiers, voile de dépôt sur la note entière, plusieurs fichiers déposés créant plusieurs blocs). Livré en phase 9 : le dépôt **sur la zone vide d'un bloc** média. Non livré : le dépôt libre dans l'éditeur, qui partage toute son infrastructure de détection de frontière avec le glisser-déposer de blocs, c'est-à-dire la phase 10. Les deux doivent être construits dans la même passe plutôt que deux fois.
- ~~REPORT PHASE 9~~ **SOLDÉ en phase 10** - paliers de largeur hors colonne (débord 960 pt, pleine largeur). `EditorContentColumn` plafonne la largeur à 720 + 48 pt et enveloppe **toute la liste de blocs d'un coup**, pas chaque bloc : aucun bloc ne peut sortir de la colonne aujourd'hui. Les deux paliers ne sont donc volontairement **pas proposés** (`EditorController.availableImageAlignments`), plutôt qu'affichés sans effet - même règle d'honnêteté d'interface qu'en phase 6. Les largeurs restent calculées, prêtes à servir. La phase 10 doit de toute façon revoir ce conteneur pour la mise en colonnes.
- **Barre de progression d'import sans pourcentage réel** : l'import est synchrone (décodage ImageIO), lancé en `Task.detached` pour ne pas geler l'interface, mais la barre ne progresse pas continûment.
- **⌘V ne crée un bloc image que sur une image déjà sélectionnée**, pas pendant la frappe dans un bloc de texte. Intercepter le collage dans TextKit est un sous-système délicat, laissé de côté volontairement. Vérifié que le collage de texte ordinaire n'est pas cassé.
- **"1 pages" au singulier** : le libellé de métadonnées PDF n'a pas de forme plurielle. Cosmétique, demanderait une pluralisation.
- **`SlateServices` n'a aucun catalogue `.xcstrings`** : ses libellés de type de fichier et ses messages d'erreur passent par une table FR/EN interne, avec locale paramétrable. Cohérent et testable, mais ce n'est pas le mécanisme standard du projet. Chantier léger et distinct si tu veux l'aligner.
- **Deux teintes dérivées faute de valeur au design** : la ligne de cause d'erreur en thème clair et la pastille de tableur en thème sombre n'ont pas de valeur dans les maquettes, elles ont été dérivées par cohérence. À valider à l'œil.
- **Aucune vérification visuelle de la phase 9** : les 4 états du bloc image, le geste de redimensionnement, le popover de menu média et l'expérience VoiceOver ne sont couverts que par lecture de code et tests de logique. Aucune fenêtre n'était disponible, ni pour les agents livreurs, ni pour la revue.
- **Aperçu de glisser non personnalisé** : `BlockDragGhostView` a été construit mais n'est pas injecté, l'API `.draggable` exposée par `BlockHandle` n'ayant pas de paramètre d'aperçu. macOS affiche son instantané par défaut. Le brancher demanderait de faire passer un constructeur d'aperçu à travers trois signatures et deux packages, pour un effet purement cosmétique invérifiable sans fenêtre : laissé tel quel, le composant reste disponible.
- **Pas de voile distinct au dépôt sur la note entière** : un dépôt hors de tout bloc ajoute à la fin, ce qui est fonctionnellement correct, mais sans le voile `accent.subtle` dédié de l'artboard C.
- **Glisser annulé hors fenêtre** (Échap, relâché ailleurs) : nettoyé au `dropExited`, faute de hook SwiftUI fiable côté source. Évite un état bloqué, mais le bloc source cesse d'être estompé un peu plus tôt que le design ne le décrit.
- **Rendu du glisser-déposer jamais observé** : c'est précisément ce qui se vérifie le moins bien par des tests. Ligne d'insertion suivant le pointeur, empilement des colonnes sous 560 pt, redimensionnement du séparateur : uniquement couverts par la logique pure et la compilation.
- **`swift test` en parallèle sur plusieurs packages produit des échecs fantômes** (`error: fatalError`, symboles introuvables) à cause du `.build` partagé. Rencontré deux fois, sans aucun rapport avec le code. Toujours relancer le package seul avant de conclure.
- **PIÈGE D'ENVIRONNEMENT, vaut pour tout le projet : `swift test` en ligne de commande ne compile pas les `.xcstrings`.** `String(localized:)` y renvoie donc la **clé brute**, jamais la traduction. Un test qui compare à du texte français figé échoue à tort hors Xcode. Convention à suivre (déjà en place dans `NoteHeaderMetadataFormatterTests`) : recomposer l'attendu avec les mêmes clés et gabarits localisés, jamais du texte en dur.
- **Verrouiller et Exporter : entrées présentes mais désactivées.** Le verrouillage arrive en phase 12. L'export n'a ni mécanisme ni spécification de format, et n'est listé dans aucun livrable : l'entrée reste visible et désactivée, conformément à la règle du design ("désactivé, jamais masqué").
- **Lien interne `slate://note/<uuid>` provisoire** : copié dans le presse-papiers, mais aucun résolveur de ce schéma n'existe encore. À traiter en phase 16 (liens internes).
- **"Déplacer vers" liste les dossiers à plat**, sans regroupement par section.
- **Raccourcis du menu contextuel actifs seulement menu ouvert** (⌃⌘P, ⌘D, ⌘⌫) : un raccourci global demanderait une `CommandGroup` au niveau de l'app, ce qui relève de la phase 14.
- **Sélection multiple par Cmd/Maj-clic lue via `NSEvent.modifierFlags`** : aucune autre voie SwiftUI sur macOS pour ce geste.

## Prochaine action concrète
La **phase 12 — Verrouillage de note**. Design déjà livré : artboards **B** (cas de la note verrouillée en corbeille) et **C** (écran de note verrouillée, dialogue de définition du mot de passe) de `design/_design_complet/Slate P3 - Organisation & sécurité.dc.html`.

`Note.isLocked` existe depuis la phase 2, et la corbeille gère déjà le cas "Déverrouiller pour restaurer". Restent à construire : un `LockService` dans `SlateServices` basé sur `LocalAuthentication`, le stockage du secret dans le **Keychain** (jamais en clair, jamais dans SwiftData ni CloudKit), l'écran de verrou, et le re-verrouillage automatique.

C'est la phase la plus sensible du jalon : le doc réclame une **revue de sécurité dédiée**. Le risque principal n'est pas le déverrouillage lui-même mais la **fuite par les chemins latéraux** : `Note.plainText` et `snippetText` sont des champs dérivés en clair, alimentés par `refreshDerivedText()`, et la recherche de la phase 4 les interroge. Une note verrouillée ne doit exposer ni contenu, ni extrait, ni pièces jointes. Le niveau de chiffrement réel des blocs (au-delà de la simple exclusion) reste une décision ouverte de `docs/12`.
