import Foundation

/// Plage de blocs SELECTIONNES, exprimee par une paire ancre/tete -- exactement le
/// meme modele qu'une selection de TEXTE (`NSTextView`/`UITextView`) : `anchorBlockID`
/// est le bloc ou le geste a COMMENCE (clic simple, debut de glisser, bloc focalise au
/// moment d'un Maj+fleche), `focusBlockID` est l'extremite MOBILE que chaque geste
/// d'extension deplace. Les deux valent le meme identifiant pour un bloc seul
/// selectionne (`init(single:)`), l'equivalent generalise du `selectedBlockID` de la
/// sous-etape 5.3.
///
/// ## Pourquoi anchor/focus plutot qu'un intervalle d'indices
/// Un intervalle d'INDICES (ex: `0...3`) serait invalide des la premiere insertion/
/// suppression de bloc ailleurs dans le document (tous les indices se decalent) : le
/// STOCKER figerait une position perimee. Stocker deux IDENTIFIANTS DE BLOC reste
/// valide tant que les deux blocs existent encore -- la resolution en indices (voir
/// `BlockSelectionOperations.orderedBlocks(of:in:)`) se fait a la demande, sur l'etat
/// COURANT du document, jamais en cache.
///
/// ## Type PUR (docs/05_editeur_blocs.md, sous-etape 5.6)
/// Aucune dependance a `SlateModel`/AppKit/SwiftUI : uniquement deux `UUID`. La
/// resolution en blocs reels (et le respect de l'ordre DFS aplati, indispensable a
/// travers des blocs imbriques) est deleguee a `BlockSelectionOperations`, qui seul
/// connait `Note`/`Block`/`BlockOrdering`.
public struct BlockSelectionRange: Equatable, Sendable {
    /// Bloc ou le geste de selection a COMMENCE. Ne bouge jamais pendant une extension
    /// (`BlockSelectionOperations.extending(_:focusOn:)`/`extendingByStep(...)`) --
    /// seul `focusBlockID` bouge.
    public let anchorBlockID: UUID
    /// Extremite MOBILE de la plage : le bloc le plus recemment vise par le geste en
    /// cours (clic Maj, point courant d'un glisser, pas de Maj+fleche).
    public let focusBlockID: UUID

    public init(anchorBlockID: UUID, focusBlockID: UUID) {
        self.anchorBlockID = anchorBlockID
        self.focusBlockID = focusBlockID
    }

    /// Un seul bloc selectionne : ancre et tete confondues -- l'equivalent generalise
    /// de l'ancien `EditorController.selectedBlockID` (sous-etape 5.3).
    public init(single blockID: UUID) {
        self.anchorBlockID = blockID
        self.focusBlockID = blockID
    }

    /// La plage ne couvre-t-elle qu'un seul bloc ? NE PREJUGE PAS de l'ordre DFS reel
    /// (deux identifiants distincts pourraient en theorie designer des blocs adjacents
    /// OU tres eloignes) : cette propriete ne regarde que l'IDENTITE des deux bornes,
    /// c'est `BlockSelectionOperations.orderedBlocks(of:in:)` qui calcule l'etendue
    /// REELLE une fois resolue contre le document.
    public var isSingleBlock: Bool { anchorBlockID == focusBlockID }
}

/// Direction d'une extension de selection PAS A PAS (spec E4 : accessibilite clavier,
/// Maj+fleche haut/bas) -- distincte de `EditorCaretRequest.VerticalEdge` (qui decrit
/// un ATTERRISSAGE de caret, pas une direction de deplacement).
public enum BlockSelectionDirection: Equatable, Sendable {
    case up
    case down
}
