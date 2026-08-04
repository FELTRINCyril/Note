import SlateModel
import SlateUI
import SwiftUI

/// Overlay du menu de commandes "/" (docs/06_slash_commandes.md, sous-etapes 6.4/6.5) :
/// affiche `SlashMenuView` en SURIMPRESSION de la colonne de blocs, sans jamais devenir
/// premier repondant AppKit.
///
/// ## Pourquoi un overlay SwiftUI plutot qu'un `.popover` (point dur numero 1 de la tache)
/// Exigence non negociable de la sous-etape 6.4 : "la frappe doit CONTINUER pendant que
/// le menu est ouvert" -- l'utilisateur tape `/tit`, la liste se filtre a chaque
/// caractere, le texte va donc TOUJOURS dans le `NSTextView` du bloc, qui doit RESTER
/// premier repondant. Un `.popover` SwiftUI standard (deja utilise par `BlockMenuView`,
/// menu de bloc de la Phase 5) PREND le focus clavier de la fenetre au moment ou il
/// s'affiche : c'est un comportement documente d'AppKit (`NSPopover` cree sa propre
/// fenetre enfant et en fait la fenetre cle), pas une supposition -- un `NSTextView`
/// perd son statut de premier repondant des qu'une autre fenetre devient cle, exactement
/// comme le documente `RichTextEditingTextView.applyCaretPlacement(_:)` ("le focus
/// AppKit... c'est ICI, et seulement ici, que le focus traverse d'un bloc a l'autre" --
/// une fenetre popover est un troisieme mecanisme, hors de ce controle). Retenir
/// `.popover` ici aurait donc coupe la frappe au deuxieme caractere tape apres le `/`,
/// exactement l'echec que la tache met en garde contre.
///
/// Options ecartees/retenues, dans l'ordre de preference du rapport de livraison :
/// 1. **Overlay SwiftUI (retenu)** : un simple `View` positionne par calcul, jamais une
///    fenetre -- ne touche donc JAMAIS au premier repondant. Limite connue : voir
///    "Geometrie" ci-dessous.
/// 2. `NSPanel` enfant non-activant (`becomesKeyOnlyIfNeeded`, `.popUpMenu`) : plus
///    robuste vis-a-vis du focus dans l'absolu, mais demande un second pont AppKit
///    (creation/positionnement/cycle de vie d'une fenetre enfant) en plus du
///    `NSViewRepresentable` deja en place pour `RichTextEditingTextView` -- non justifie
///    tant que l'overlay suffit a l'usage reel (voir le point 2 ci-dessous pour la seule
///    limite identifiee).
/// 3. `.popover` SwiftUI : ECARTE, voir ci-dessus.
///
/// ## Geometrie : limite documentee, pas resolue ici (le "risque a verifier" annonce)
/// La position est ancree au CADRE DU BLOC ENTIER (`EditorController.blockFrames`, deja
/// alimente par `BlockFramePreferenceKey` pour le glisser de selection de la sous-etape
/// 5.6 -- aucune nouvelle cle de preference introduite), pas a la position REELLE du
/// caret dans le texte :
/// 1. **Cas dominant, exact** : un `/` tape en tout debut d'un bloc (le cas d'usage
///    normal -- on ouvre le menu pour CREER un nouveau type de contenu). Le coin
///    superieur gauche du cadre du bloc EST alors la position du caret : l'ancrage est
///    pixel-exact.
/// 2. **Cas marginal, approxime** : l'utilisateur tape `/` plus loin dans un bloc DEJA
///    multi-lignes. Le menu s'ancre alors au coin superieur du bloc ENTIER, pas a la
///    ligne exacte ou le `/` a ete tape -- decalage visuel non corrige. Resoudre ce cas
///    exigerait de transporter le rectangle REEL du caret (coordonnees locales d'un
///    `NSTextView`, voir `RichTextEditingTextView.currentCaretVisualColumnX`) vers ce
///    meme `coordinateSpace` nomme, ce qui demanderait un second pont explicite
///    NSView -> SwiftUI (aucune API SwiftUI native ne lit l'interieur d'un
///    `NSViewRepresentable` a chaque frappe) -- non implemente ici, la Phase 6 se
///    limitant a la sous-etape 6.5 pour la vue elle-meme (contrat deja livre et gele).
/// 3. **Rognage en bas de la zone de defilement** (risque explicitement signale par la
///    tache) : NON VERIFIE dans une fenetre reelle par cet agent (aucune fenetre
///    disponible dans cet environnement -- voir le rapport de livraison, section
///    "non verifiable"). L'overlay vit DANS le contenu du `ScrollView` (meme
///    `ZStack`/`coordinateSpace` que les blocs, voir `NoteDocumentView`), donc il
///    defile avec le document -- mais `SlashMenuView.menuMaxHeight` (320 pt, deja fige
///    par le contrat de la sous-etape 6.5) n'est borne par AUCUNE hauteur RESTANTE
///    visible sous le bloc courant : un `/` tape tout en bas de la fenetre visible
///    pourrait faire deborder le menu sous le bord inferieur du `ScrollView` sans qu'il
///    ne se redimensionne ni ne bascule au-dessus du bloc. A reevaluer visuellement.
struct SlashMenuOverlay: View {
    let block: Block
    let editorController: EditorController

    var body: some View {
        if let frame = editorController.blockFrames[block.id] {
            SlashMenuView(
                sections: sections,
                selectedItemID: editorController.slashMenuState?.selectedCommandID,
                emptyStateMessage: EditorStrings.slashCommandEmptyState,
                onSelect: { commandID in editorController.confirmSlashMenuCommand(commandID, in: block) },
                onHover: { commandID in editorController.hoverSlashMenuItem(commandID) }
            )
            // Voir la doc de tete, "Geometrie" : ancre au coin superieur gauche du CADRE
            // DU BLOC (pas au caret reel), dans le `coordinateSpace` nomme partage avec
            // `EditorController.blockFrames` (voir `NoteDocumentView`).
            .offset(x: frame.minX, y: frame.maxY)
        }
    }

    /// Sections localisees, dans l'ordre de `SlashCommandCategory.allCases` -- une
    /// categorie sans commande correspondant a la requete courante ne produit AUCUNE
    /// section (meme regle que `SlashMenuView.nonEmptySections`, appliquee ici en amont
    /// pour eviter de construire un `Section` vide inutilement).
    private var sections: [SlashMenuView.Section] {
        let matches = editorController.slashMenuMatches(for: block)
        return SlashCommandCategory.allCases.compactMap { category in
            let items = matches.filter { $0.command.category == category }.map(item(for:))
            guard !items.isEmpty else { return nil }
            return SlashMenuView.Section(
                id: category.rawValue,
                title: EditorStrings.slashCommandCategoryTitle(category),
                items: items
            )
        }
    }

    private func item(for match: SlashCommandMatch) -> SlashMenuView.Item {
        SlashMenuView.Item(
            id: match.command.id,
            title: match.command.title,
            subtitle: match.command.subtitle,
            systemImage: match.command.systemImage,
            matchedTitleOffsets: match.matchedTitleOffsets
        )
    }
}
