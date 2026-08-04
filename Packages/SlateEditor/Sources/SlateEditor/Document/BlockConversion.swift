import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit, aucun `ModelContext`) de la conversion de
/// type de bloc (docs/05_editeur_blocs.md, sous-etape 5.5 : "Convertir un bloc d'un
/// type a un autre... en conservant le texte"). Memes principes que `BlockOperations`
/// (sous-etape 5.4) : opere directement sur le graphe `Block`/`Note` deja en memoire,
/// entierement testable sans `NSTextView` ni fenetre. `EditorController` reste la SEULE
/// facade appelee par la couche SwiftUI.
///
/// ## Le texte riche n'est JAMAIS touche
/// `convert(_:to:)` ne lit ni n'ecrit `block.text` : le `RichText` (caracteres ET
/// attributs inline -- gras, lien, surlignage...) traverse la conversion **tel quel**,
/// par la simple absence de mutation. Repasser par une `String` intermediaire, meme
/// pour "juste changer le type", detruirait silencieusement le formatage inline deja
/// applique -- exactement la classe de perte que ce projet vient de corriger ailleurs.
/// C'est le point non negociable de cette sous-etape.
///
/// ## Types offerts a la conversion
/// `convertibleTypes` est restreint aux types qui ont un rendu REEL et porteur de texte
/// aujourd'hui (voir `BlockRenderRouting`/`BlockContentRouterView`) : paragraphe, les 6
/// niveaux de titre, les 3 types de liste, citation, code. En sont exclus :
/// - `divider`, `image`, `file` : pas de `RichText` porte par ces types (`divider`) ou
///   contenu principal non textuel (`image`/`file`, texte alternatif mis a part) -- une
///   conversion depuis/vers l'un de ces types detruirait ou masquerait du texte sans
///   qu'aucune UI ne le signale. Le choix le plus honnete est de ne PAS les proposer
///   (aucune confirmation a construire, aucune perte a risquer).
/// - `callout`, `table`, `columnList`, `column`, `bookmark`, `embed`, `databaseView`,
///   `pageLink` : reserves a des phases ulterieures (8, 10, v2 -- voir
///   `BlockRenderRouting.kind(for:)`, cas `.unsupported`), sans rendu reel aujourd'hui.
///   Cette liste est EXTENSIBLE : chaque type qui gagnera un rendu reel dans une phase
///   ulterieure devra rejoindre `convertibleTypes` a ce moment-la, pas avant.
///
/// ## Conservation/abandon de `BlockAttributes` (le point delicat de la tache)
/// Les `BlockAttributes` sont TYPE-DEPENDANTES (voir sa documentation dans `SlateModel`) :
/// aucune conversion ne les copie en bloc. Trois regles explicites, appliquees par
/// `convertedAttributes(from:to:)` :
///
/// 1. **`isChecked` est TOUJOURS preserve**, quel que soit le type de depart ou
///    d'arrivee. C'est un etat semantique voulu par l'utilisateur ("cette ligne est
///    faite"), independant du type d'affichage -- le convertir en paragraphe puis le
///    reconvertir en tache doit retrouver la case cochee, sinon l'utilisateur perd une
///    information qu'il n'a jamais demande a perdre en changeant juste le rendu.
/// 2. **`headingLevel` est TOUJOURS RECALCULE**, jamais transporte depuis la source :
///    mis a la valeur du type d'arrivee si c'est un titre, remis a `nil` sinon. Ce n'est
///    PAS une perte de donnee : `headingLevel` est explicitement documente dans
///    `BlockAttributes` comme "redondant avec le `BlockType`", donc entierement
///    reconstructible depuis le nouveau type.
/// 3. **Tous les autres champs sont ABANDONNES** (`language`, `calloutIcon`,
///    `imageWidth`, `imageHeight`, `imageAltText`, `columnWidthRatio`, `columnCount`,
///    `linkedNoteID`, `sourceURLString`) : perte VOLONTAIRE et documentee. En pratique
///    seul `language` (bloc code) est jamais renseigne sur un type de la liste
///    `convertibleTypes` -- les autres champs appartiennent a des types qui n'y sont
///    pas proposes. Contrairement a `isChecked`, un langage de coloration syntaxique
///    est un attribut de l'OUTIL (a quoi ressemble ce bloc), pas du contenu de
///    l'utilisateur : le laisser survivre en silence sur un paragraphe puis
///    ressusciter (peut-etre a tort) au retour vers un bloc code serait plus surprenant
///    que de le redemander. Convertir un bloc code en paragraphe puis en code redemarre
///    donc sans langage -- c'est un choix, pas un oubli.
///
/// ## Enfants et imbrication
/// - **Entre les trois types de liste** (`bulletedList`/`numberedList`/`todo`) :
///   aucune promotion, les enfants restent attaches tels quels -- c'est le cas d'usage
///   le plus courant (transformer une liste a puces en liste de taches) et il doit
///   rester parfaitement fluide, imbrication comprise.
/// - **Vers tout autre type** (paragraphe, titre, citation, code) : les enfants sont
///   PROMUS a la place du bloc convertit, exactement comme `BlockOrdering.remove(_:)`
///   le fait deja pour la suppression (sous-etape 5.3/5.4) -- meme principe : "ne
///   jamais perdre de bloc silencieusement". Un titre ou une citation ne portant pas de
///   sous-items dans le vocabulaire actuel de l'editeur, garder les enfants imbriques
///   SOUS eux serait incoherent avec ce que l'utilisateur voit d'un titre partout
///   ailleurs dans le document.
@MainActor
public enum BlockConversion {
    /// Types de bloc offerts a la conversion (source ET cible), dans l'ordre ou ils
    /// doivent apparaitre dans le sous-menu "Convertir en..." -- voir la documentation
    /// de tete de fichier pour la justification de cette liste et son caractere
    /// extensible.
    public static let convertibleTypes: [BlockType] = [
        .paragraph,
        .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
        .bulletedList, .numberedList, .todo,
        .quote,
        .code
    ]

    /// Types cibles a proposer pour `block` : `convertibleTypes` prive du type courant
    /// de `block`, et vide si `block` lui-meme n'est pas dans `convertibleTypes` (rien
    /// de sense a proposer pour un separateur, une image, ou un type non encore rendu).
    public static func availableTargets(for block: Block) -> [BlockType] {
        guard convertibleTypes.contains(block.type) else { return [] }
        return convertibleTypes.filter { $0 != block.type }
    }

    /// Convertit `block` vers `newType`, en place : `RichText` inchange (voir la
    /// documentation de tete de fichier), `BlockAttributes` recalcules
    /// (`convertedAttributes(from:to:)`), enfants promus SAUF entre deux types de
    /// liste. Sans effet si `newType` est egal au type courant, ou si l'un des deux
    /// types n'est pas dans `convertibleTypes`.
    public static func convert(_ block: Block, to newType: BlockType) {
        guard newType != block.type,
              convertibleTypes.contains(block.type),
              convertibleTypes.contains(newType) else { return }

        if !(isListType(block.type) && isListType(newType)) {
            promoteChildren(of: block)
        }

        block.attributes = convertedAttributes(from: block.attributes, to: newType)
        block.type = newType
    }

    // MARK: - Attributs (voir la documentation de tete de fichier, point "Conservation/abandon")

    static func convertedAttributes(from old: BlockAttributes, to newType: BlockType) -> BlockAttributes {
        var result = BlockAttributes(isChecked: old.isChecked)
        result.headingLevel = headingLevel(of: newType)
        return result
    }

    private static func headingLevel(of type: BlockType) -> Int? {
        switch type {
        case .heading1: 1
        case .heading2: 2
        case .heading3: 3
        case .heading4: 4
        case .heading5: 5
        case .heading6: 6
        default: nil
        }
    }

    // MARK: - Enfants (voir la documentation de tete de fichier, point "Enfants et imbrication")

    private static func isListType(_ type: BlockType) -> Bool {
        type == .bulletedList || type == .numberedList || type == .todo
    }

    /// Detache tous les enfants directs de `block` et les reinsere, dans le meme ordre
    /// et avec leur propre sous-arbre intact, comme freres suivant IMMEDIATEMENT
    /// `block` (memes `parent`/`note` que `block`). Reutilise `BlockOrdering.insert(_:after:)`
    /// bloc par bloc : chaque insertion renumerote deja correctement la fratrie
    /// resultante, il suffit de faire glisser l'ancre a chaque etape.
    private static func promoteChildren(of block: Block) {
        let children = BlockOrdering.children(of: block)
        guard !children.isEmpty else { return }

        block.children = []
        var anchor = block
        for child in children {
            BlockOrdering.insert(child, after: anchor)
            anchor = child
        }
    }
}
