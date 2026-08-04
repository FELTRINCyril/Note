# Brief design — Slate

> **À lire d'abord** : `PLAN.md` (roadmap + fonctionnalités) et les docs `docs/*.md` décrivent le **produit et son comportement**. Ce document ne traite que du **visuel et de l'interaction**.
> Le détail granulaire des variables (couleurs, typo, espacements, durées…) vit dans `design/tokens.md` — **le remplir est un livrable de ce brief**.

**Cible** macOS, application de bureau native SwiftUI (macOS 15). Fenêtre redimensionnable, de ~1000×700 au plein écran. iOS viendra ensuite à partir du même code — le garder à l'esprit, mais **ne pas maquetter iOS pour l'instant** (voir §7 pour ce qui doit rester adaptable).

---

## 1. Ce qu'on attend en sortie

1. Maquettes des **écrans de la §3**, en thème clair **et** sombre.
2. Maquettes des **apparences de blocs de la §4**, chacune avec ses états.
3. La **spec de design tokens** de `design/tokens.md` **entièrement remplie** (couleurs clair+sombre, typo, espacements, rayons, ombres, durées d'animation), exploitable directement en SwiftUI.
4. Les **états secondaires** : chargement/sync, vide, erreur, note verrouillée, corbeille.
5. Les **composants réutilisables** de la §5.

---

## 2. Direction artistique

**Intention** : *l'écriture est l'héroïne.* Slate doit avoir le **calme de Notes d'Apple** avec la **puissance de Notion** — sans en prendre le côté chargé. Le chrome s'efface, la page respire, mais tout le pouvoir d'un éditeur de blocs est là dès qu'on en a besoin. La tension centrale à résoudre : **densité fonctionnelle sans bruit visuel**.

**Pistes**
- Ancrage macOS assumé : `NavigationSplitView` à 3 colonnes, matériaux translucides pour la sidebar, toolbar système. On ne réinvente pas la navigation.
- Chrome **neutre et désaturé** ; **une seule couleur d'accent**, personnalisable par l'utilisateur, qui porte l'identité (sélection, liens, focus, boutons primaires).
- **Colonne de texte généreuse et centrée** dans l'éditeur, avec une largeur de lecture confortable — c'est la respiration qui distingue Slate d'un Notion dense.
- Les commandes avancées (poignée de bloc, bouton `+`, barre de formatage) sont **révélées au survol / à la sélection**, jamais imposées en permanence.
- Hiérarchie typographique nette : titre de note, sous-titre, titre secondaire, H1–H6, corps, monostyle — chaque niveau doit se distinguer sans effort.
- Animations **discrètes et courtes** : apparition d'un bloc, ouverture du menu `/`, transition de thème. Pas de célébration, pas d'effet gratuit.

**À éviter** : ombres portées lourdes, dégradés, skeuomorphisme papier, barres d'outils toujours visibles qui encombrent, gamification, sur-animation, couleurs criardes hors de l'accent choisi.

---

## 3. Inventaire des écrans

### E1 — Fenêtre principale (coquille 3 colonnes)  · *Phase 3*
Sidebar | liste de notes | éditeur. Colonnes **repliables** comme Notes. Proportions par défaut à proposer, comportements de collapse (masquer sidebar, masquer liste pour se concentrer sur l'éditeur). Toolbar système en haut.

### E2 — Barre latérale  · *Phase 3*
- **Sélecteur de workspace** en haut (nom + icône, bascule rapide) — placeholder au début, réel en Phase 19.
- Section **Favoris**.
- Section **Espaces / Dossiers** : arbre **récursif pliable** (chevrons, indentation par niveau, icône + nom par ligne). États survol / sélectionné.
- Accès **Réglages** et **Corbeille** en bas.
- Boutons **nouveau dossier / nouvelle note**.
- Réordonnancement par glisser-déposer (indicateur de dépôt).

### E3 — Liste de notes  · *Phase 4*
- Section **Épinglées** en haut.
- **Regroupement par date** façon Notes : *Aujourd'hui, Hier, 7 jours précédents, 30 jours précédents,* puis par **mois**, puis par **années** — en-têtes de section à hiérarchiser sans lourdeur.
- **Cellule de note** : titre, extrait (1–2 lignes), date relative, indicateurs 📌 épinglé / 🔒 verrouillé / ★ favori.
- **Barre de recherche** + menu de **tri**.
- États : sélectionnée, survol, **vide** (aucune note — accueillant).

### E4 — Éditeur de note  · *Phase 5* (pièce maîtresse)
- **En-tête** : icône/emoji optionnel, image de couverture optionnelle, **titre**, sous-titre.
- **Corps** : suite verticale de blocs, colonne de texte centrée.
- **Poignée de bloc ⋮⋮** (drag + menu) et **bouton `+`** à gauche, révélés au survol.
- États d'un bloc : normal, survol, focus, sélectionné, **placeholder** (« Tapez `/` pour les commandes »).
- Comportement visuel du **caret** entre blocs et de la **sélection multi-blocs**.

### E5 — Menu de commandes `/`  · *Phase 6*
Popover ancré au caret : champ de filtre, liste **icône + libellé + description + raccourci**, catégories (Basique / Média / Avancé). État survol/sélection clavier, état « aucun résultat ».

### E6 — Formatage inline  · *Phase 7*
- **Barre de formatage flottante** au-dessus de la sélection : gras, italique, souligné, barré, code inline, surlignage couleur, lien.
- **Palette de surlignage / couleur de texte**.
- **Popover d'édition de lien** (URL + texte).
- Styles visuels de **H1 → H6** et du **code inline**.

### E7 — Blocs spéciaux (apparences)  · *Phase 8* → voir §4.

### E8 — Médias & pièces jointes  · *Phase 9*
- **Bloc image** : états drop-zone vide / chargement / affichée ; **poignées de redimensionnement** ; alignement ; légende.
- **Bloc fichier joint** : icône par type, nom, taille, actions (ouvrir / révéler).
- Zone de **drag & drop** dans l'éditeur (indicateur).

### E9 — Colonnes & réorganisation  · *Phase 10*
- **Ligne d'insertion** lors du drag d'un bloc.
- **Mise en colonnes** : séparateur de colonnes redimensionnable, gouttière, empilement responsive en fenêtre étroite.
- Aperçu (« ghost ») du bloc en cours de déplacement.

### E10 — Note verrouillée  · *Phase 12*
Écran de verrou (icône cadenas + bouton déverrouiller, Touch ID / Face ID), dialogue de définition du mot de passe. Le contenu et l'aperçu ne doivent **jamais** transparaître quand verrouillé.

### E11 — Réglages  · *Phases 13 / 12 / 18*
Apparence (**Système / Clair / Sombre** + **couleur d'accent personnalisable** avec palette), verrouillage (mot de passe app), IA (clé API, confidentialité), général (langue, tri par défaut, purge corbeille). État par section, formulaire natif macOS.

### E12 — Corbeille  · *Phase 11*
Liste des notes supprimées, restaurer / supprimer définitivement, mention de purge auto. État vide.

### E13 — Bases de données  · *Phase 17*  (v2)
Sur un **même jeu de données**, cinq vues cohérentes :
- **Grille/Table** (façon Excel) : en-têtes de champ typés, cellules par type, ligne d'ajout, **barre de calculs** en bas de colonne.
- **Kanban** : colonnes = group by, cartes déplaçables entre colonnes.
- **Calendrier** : mois / semaine, entrées par date.
- **Galerie** : cartes à vignette.
- **Liste** compacte.
Plus : éditeur de champ (types), menu **filtres / tris / group by**, **étiquettes (tags) colorées**, éditeur de **template** de fiche.

### E14 — Assistant IA  · *Phase 18*  (v2)
Panneau (latéral ou popover) : champ de prompt, réponse en **streaming**, menu IA dans l'éditeur (rédiger / résumer / traduire / corriger), **bibliothèque de prompts** (catégories, recherche), et affichage des réponses **RAG avec sources citées** (puces vers les notes).

### E15 — Workspaces  · *Phase 19*  (v2)
Sélecteur en haut de sidebar (bascule rapide) + écran de gestion (créer / renommer / icône / couleur d'accent / supprimer). L'isolation entre workspaces doit se **ressentir** visuellement (accent propre à chaque workspace).

### E16 — États système  · *transverse*
- **Sync iCloud** : indicateur discret (en cours / à jour / erreur), jamais bloquant.
- **Génération IA / transcription** : progression annulable, jamais de gel.
- États **vides** accueillants (nouveau dossier, nouvelle note, recherche sans résultat, stats de base de données vides).
- **Erreurs** claires avec action de reprise.

---

## 4. Apparences de blocs (points durs de rendu)

Le corps d'une note est une pile de blocs typés. Chaque type a une apparence propre, mais **l'ensemble doit rester calme** malgré la variété. À concevoir, avec tous leurs états :

- **Paragraphe** — le défaut ; placeholder discret sur bloc vide.
- **Titres H1–H6** — échelle claire, sans que H1 n'écrase la page.
- **Listes** à puces / numérotées / **à cocher** : imbrication (indentation par niveau), renumérotation, **case cochée** (texte barré/estompé).
- **Citation** — barre latérale + retrait.
- **Callout** — icône/emoji + **fond coloré sobre**, plusieurs variantes (info / attention / succès…) qui ne crient pas.
- **Bloc de code** — police mono, fond dédié, **coloration syntaxique lisible en clair ET sombre**, sélecteur de langage **discret**, bouton copier.
- **Divider** — séparation minimale.
- **Tableau** — lisible sans devenir une grille lourde ; en-tête distinct, redimensionnement de colonnes, navigation clavier entre cellules.
- **Image / fichier** — voir E8.
- **Colonnes** — voir E9.
- **Lien de page interne** (v2) — pastille discrète icône + titre, état « page supprimée ».

**Le défi transverse** : garder la **respiration** (espacement inter-blocs, largeur de colonne) quand une note empile 200+ blocs hétérogènes.

---

## 5. Composants réutilisables

| Composant | Rôle |
|---|---|
| `SidebarRow` / `FolderRow` (récursif) | Ligne de dossier/espace, indentation, chevron, états |
| `WorkspaceSwitcher` | Sélecteur de workspace |
| `NoteCell` | Cellule de note (titre, extrait, date, indicateurs) |
| `DateSectionHeader` | En-tête de regroupement par date |
| `BlockHandle` | Poignée ⋮⋮ + bouton `+`, révélés au survol |
| `RichTextBlock` | Rendu/édition d'un bloc, décliné par type |
| `SlashMenu` | Menu de commandes `/` filtrable |
| `FloatingFormatBar` | Barre de formatage sur sélection |
| `LinkPopover` / `HighlightPalette` | Édition de lien / palette de surlignage |
| `CodeBlock` · `CalloutBlock` · `QuoteBlock` · `TableBlock` · `TodoItem` · `DividerBlock` | Blocs spéciaux |
| `ImageBlock` / `FileBlock` | Médias, avec redimensionnement |
| `ColumnContainer` | Mise en colonnes (redim, responsive) |
| `LockScreen` | Écran de note verrouillée |
| `ThemePicker` / `AccentPicker` | Apparence + couleur d'accent |
| `DatabaseGrid` · `KanbanBoard` · `CalendarView` · `GalleryView` · `DatabaseList` | Vues de base de données |
| `TagChip` · `FieldEditor` · `FilterSortMenu` | Éléments de base de données |
| `AIPanel` · `PromptLibrary` · `SourceChip` | Assistant IA |
| `EmptyState` · `LoadingState` · `ErrorState` · `SyncIndicator` | États système |

---

## 6. Design tokens à livrer

**Ne pas redéfinir ici** : la liste **exhaustive et structurée** des tokens est dans `design/tokens.md` (20 catégories : fonds/surfaces, texte, accent + états, sémantiques, bordures, surlignages, palettes d'accents et d'icônes, typographie complète, espacements, rayons, traits/focus, ombres, opacités, tailles d'icônes/contrôles, **tokens éditeur & blocs**, sidebar/liste, base de données, IA, mouvement).

**Le livrable = remplir chaque cellule `_à définir_` de `tokens.md`**, en clair **et** sombre, de préférence sous forme exploitable (hex / Color Assets / code SwiftUI). Points d'attention particuliers :
- **Chiffres tabulaires** pour les nombres (cellules de base de données, calculs) afin d'éviter que les colonnes « dansent ».
- **Accent personnalisable** : les tokens `accent.*` doivent pouvoir se recolorer à la volée **sans casser les contrastes**.
- Coloration syntaxique du bloc code : fournir un thème clair et un thème sombre.

---

## 7. Accessibilité, clavier & adaptabilité

- Contraste **AA minimum** sur tous les états, dans les deux thèmes. Support **Increase Contrast** et **Reduce Transparency**.
- **Reduce Motion** : prévoir des transitions dégradées non animées.
- **Dynamic Type** : la typo suit la taille système ; les maquettes doivent tenir quand la police grandit.
- **Daltonisme** : aucune information portée par la seule couleur (surlignages, indicateurs d'état, tags de base de données) — jouer aussi sur icône/forme/libellé.
- **VoiceOver** : chaque bloc, cellule et ligne de sidebar doit avoir un label clair.
- **Tout au clavier** (usage majeur sur Mac) : prévoir un **indicateur de focus clavier distinct de la sélection souris**. Détail des raccourcis dans `docs/14_raccourcis_clavier.md` (navigation colonnes ⌘1/2/3, `/` menu, ⌘B/I/U/K, Tab/⇧Tab indentation, ⌘⇧↑/↓ déplacer un bloc, ⌘N/⌘⇧N, etc.).
- **Adaptabilité (pour iOS plus tard)** : concevoir la coquille et l'éditeur de façon à **encaisser une largeur réduite** — colonnes qui s'empilent, panneaux qui deviennent des feuilles, barre de formatage au-dessus du clavier. Ne pas maquetter iOS maintenant, mais éviter tout parti pris qui bloquerait ce passage.

---

## 8. Ordre de livraison suggéré

Aligné sur les phases de build (voir `PLAN.md` et `DESIGN_HANDOFF.md`) :
**D'abord** E1–E2 (coquille + sidebar), puis E3 (liste), puis E4–E7 (éditeur, cœur), puis E8–E9 (médias, colonnes), puis E10–E12 (verrouillage, réglages, corbeille) et le **système de tokens complet (E/§6)**. **Ensuite seulement** (v2) : E13 (bases de données), E14 (IA), E15 (workspaces).
