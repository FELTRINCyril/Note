# GLOSSAIRE — vocabulaire de Slate

> Référence de vocabulaire figée en Phase 0. Objectif : un seul mot par concept, en anglais dans le code,
> en français dans l'interface et la documentation. Toute nouvelle entité du modèle de données doit
> être ajoutée ici **avant** d'être codée.

---

## 1. Hiérarchie d'organisation

| Terme (code) | Terme UI (FR) | Définition |
|---|---|---|
| `Workspace` | Espace de travail | Cloisonnement de plus haut niveau, totalement isolé (ex : Pro, Perso). Change de contexte entier : arborescence, notes, accent de couleur. Posé dès la Phase 2, réellement exploité en Phase 19. |
| `Space` | Section | Regroupement de haut niveau **à l'intérieur** d'un workspace. Équivalent d'un compte ou d'une grande rubrique dans la sidebar (comme « iCloud » / « Sur mon Mac » dans Notes d'Apple). |
| `Folder` | Dossier | Conteneur récursif (un dossier peut contenir des sous-dossiers et des notes). Appartient à une `Space`. |
| `Note` | Note | Une unité de contenu = une page. Contient une liste ordonnée de blocs. |
| `Block` | Bloc | Plus petite unité de contenu éditable d'une note (paragraphe, titre, image, tableau...). |
| `Attachment` | Pièce jointe | Binaire rattaché à un bloc (image, fichier). |
| `Tag` | Étiquette | Libellé transversal réutilisable, indépendant de l'arborescence. Préparé en Phase 2, exploité par les bases de données (Phase 17). |

Chaîne complète : `Workspace > Space > Folder (récursif) > Note > Block > Attachment`.

---

## 2. Note vs Page vs Document

Décision : **on dit toujours « Note »**, jamais « Page » ni « Document ».

- Dans Notion, « page » désigne à la fois le contenu et le conteneur (une page peut contenir des sous-pages).
  Dans Slate, le conteneur est le `Folder`, le contenu est la `Note`.
- Les sous-pages de la Phase 16 sont donc des **notes enfants** reliées par un bloc de type `pageLink`
  (nom de l'enum conservé pour rester lisible, mais l'UI dit « lien vers une note »).
- Le mot « document » n'est utilisé que pour parler d'un fichier externe importé ou exporté.

---

## 3. Vocabulaire de l'éditeur

| Terme (code) | Terme UI (FR) | Définition |
|---|---|---|
| `BlockType` | Type de bloc | Enum `String`-backed qui détermine le rendu et le comportement d'un bloc. |
| `BlockAttributes` | Attributs de bloc | Struct `Codable` portant les métadonnées propres au type : langage d'un bloc code, niveau de titre, état coché d'une tâche, largeur d'image, config de colonne. |
| inline formatting | Formatage inline | Mise en forme **à l'intérieur** du texte d'un bloc : gras, italique, souligné, barré, code inline, surlignage, lien. Porté par `Block.text`. |
| block formatting | Formatage de bloc | Mise en forme qui change le type ou le rendu du bloc entier (titre, citation, callout, liste). |
| `caret` | Curseur | Position d'insertion du texte dans le bloc focalisé. À ne pas confondre avec le pointeur de souris. |
| focus | Focus | Le bloc qui reçoit actuellement la saisie clavier. Un seul bloc focalisé à la fois par note. |
| block handle | Poignée de bloc | Zone de préhension à gauche d'un bloc (survol) servant au glisser-déposer et au menu contextuel. |
| slash menu | Menu de commandes | Palette déclenchée par `/` en début de bloc vide, pour insérer ou convertir un bloc (Phase 6). |
| `columnList` / `column` | Colonnes | Bloc conteneur (`columnList`) portant N blocs `column`, chacun portant ses propres blocs enfants (Phase 10). |
| nesting | Imbrication | Relation `parent`/`children` entre blocs. Utilisée par les listes et les colonnes, pas par la hiérarchie de dossiers. |
| `order` | Ordre | Position d'un bloc parmi ses frères (au sein de la note ou du bloc parent). |

---

## 4. Organisation & états d'une note

| Terme (code) | Terme UI (FR) | Sens |
|---|---|---|
| `isPinned` | Épinglée | Remontée en tête de la liste de notes. |
| `isFavorite` | Favori | Accès rapide depuis la sidebar. Indépendant de l'épinglage. |
| `isLocked` | Verrouillée | Contenu protégé par mot de passe / Touch ID (Phase 12). |
| `isTrashed` / `trashedAt` | Dans la corbeille | Suppression douce, avec date pour la purge automatique (Phase 11). |
| snippet | Aperçu | Extrait texte calculé à partir des premiers blocs, affiché dans la liste de notes. |

Règle : **épinglé ≠ favori ≠ verrouillé**. Trois notions distinctes, jamais fusionnées dans l'UI.

---

## 5. Modules Swift

| Module | Contenu | Dépend de |
|---|---|---|
| `SlateModel` | Modèles SwiftData, `ModelContainer`, requêtes, migrations, config CloudKit. | rien |
| `SlateUI` | Design system : tokens, composants atomiques, thèmes clair/sombre. | SwiftUI seul |
| `SlateEditor` | Moteur d'édition par blocs. | Model, UI |
| `SlateFeatures` | Écrans complets assemblés (sidebar, liste, réglages, bases de données, IA). | tous |
| `SlateServices` | Sync CloudKit, verrouillage biométrique, import/export, IA, transcription. | Model |

Vocabulaire associé :

- **token** : variable de design (couleur, typo, espacement, rayon) définie dans `SlateUI` et dans `design/tokens.md`. Aucune valeur brute (`Color(red:...)`, `.padding(13)`) ne doit apparaître ailleurs.
- **feature** : écran ou fonctionnalité complète assemblée dans `SlateFeatures`.
- **service** : composant transverse sans UI, souvent un acteur, vivant dans `SlateServices`.
- **`AppState`** : état global `@Observable` portant la sélection courante (workspace / space / dossier / note actifs).

---

## 6. Conventions de nommage

- **Code en anglais** : types, propriétés, fonctions, cas d'enum. Commentaires en français autorisés.
- **UI en français d'abord**, chaînes localisées (base FR + EN), jamais de texte en dur dans une vue.
- Un type SwiftData = un fichier, nommé comme le type (`Note.swift`).
- Les vues se terminent par `View` (`NoteListView`), les view-models par `Model` (`NoteListModel`).
- Les tokens sont préfixés par leur famille (`Color.slateAccent`, `Font.slateBody`, `Spacing.md`).
