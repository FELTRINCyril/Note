import Foundation

/// Chaines des blocs speciaux (Phase 8, docs/08_blocs_speciaux.md : callout, bloc de
/// code, tableau) -- extrait de `EditorStrings.swift` pour rester sous la limite de
/// longueur de fichier/de corps de type de `CLAUDE.md` §5. Meme type (`EditorStrings`),
/// aucune nouvelle surface publique qui lui soit propre.
extension EditorStrings {
    // MARK: - Menu de bloc en lot (sous-etape 5.6, selection multi-blocs)

    /// Bandeau de synthese en tete du menu quand il agit sur une PLAGE de plusieurs
    /// blocs (docs/05_editeur_blocs.md, sous-etape 5.6, point explicite : "le menu de
    /// bloc doit refleter qu'on agit sur une plage"). Deplace ici (Phase 17) pour
    /// rester sous la limite de longueur de fichier de `EditorStrings.swift`.
    static func blockMenuSelectionSummary(_ count: Int) -> String {
        let template = String(localized: "editor.blockMenu.selection.summary", bundle: .module)
        return String(format: template, count)
    }

    /// "Supprimer" pluralise avec le NOMBRE de blocs de la plage -- jamais un simple
    /// "Supprimer" qui laisserait ignorer combien de blocs disparaissent.
    static func blockMenuDeleteRangeTitle(_ count: Int) -> String {
        let template = String(localized: "editor.blockMenu.delete.rangeTitle", bundle: .module)
        return String(format: template, count)
    }

    static var calloutIconAccessibilityLabel: String {
        String(localized: "editor.callout.iconAccessibilityLabel", bundle: .module)
    }

    static var calloutVariantMenuAccessibilityLabel: String {
        String(localized: "editor.callout.variantMenu.accessibilityLabel", bundle: .module)
    }

    /// Libelle d'une entree du menu de variante -- couvre aussi `.neutral`, qui n'a PAS
    /// de `SlateCalloutVariant.label` affiche dans le corps du callout lui-meme (design :
    /// icone libre, aucun libelle) mais doit tout de meme etre nommee dans ce menu pour
    /// rester choisissable. `token` est `SlateCalloutVariant.rawValue` -- meme motif que
    /// `highlightTokenAccessibilityLabel(_:)`.
    static func calloutVariantMenuLabel(_ token: String) -> String {
        switch token {
        case "neutral": String(localized: "editor.callout.variant.neutral", bundle: .module)
        case "info": String(localized: "editor.callout.variant.info", bundle: .module)
        case "warning": String(localized: "editor.callout.variant.warning", bundle: .module)
        case "success": String(localized: "editor.callout.variant.success", bundle: .module)
        default: token
        }
    }

    static var codeBlockCopyAccessibilityAnnouncement: String {
        String(localized: "editor.codeBlock.copiedAnnouncement", bundle: .module)
    }

    static var tableAddRowAccessibilityLabel: String {
        String(localized: "editor.table.addRow.accessibilityLabel", bundle: .module)
    }

    static var tableInsertRowAboveTitle: String {
        String(localized: "editor.table.insertRowAbove.title", bundle: .module)
    }

    static var tableInsertRowBelowTitle: String {
        String(localized: "editor.table.insertRowBelow.title", bundle: .module)
    }

    static var tableDeleteRowTitle: String {
        String(localized: "editor.table.deleteRow.title", bundle: .module)
    }

    static var tableInsertColumnLeftTitle: String {
        String(localized: "editor.table.insertColumnLeft.title", bundle: .module)
    }

    static var tableInsertColumnRightTitle: String {
        String(localized: "editor.table.insertColumnRight.title", bundle: .module)
    }

    static var tableDeleteColumnTitle: String {
        String(localized: "editor.table.deleteColumn.title", bundle: .module)
    }
}
