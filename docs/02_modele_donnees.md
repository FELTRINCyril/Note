# Phase 2 — Modèle de données (le socle)

## Objectif
Définir tout le modèle SwiftData qui portera l'app : hiérarchie d'organisation (workspaces → espaces → dossiers → notes) et surtout le **modèle de blocs** qui fait la richesse de l'éditeur. C'est la phase la plus structurante ; elle conditionne toutes les suivantes.

## Prérequis
Phase 1 (projet + SwiftData/CloudKit).

## 🎨 Design
Non requis.

---

## Modèle conceptuel

```
Workspace (Pro, Perso…)          ← isolé, arrive vraiment en Phase 19 mais posé ici
 └─ Space                        ← équiv. compte/section de haut niveau
     └─ Folder (récursif)        ← dossier + sous-dossiers
         └─ Note                 ← une note = une page
             └─ Block (ordonné)  ← contenu = liste ordonnée de blocs typés
                 └─ Attachment   ← image / fichier joint rattaché à un bloc
```

## Entités SwiftData (à créer dans `SlateModel`)

### `Workspace`
- `id`, `name`, `iconName`, `accentColorHex`, `createdAt`, `sortIndex`
- relation `spaces: [Space]`

### `Space`
- `id`, `name`, `iconName`, `sortIndex`
- relation `workspace`, `folders: [Folder]`

### `Folder` (récursif)
- `id`, `name`, `iconName`, `sortIndex`, `createdAt`
- relations : `parent: Folder?`, `subfolders: [Folder]`, `notes: [Note]`, `space`

### `Note`
- `id`, `title`, `createdAt`, `modifiedAt`
- `isPinned: Bool`, `isLocked: Bool`, `isFavorite: Bool`, `isTrashed: Bool`, `trashedAt: Date?`
- `iconName: String?`, `coverImageData: Data?` (ou référence Attachment)
- relations : `folder`, `blocks: [Block]` (ordonnés par `order`)
- champs calculés : aperçu (snippet) dérivé des premiers blocs texte.

### `Block` (cœur)
- `id`, `order: Int` (position dans la note)
- `type: BlockType` (enum stocké en String — voir plus bas)
- `text: AttributedText?` — contenu texte riche (voir §Formatage inline)
- `attributes: BlockAttributes` — struct Codable pour les métadonnées propres au type (langage d'un bloc code, niveau de titre, état coché d'une tâche, largeur d'image, config de colonne…)
- relations : `note`, `parent: Block?` (pour l'imbrication : blocs enfants d'une colonne, items d'une liste), `children: [Block]`, `attachment: Attachment?`

### `Attachment`
- `id`, `filename`, `uti` (type), `data: Data?` **ou** `fileURL`/référence CloudKit asset pour les gros fichiers
- `width`, `height` (pour images), `createdAt`
- relation `block`

### `Tag` (préparé pour bases de données v2)
- `id`, `name`, `colorHex`

---

## `BlockType` (enum, extensible)
```
paragraph
heading1 … heading6
bulletedList, numberedList, todo        (item de liste ; imbrication via parent/children)
quote
callout
code                                     (attributes.language)
divider
image                                    (attachment)
file                                     (attachment)
table                                    (structure dédiée, cf. Phase 8)
columnList / column                      (mise en colonnes, cf. Phase 10)
bookmark / embed                         (v2)
databaseView                             (v2, cf. Phase 17)
pageLink                                 (v2, cf. Phase 16)
```
Choisir un enum `String`-backed pour compatibilité CloudKit et évolutivité.

## Formatage inline (dans `Block.text`)
Deux options — **à trancher avec `data-modeler`** :
1. **`AttributedString` Codable** : natif Swift, gère gras/italique/souligné/barré/lien/couleur via `AttributeContainer`. Recommandé pour rester natif.
2. Modèle maison : texte brut + liste de « runs » `{range, marks}`. Plus de contrôle, plus de travail.

Recommandation : **option 1** (`AttributedString`) avec un jeu d'attributs custom pour surlignage couleur et code inline. Documenter la (dé)sérialisation pour CloudKit.

---

## Contraintes CloudKit (rappel Phase 1)
- Toute propriété doit avoir une valeur par défaut ou être optionnelle.
- Les relations doivent être optionnelles côté CloudKit.
- Les gros binaires (images/fichiers) → stocker comme **CKAsset** / `externalStorage`, pas en base directement.

## Sous-agents
- `data-modeler` : conçoit et implémente tous les modèles, l'enum, la stratégie de formatage inline, les migrations, la config CloudKit. **Tâche principale.**
- `swift-reviewer` : vérifie la concurrence, teste création/lecture/suppression en cascade, teste la sérialisation `AttributedString`, teste la conformité CloudKit.

## Critères d'acceptation
- On peut créer par code : un workspace → space → dossier → sous-dossier → note → plusieurs blocs typés imbriqués → une pièce jointe.
- Suppression en cascade correcte (supprimer une note supprime ses blocs/attachements).
- Un bloc texte avec gras + lien + surlignage se sérialise et se relit à l'identique.
- Aucune propriété n'enfreint les contraintes CloudKit.

## Vérification
`swift-reviewer` écrit une suite de tests SwiftData (Swift Testing) couvrant les critères ci-dessus. Cocher la Phase 2. **Ne pas avancer tant que ces tests ne passent pas** — tout le reste en dépend.
