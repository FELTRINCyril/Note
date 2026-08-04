import Foundation

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

    /// Explique POURQUOI l'entree "Convertir en..." est desactivee en 5.4 (regle
    /// d'honnetete d'interface du projet : jamais un controle qui a l'air actionnable
    /// sans agir, toujours une explication s'il est desactive).
    static var blockMenuConvertDisabledHelp: String {
        String(localized: "editor.blockMenu.convert.disabledHelp", bundle: .module)
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
