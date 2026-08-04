import Foundation
import SlateModel

/// Chaines visibles PORTEES PAR `SlateEditor` LUI-MEME (`Bundle.module`), a la
/// difference de `NoteEditorStrings` (chaines injectees par `SlateFeatures`, motif de
/// la Phase 5.1 -- voir sa documentation pour le pourquoi historique).
///
/// Depuis la 5.2, ce module a `defaultLocalization: "fr"` et un `Localizable.xcstrings`
/// traite comme ressource (`Package.swift`) : `Bundle.module` existe, donc toute
/// nouvelle chaine ajoutee par cette sous-etape (et les suivantes : menu `/`,
/// formatage, blocs riches) doit passer par ICI plutot que de continuer a remonter des
/// parametres jusqu'a `SlateFeatures` -- exigence explicite de la tache. Les chaines de
/// la 5.1 restent volontairement inchangees (`NoteEditorStrings`) : les migrer n'est
/// pas l'objet de cette sous-etape.
enum EditorStrings {
    /// Placeholder d'un bloc paragraphe vide, visible seulement quand ce bloc est
    /// focalise (spec E4, "GALERIE D'ETATS" : "Tapez / pour les commandes -- bloc vide,
    /// focalise"). Passe explicitement a `BlockContainer` plutot que de laisser sa
    /// valeur par defaut (`SlateUI`, hors de ce perimetre) : ce defaut est un litteral
    /// francais non localise, cette chaine-ci l'est reellement (fr + en).
    static var paragraphPlaceholder: String {
        String(localized: "block.paragraph.placeholder", bundle: .module)
    }

    /// Libelle d'accessibilite de la zone cliquable de bas de document (sous-etape 5.3 :
    /// "un clic y cree un bloc vide focalise") -- sans lui, VoiceOver n'aurait aucun
    /// moyen d'annoncer cette affordance desormais interactive.
    static var appendBlockAccessibilityLabel: String {
        String(localized: "editor.appendBlock.accessibilityLabel", bundle: .module)
    }

    // MARK: - Menu de bloc (sous-etape 5.4)

    /// Libelle d'accessibilite du bouton "Options du bloc" de `BlockHandle`, complete
    /// par cet ecran-ci (`BlockHandle` porte deja un libelle generique dans `SlateUI`) :
    /// annonce aussi le moyen clavier d'y acceder pour les utilisateurs VoiceOver qui
    /// ne survolent jamais a la souris.
    static var blockMenuAccessibilityHint: String {
        String(localized: "editor.blockMenu.accessibilityHint", bundle: .module)
    }

    static var blockMenuConvertTitle: String {
        String(localized: "editor.blockMenu.convert.title", bundle: .module)
    }

    /// Explique POURQUOI l'entree "Convertir en..." est desactivee (sous-etape 5.5,
    /// `BlockConversion.availableTargets(for:)` retourne une liste vide) : regle
    /// d'honnetete d'interface du projet -- jamais un controle qui a l'air actionnable
    /// sans agir, toujours une explication s'il est desactive. Concerne les types sans
    /// rendu textuel reel aujourd'hui (`divider`, `image`, `file`...) ou reserves a une
    /// phase ulterieure (`callout`, `table`, `columnList`...).
    static var blockMenuConvertUnavailableHelp: String {
        String(localized: "editor.blockMenu.convert.unavailableHelp", bundle: .module)
    }

    /// Rend visible le type DE DEPART d'une conversion (sous-etape 5.5, point explicite
    /// de la tache : "le libelle du type courant doit etre visible pour que
    /// l'utilisateur sache d'ou il part") -- affiche en `.help` du sous-menu, pas
    /// seulement dans le sous-menu lui-meme ou l'utilisateur ne le voit qu'apres avoir
    /// deja clique.
    static func blockMenuConvertCurrentType(_ typeLabel: String) -> String {
        let template = String(localized: "editor.blockMenu.convert.currentType", bundle: .module)
        return String(format: template, typeLabel)
    }

    /// Libelle visible d'un `BlockType`, utilise a la fois pour annoncer le type
    /// courant (`blockMenuConvertCurrentType(_:)`) et pour chaque entree du sous-menu
    /// "Convertir en..." (`BlockConversion.availableTargets(for:)`). Couvre uniquement
    /// `BlockConversion.convertibleTypes` : les autres types ne sont jamais passes ici
    /// par construction (le sous-menu ne les propose pas), le repli sur `rawValue`
    /// n'est donc qu'un garde-fou de dernier recours, jamais localise volontairement --
    /// un `BlockType` qui l'atteindrait serait un bug d'appel, pas un cas d'usage.
    static func blockTypeLabel(_ type: BlockType) -> String {
        if let headingLabel = headingTypeLabel(type) {
            return headingLabel
        }
        switch type {
        case .paragraph:
            return String(localized: "editor.blockType.paragraph", bundle: .module)
        case .bulletedList:
            return String(localized: "editor.blockType.bulletedList", bundle: .module)
        case .numberedList:
            return String(localized: "editor.blockType.numberedList", bundle: .module)
        case .todo:
            return String(localized: "editor.blockType.todo", bundle: .module)
        case .quote:
            return String(localized: "editor.blockType.quote", bundle: .module)
        case .code:
            return String(localized: "editor.blockType.code", bundle: .module)
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .callout, .divider, .image, .file, .table, .columnList, .column,
             .bookmark, .embed, .databaseView, .pageLink:
            return type.rawValue
        }
    }

    /// Libelle des 6 niveaux de titre, extrait de `blockTypeLabel(_:)` pour rester sous
    /// la limite de complexite cyclomatique de SwiftLint -- un `switch` unique sur les
    /// 12 cas convertibles plus les niveaux de titre depasserait le seuil configure.
    private static func headingTypeLabel(_ type: BlockType) -> String? {
        switch type {
        case .heading1:
            String(localized: "editor.blockType.heading1", bundle: .module)
        case .heading2:
            String(localized: "editor.blockType.heading2", bundle: .module)
        case .heading3:
            String(localized: "editor.blockType.heading3", bundle: .module)
        case .heading4:
            String(localized: "editor.blockType.heading4", bundle: .module)
        case .heading5:
            String(localized: "editor.blockType.heading5", bundle: .module)
        case .heading6:
            String(localized: "editor.blockType.heading6", bundle: .module)
        default:
            nil
        }
    }

    static var blockMenuDuplicateTitle: String {
        String(localized: "editor.blockMenu.duplicate.title", bundle: .module)
    }

    static var blockMenuMoveUpTitle: String {
        String(localized: "editor.blockMenu.moveUp.title", bundle: .module)
    }

    static var blockMenuMoveDownTitle: String {
        String(localized: "editor.blockMenu.moveDown.title", bundle: .module)
    }

    static var blockMenuDeleteTitle: String {
        String(localized: "editor.blockMenu.delete.title", bundle: .module)
    }
}
