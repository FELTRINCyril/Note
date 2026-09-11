# Raccourcis clavier de Slate

> Document de référence de la Phase 14 (`docs/14_raccourcis_clavier.md`, dernière phase
> du jalon v1). Recense l'ensemble des raccourcis clavier de l'application, groupés par
> portée. Source de vérité pour la partie testable (registre de non-conflit) :
> `Packages/SlateFeatures/Sources/SlateFeatures/Shortcuts/KeyboardShortcutRegistry.swift`.
>
> Convention d'état :
> - **Actif** : la combinaison déclenche réellement l'action aujourd'hui, quelque part
>   dans l'application (frappe directe dans l'éditeur, bouton local, ou commande de la
>   barre de menu).
> - **À venir** : documentée pour mémoire, aucune combinaison n'est encore assignée.
>
> Aucune entrée n'est présentée comme active si elle ne l'est pas réellement (règle
> d'honnêteté d'interface du projet, appliquée ici comme dans le reste de
> l'application).

## Portée globale

Toujours actifs, quelle que soit la fenêtre au premier plan.

| Raccourci | Action | État |
|---|---|---|
| `⌘N` | Nouvelle note (dans le dossier sélectionné) | Actif |
| `⌘⇧N` | Nouveau dossier | Actif |
| `⌘1` | Afficher/masquer la barre latérale | Actif |
| `⌘2` | Afficher/masquer la colonne liste | Actif |
| `⌃⌘F` | Mode focus (masque barre latérale et liste) | Actif |
| `⌃⌘1` | Donner le focus clavier à la barre latérale | Actif |
| `⌃⌘2` | Donner le focus clavier à la colonne liste | Actif |
| `⌃⌘3` | Donner le focus clavier à l'éditeur (sélectionne le premier bloc) | Actif |
| `⌘⇧F` | Recherche plein texte globale | À venir (Phase 15) |

Note sur la recherche : un champ de filtre existe déjà dans la colonne liste
(`NoteListView`), mais il ne filtre que le dossier affiché et n'a aucun raccourci
clavier dédié pour y placer le focus. La recherche plein texte annoncée par
`docs/14_raccourcis_clavier.md` est le sujet de la Phase 15 ; le bouton de recherche de
la barre d'outils est d'ailleurs déjà désactivé pour la même raison.

Note sur le choix de `⌃⌘1`/`⌃⌘2`/`⌃⌘3` : `docs/14_raccourcis_clavier.md` suggérait
`⌘1`/`⌘2`/`⌘3`, mais `⌘1` et `⌘2` sont déjà pris depuis la Phase 3 pour afficher/masquer
la barre latérale et la colonne liste (une fonctionnalité différente, déjà livrée) ;
`⌘⌥1`/`⌘⌥2`/`⌘⌥3` sont eux pris par les conversions de titre du menu Format. `⌃⌘`
restait la seule combinaison encore libre pour les trois panneaux, cohérente avec
`⌃⌘F` (mode focus) déjà en usage juste au-dessus. Le focus de la barre latérale et de
la liste déplace le focus clavier réel (`@FocusState` partagé avec `MainWindowView`,
voir `SlatePanelFocus`) vers leur zone de défilement ; la première flèche pressée
ensuite sélectionne alors le dossier/la note courante exactement comme un clic
l'aurait fait. Le focus de l'éditeur sélectionne le premier bloc de la note affichée
(`EditorController.selectBlock(_:)`, le même point d'entrée déjà utilisé par un clic
simple sur un bloc) : `Retour` permet ensuite d'entrer en édition. Aucun de ces trois
raccourcis ne touche au focus AppKit interne de l'éditeur (premier répondant,
`NSTextView`) : ils s'appuient sur des mécanismes déjà existants et déjà exercés par
la souris.

## Navigation

Déplacement entre panneaux et entre notes. Chaque raccourci n'est actionnable que
lorsque le panneau correspondant a le focus clavier (mutuellement exclusifs, jamais
actifs en même temps).

| Raccourci | Action | État |
|---|---|---|
| `↑` / `↓` (barre latérale) | Dossier précédent/suivant | Actif |
| `←` / `→` (barre latérale) | Replier/déplier un dossier (ou aller à son parent/premier enfant) | Actif |
| `↑` / `↓` (liste de notes) | Note précédente/suivante | Actif |
| `Retour` (liste de notes) | Ouvrir la note sélectionnée dans la colonne détail | Actif |

## Actions de note

Épingler, dupliquer, verrouiller, mettre à la corbeille. Actifs à la fois depuis le
menu contextuel (clic droit sur une note, Phase 11) et depuis le menu **Édition** de la
barre de menu (Phase 14), et opèrent sur la même sélection dans les deux cas.

| Raccourci | Action | État |
|---|---|---|
| `⌃⌘P` | Épingler/désépingler la sélection | Actif (menu contextuel **et** barre de menu) |
| `⌘D` | Dupliquer la sélection | Actif (menu contextuel **et** barre de menu) |
| `⌃⌘L` | Verrouiller la note (jamais déverrouiller, qui exige une authentification) | Actif (menu contextuel **et** barre de menu) |
| `⌘⌫` | Mettre la sélection à la corbeille | Actif (menu contextuel **et** barre de menu) |

Avant cette phase, ces quatre raccourcis n'étaient actifs que le menu contextuel déjà
ouvert (il fallait faire un clic droit avant de pouvoir les utiliser) : c'était le
manque explicitement documenté dans `STATUT.md`. Ils sont désormais également exposés
comme de vraies commandes de la barre de menu (`SlateAppCommands`, menu Édition),
opérant sur la sélection courante de la colonne liste (ou, à défaut, la note affichée
dans la colonne détail). Une entrée se désactive automatiquement si aucune note n'est
sélectionnée, ou - pour "Verrouiller" - si la sélection contient déjà une note
verrouillée.

## Édition de blocs

À l'intérieur de l'éditeur, sur un bloc en cours de saisie ou sélectionné.

| Raccourci | Action | État |
|---|---|---|
| `Retour` | Nouveau bloc (paragraphe suivant) | Actif |
| `Retour arrière` (bloc vide/début de bloc) | Fusionner avec le bloc précédent | Actif |
| `↑` / `↓` (en bordure du bloc) | Naviguer vers le bloc précédent/suivant | Actif |
| `Tab` | Indenter (imbriquer dans l'item précédent) | Actif |
| `⇧Tab` | Désindenter | Actif |
| `⌃⌘↑` / `⌃⌘↓` | Déplacer le bloc (ou la plage sélectionnée) d'un cran | Actif |
| `Échap` (dans un paragraphe) | Sélectionner le bloc entier (sort du texte) | Actif |
| `Espace` (bloc sélectionné seul) | Ouvrir le menu du bloc (identique à la poignée) | Actif |
| `/` (en début de bloc) | Ouvrir le menu de commandes `/` (insertion de bloc) | Actif |
| `⌥←` / `⌥→` (image sélectionnée) | Changer l'alignement/la largeur de l'image | Actif |
| `⌘V` (image sélectionnée) | Coller une image depuis le presse-papiers | Actif |
| `Tab` (dans un tableau) | Cellule suivante (ajoute une colonne en fin de ligne) | Actif |
| `↑` / `↓` (dans un tableau) | Cellule au-dessus/en-dessous | Actif |
| `⌃⌥C` (survol d'un bloc de code) | Copier le contenu du bloc de code | Actif |

Le menu du bloc (`Espace`, ou clic sur la poignée) donne accès au clavier à
Dupliquer/Convertir/Déplacer/Supprimer sans raccourci dédié supplémentaire - ces
actions sont déjà atteignables entièrement au clavier via ce menu.

## Formatage

Marques de texte riche et conversions de type de bloc, actives dès qu'une sélection
(ou un caret) est présente dans un bloc de texte.

| Raccourci | Action | État |
|---|---|---|
| `⌘B` | Gras | Actif |
| `⌘I` | Italique | Actif |
| `⌘U` | Souligné | Actif |
| `⌘⇧X` | Barré | Actif |
| `⌘E` | Code en ligne | Actif |
| `⌘K` | Insérer/modifier un lien | Actif |
| `⌘⌥0` | Convertir en paragraphe | Actif |
| `⌘⌥1` | Convertir en titre 1 | Actif |
| `⌘⌥2` | Convertir en titre 2 | Actif |
| `⌘⌥3` | Convertir en titre 3 | Actif |

**Arbitrage `⌘K`** : `docs/14_raccourcis_clavier.md` proposait aussi `⌘K` pour une
palette de commandes globale (optionnelle dans ce document). `⌘K` reste l'insertion de
lien, livrée en Phase 7 et déjà utilisée par convention dans tous les éditeurs de texte
riche. Aucune palette de commandes globale n'existe dans le code, et cette phase de
consolidation n'en construit pas : ce n'était un critère d'acceptation d'aucune phase.

**Menu Format de la barre de menu** : ces dix raccourcis sont déjà pleinement actifs
pendant la frappe (interceptés directement par l'éditeur de blocs, `SlateEditor`), mais
leurs entrées dans le menu **Format** de la barre de menu sont volontairement
**désactivées**. Un item de menu actif sur la même combinaison intercepterait
l'événement clavier avant qu'il n'atteigne l'éditeur (la barre de menu est interrogée
en premier par AppKit) : les activer casserait un raccourci déjà livré, pour un gain
purement cosmétique. Elles restent affichées, grisées, pour la découvrabilité visuelle
du menu.
