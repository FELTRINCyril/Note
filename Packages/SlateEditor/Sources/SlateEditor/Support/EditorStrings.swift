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
    /// courant (`blockMenuConvertCurrentType(_:)`), pour chaque entree du sous-menu
    /// "Convertir en..." (`BlockConversion.availableTargets(for:)`), et depuis la
    /// Phase 6 pour le titre de la commande "/" correspondante
    /// (`SlashCommandRegistry.allCommands`). Couvre `BlockConversion.convertibleTypes`
    /// PLUS `.divider` (corrige a la Phase 6 -- `.divider` n'appartient pas a
    /// `convertibleTypes`, absence de `RichText` a transporter, mais a bel et bien un
    /// rendu reel et est desormais presente a l'utilisateur via le menu "/" : le laisser
    /// retomber sur `rawValue` non localise etait un vrai trou, pas un garde-fou
    /// legitime). Les types restants ne sont jamais passes ici par construction (ni le
    /// sous-menu de conversion ni le registre "/" ne les proposent), le repli sur
    /// `rawValue` reste donc un garde-fou de dernier recours, jamais localise
    /// volontairement -- un `BlockType` qui l'atteindrait serait un bug d'appel, pas un
    /// cas d'usage.
    static func blockTypeLabel(_ type: BlockType) -> String {
        if let headingLabel = headingTypeLabel(type) {
            return headingLabel
        }
        if let mediaLabel = mediaTypeLabel(type) {
            return mediaLabel
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
        case .divider:
            return String(localized: "editor.blockType.divider", bundle: .module)
        case .callout:
            return String(localized: "editor.blockType.callout", bundle: .module)
        case .table:
            return String(localized: "editor.blockType.table", bundle: .module)
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .image, .file, .tableRow, .tableCell, .columnList, .column,
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

    // MARK: - Menu de bloc en lot (sous-etape 5.6, selection multi-blocs)

    /// Bandeau de synthese en tete du menu quand il agit sur une PLAGE de plusieurs
    /// blocs (docs/05_editeur_blocs.md, sous-etape 5.6, point explicite : "le menu de
    /// bloc doit refleter qu'on agit sur une plage").
    static func blockMenuSelectionSummary(_ count: Int) -> String {
        let template = String(localized: "editor.blockMenu.selection.summary", bundle: .module)
        return String(format: template, count)
    }

    /// "Supprimer" pluralise avec le NOMBRE de blocs de la plage -- jamais un simple
    /// "Supprimer" qui laisserait ignorer combien de blocs disparaissent (voir la
    /// documentation de tete de fichier).
    static func blockMenuDeleteRangeTitle(_ count: Int) -> String {
        let template = String(localized: "editor.blockMenu.delete.rangeTitle", bundle: .module)
        return String(format: template, count)
    }

    // MARK: - Menu de commandes / (phase 6)

    /// Sous-titre (description courte) de chaque commande "/" -- voir la documentation
    /// de tete de `SlashCommandRegistry` pour la regle "une vraie phrase utile, jamais
    /// une paraphrase du titre". Une fonction unique plutot que 13 `static var`
    /// distinctes : ce switch est exhaustif sur `BlockType` pour beneficier du meme
    /// garde-fou de COMPILATION que `BlockRenderRouting.kind(for:)` (aucun type de bloc
    /// ne doit rester silencieusement sans description s'il rejoint un jour le
    /// registre) -- voir la documentation de tete de `SlashCommandRegistry`, section
    /// "Types offerts", pour la liste des types qui l'atteignent effectivement
    /// aujourd'hui.
    static func slashCommandSubtitle(_ type: BlockType) -> String {
        if let headingSubtitle = headingSlashCommandSubtitle(type) {
            return headingSubtitle
        }
        if let mediaSubtitle = mediaSlashCommandSubtitle(type) {
            return mediaSubtitle
        }
        switch type {
        case .paragraph:
            return String(localized: "editor.slashCommand.subtitle.paragraph", bundle: .module)
        case .bulletedList:
            return String(localized: "editor.slashCommand.subtitle.bulletedList", bundle: .module)
        case .numberedList:
            return String(localized: "editor.slashCommand.subtitle.numberedList", bundle: .module)
        case .todo:
            return String(localized: "editor.slashCommand.subtitle.todo", bundle: .module)
        case .quote:
            return String(localized: "editor.slashCommand.subtitle.quote", bundle: .module)
        case .code:
            return String(localized: "editor.slashCommand.subtitle.code", bundle: .module)
        case .divider:
            return String(localized: "editor.slashCommand.subtitle.divider", bundle: .module)
        case .callout:
            return String(localized: "editor.slashCommand.subtitle.callout", bundle: .module)
        case .table:
            return String(localized: "editor.slashCommand.subtitle.table", bundle: .module)
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
             .image, .file, .tableRow, .tableCell, .columnList, .column,
             .bookmark, .embed, .databaseView, .pageLink:
            return ""
        }
    }

    /// Sous-titres des 6 niveaux de titre, extraits de `slashCommandSubtitle(_:)` pour
    /// rester sous la limite de complexite cyclomatique de SwiftLint -- meme raison que
    /// `headingTypeLabel(_:)` ci-dessus.
    private static func headingSlashCommandSubtitle(_ type: BlockType) -> String? {
        switch type {
        case .heading1:
            String(localized: "editor.slashCommand.subtitle.heading1", bundle: .module)
        case .heading2:
            String(localized: "editor.slashCommand.subtitle.heading2", bundle: .module)
        case .heading3:
            String(localized: "editor.slashCommand.subtitle.heading3", bundle: .module)
        case .heading4:
            String(localized: "editor.slashCommand.subtitle.heading4", bundle: .module)
        case .heading5:
            String(localized: "editor.slashCommand.subtitle.heading5", bundle: .module)
        case .heading6:
            String(localized: "editor.slashCommand.subtitle.heading6", bundle: .module)
        default:
            nil
        }
    }

    /// Titre de section du menu "/" (sous-etapes 6.1/6.3/6.5), dans l'ordre de
    /// `SlashCommandCategory.allCases` -- voir la documentation de tete de
    /// `SlashCommandRegistry` pour cet ordre. `media` n'a aujourd'hui aucune commande
    /// (voir sa documentation), mais garde son libelle localise ici : le jour ou une
    /// commande media rejoindra le registre, aucune chaine a ajouter a retardement.
    static func slashCommandCategoryTitle(_ category: SlashCommandCategory) -> String {
        switch category {
        case .basic:
            String(localized: "editor.slashCommand.category.basic", bundle: .module)
        case .media:
            String(localized: "editor.slashCommand.category.media", bundle: .module)
        case .advanced:
            String(localized: "editor.slashCommand.category.advanced", bundle: .module)
        }
    }

    /// Message affiche par le menu "/" quand aucune commande ne correspond a la
    /// requete tapee (sous-etape 6.4 : "aucun resultat ne ferme PAS le menu... on
    /// affiche le message, l'utilisateur peut corriger sa frappe").
    static var slashCommandEmptyState: String {
        String(localized: "editor.slashCommand.emptyState", bundle: .module)
    }

    // MARK: - Barre de formatage flottante (Phase 7, artboard P1 A)

    static var formatBarBoldLabel: String { String(localized: "editor.formatBar.bold", bundle: .module) }
    static var formatBarItalicLabel: String { String(localized: "editor.formatBar.italic", bundle: .module) }
    static var formatBarUnderlineLabel: String { String(localized: "editor.formatBar.underline", bundle: .module) }
    static var formatBarStrikethroughLabel: String {
        String(localized: "editor.formatBar.strikethrough", bundle: .module)
    }
    static var formatBarInlineCodeLabel: String { String(localized: "editor.formatBar.inlineCode", bundle: .module) }
    static var formatBarHighlightLabel: String { String(localized: "editor.formatBar.highlight", bundle: .module) }
    static var formatBarLinkLabel: String { String(localized: "editor.formatBar.link", bundle: .module) }

    /// `accessibilityValue` d'un bouton de la barre a l'etat ACTIF (docs/07, "Etats des
    /// boutons" : "l'etat ne doit pas etre porte par la seule couleur").
    static var formatBarActiveValue: String { String(localized: "editor.formatBar.activeValue", bundle: .module) }

    static var formatBarStyleParagraph: String {
        String(localized: "editor.formatBar.style.paragraph", bundle: .module)
    }

    /// Libelle du style COURANT affiche dans le menu de style (docs/07 : "le libelle
    /// montre le style courant : Texte, Titre 2..."), ou du choix propose dans son
    /// sous-menu pour `level` (1 a 6). Meme fonction pour les deux usages : le libelle
    /// d'un type de titre ne varie pas selon qu'il est affiche ou propose.
    static func formatBarStyleHeading(_ level: Int) -> String {
        // Meme motif que `blockMenuSelectionSummary(_:)`/`blockMenuDeleteRangeTitle(_:)`
        // ci-dessus : la cle du catalogue porte un `%lld` FIXE, jamais `\(level)` bake
        // dans `defaultValue` -- ce dernier motif (utilise un temps ici, corrige a la
        // revue de Phase 7) produit une cle ABSENTE du catalogue (`Localizable.xcstrings`
        // n'extrait que la cle CONSTANTE, pas sa valeur par defaut interpolee), donc
        // aucune traduction anglaise possible : le francais "Titre 2" restait affiche
        // meme sous une session en anglais, sans avertissement.
        let template = String(localized: "editor.formatBar.style.heading", bundle: .module)
        return String(format: template, level)
    }

    // MARK: - Palette surlignage / couleur de texte (artboard P1 B)

    static var formatBarHighlightSectionTitle: String {
        String(localized: "editor.formatBar.palette.highlightSection", bundle: .module)
    }
    static var formatBarTextColorSectionTitle: String {
        String(localized: "editor.formatBar.palette.textColorSection", bundle: .module)
    }
    static var formatBarRemoveAllTitle: String {
        String(localized: "editor.formatBar.palette.removeAll", bundle: .module)
    }

    /// Libelle d'accessibilite d'une pastille de surlignage (ex: "Jaune"). `token` est
    /// `SlateHighlightToken.rawValue` (voir `SlateUI`) : un `switch` explicite plutot
    /// qu'une cle interpolee (`String(localized:)` exige une cle CONSTANTE au moment de
    /// la compilation -- une interpolation ne compile pas avec l'initialiseur base sur
    /// une ressource, voir `String.LocalizationValue`).
    static func highlightTokenAccessibilityLabel(_ token: String) -> String {
        switch token {
        case "yellow": String(localized: "editor.formatBar.palette.highlight.yellow", bundle: .module)
        case "green": String(localized: "editor.formatBar.palette.highlight.green", bundle: .module)
        case "blue": String(localized: "editor.formatBar.palette.highlight.blue", bundle: .module)
        case "pink": String(localized: "editor.formatBar.palette.highlight.pink", bundle: .module)
        case "red": String(localized: "editor.formatBar.palette.highlight.red", bundle: .module)
        case "gray": String(localized: "editor.formatBar.palette.highlight.gray", bundle: .module)
        default: token
        }
    }

    /// Libelle d'accessibilite d'une pastille de couleur de texte (ex: "Bleu"). `token`
    /// est `SlateTextColorToken.rawValue` (voir `SlateUI`) -- meme motif que
    /// `highlightTokenAccessibilityLabel(_:)`.
    static func textColorTokenAccessibilityLabel(_ token: String) -> String {
        switch token {
        case "primary": String(localized: "editor.formatBar.palette.textColor.primary", bundle: .module)
        case "blue": String(localized: "editor.formatBar.palette.textColor.blue", bundle: .module)
        case "green": String(localized: "editor.formatBar.palette.textColor.green", bundle: .module)
        case "orange": String(localized: "editor.formatBar.palette.textColor.orange", bundle: .module)
        case "red": String(localized: "editor.formatBar.palette.textColor.red", bundle: .module)
        case "purple": String(localized: "editor.formatBar.palette.textColor.purple", bundle: .module)
        case "gray": String(localized: "editor.formatBar.palette.textColor.gray", bundle: .module)
        default: token
        }
    }

    // MARK: - Popover d'edition de lien (artboard P1 C)

    /// Titre du popover de CREATION (Cmd+K sur une selection sans lien) : "Lier
    /// <texte selectionne>".
    static func linkPopoverCreateTitle(selectedText: String) -> String {
        // Voir la documentation de `formatBarStyleHeading(_:)` : meme correctif, meme
        // raison (cle absente du catalogue faute de `%@` fixe).
        let template = String(localized: "editor.formatBar.link.createTitle", bundle: .module)
        return String(format: template, selectedText)
    }

    static var linkPopoverURLFieldPlaceholder: String {
        String(localized: "editor.formatBar.link.urlPlaceholder", bundle: .module)
    }
    static var linkPopoverApply: String { String(localized: "editor.formatBar.link.apply", bundle: .module) }
    static var linkPopoverCancel: String { String(localized: "editor.formatBar.link.cancel", bundle: .module) }
    static var linkPopoverEditTitle: String { String(localized: "editor.formatBar.link.edit", bundle: .module) }
    static var linkPopoverCopyAddress: String {
        String(localized: "editor.formatBar.link.copyAddress", bundle: .module)
    }
    static var linkPopoverRemoveLink: String { String(localized: "editor.formatBar.link.remove", bundle: .module) }

    /// Placeholder de la recherche de notes -- structure PRETE pour la Phase 16 (liens
    /// internes/sous-pages, voir PLAN.md), non branchee ici (aucune recherche reelle,
    /// voir `LinkEditorPopoverView`).
    static var linkPopoverNoteSearchPlaceholder: String {
        String(localized: "editor.formatBar.link.noteSearchPlaceholder", bundle: .module)
    }
}
