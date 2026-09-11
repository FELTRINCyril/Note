import Foundation

/// Portee d'un raccourci clavier (voir `docs/RACCOURCIS.md`) : determine dans quel
/// contexte il est actionnable, et sert de perimetre de detection de conflit (voir
/// `KeyboardShortcutRegistryTests` : "deux raccourcis ACTIFS de MEME portee ne peuvent
/// jamais partager la meme combinaison").
///
/// Volontairement PLUS FIN que le regroupement du document lisible par un humain
/// (`docs/RACCOURCIS.md` ne distingue que "Navigation", ce registre distingue
/// `editing`/`formatting`/`noteActions`) : deux raccourcis qui ne peuvent physiquement
/// jamais etre actifs en meme temps (ex. fleche haut dans la sidebar contre fleche haut
/// dans la liste, mutuellement exclusives par le focus) ne sont pas un vrai conflit,
/// alors que deux entrees de la barre de menu (toujours visibles ensemble) le sont
/// reellement des qu'elles partagent une combinaison.
public enum SlateShortcutScope: String, CaseIterable, Sendable {
    /// Toujours actif quelle que soit la fenetre/le focus (nouvelle note, bascule de
    /// colonne, mode focus, recherche...).
    case global
    /// Actions de note (epingler, dupliquer, verrouiller, corbeille) -- exposees a la
    /// fois par le menu contextuel (Phase 11) et par la barre de menu (Phase 14, voir
    /// `SlateAppCommands`), donc tout aussi "toujours actives" que `global` des qu'une
    /// note est selectionnee.
    case noteActions
    /// Raccourcis a MODIFICATEUR a l'interieur de l'editeur de blocs (deplacement de
    /// bloc, copie du bloc de code...). Les fleches/Tab/Espace/Retour "nus" de
    /// l'editeur sont volontairement HORS registre -- voir la documentation de tete de
    /// `KeyboardShortcutRegistryTests`.
    case editing
    /// Marques et conversions de texte riche (gras, italique, titres...).
    case formatting
}

/// Un modificateur clavier, independant de `SwiftUI.EventModifiers`/`NSEvent.ModifierFlags`
/// pour rester `Hashable`/`Sendable` et decrire aussi bien un raccourci SwiftUI
/// (`.keyboardShortcut`) qu'une combinaison interceptee a la main dans `SlateEditor`
/// (`NSEvent.modifierFlags`, voir `RichTextEditingTextView+Formatting.swift`).
public enum SlateShortcutModifier: String, CaseIterable, Sendable, Comparable {
    case control, option, shift, command

    /// Ordre d'affichage conventionnel macOS (Ctrl, Opt, Shift, Cmd).
    public static func < (lhs: Self, rhs: Self) -> Bool {
        displayOrder(lhs) < displayOrder(rhs)
    }

    private static func displayOrder(_ modifier: Self) -> Int {
        switch modifier {
        case .control: 0
        case .option: 1
        case .shift: 2
        case .command: 3
        }
    }
}

/// Description d'un raccourci clavier : une entree DOCUMENTAIRE et testable, pas un
/// point de branchement. Chaque site reel (`.keyboardShortcut`, `onKeyPress`,
/// `performKeyEquivalent`) continue de porter sa propre combinaison en dur -- SwiftUI
/// n'offre aucun moyen de piloter un `.keyboardShortcut` depuis une valeur partagee
/// entre modules. Ce registre EST en revanche la source de verite pour
/// `docs/RACCOURCIS.md` et pour le test de non-conflit.
public struct SlateShortcutSpec: Identifiable, Sendable {
    public let id: String
    public let scope: SlateShortcutScope
    /// Touche principale : un caractere en minuscule pour une lettre/un chiffre ("n",
    /// "1"), ou un nom symbolique pour les autres ("up", "down", "delete"...).
    public let key: String
    public let modifiers: Set<SlateShortcutModifier>
    /// Vrai si la combinaison declenche reellement l'action quelque part dans l'app
    /// aujourd'hui, `false` si elle est seulement documentee comme "a venir" (exclue du
    /// test de conflit : un raccourci qui n'existe pas encore ne peut rien percuter).
    public let isActive: Bool

    public init(
        id: String,
        scope: SlateShortcutScope,
        key: String,
        modifiers: Set<SlateShortcutModifier>,
        isActive: Bool
    ) {
        self.id = id
        self.scope = scope
        self.key = key
        self.modifiers = modifiers
        self.isActive = isActive
    }
}

/// Registre centralise des raccourcis clavier de Slate (Phase 14,
/// `docs/14_raccourcis_clavier.md`). Recense l'existant (Phases 5 a 13) et les ajouts de
/// cette phase (voir `SlateAppCommands`) -- ne couvre PAS les fleches/Tab/Espace/Retour
/// "nus" de navigation (sidebar, liste, editeur), documentes en prose uniquement dans
/// `docs/RACCOURCIS.md` : voir la documentation de `SlateShortcutScope`.
public enum SlateShortcutRegistry {
    public static let all: [SlateShortcutSpec] = [
        // MARK: Global (Phase 3 et 14)

        SlateShortcutSpec(id: "global.newNote", scope: .global, key: "n", modifiers: [.command], isActive: true),
        SlateShortcutSpec(
            id: "global.newFolder", scope: .global, key: "n", modifiers: [.command, .shift], isActive: true
        ),
        SlateShortcutSpec(id: "global.toggleSidebar", scope: .global, key: "1", modifiers: [.command], isActive: true),
        SlateShortcutSpec(id: "global.toggleList", scope: .global, key: "2", modifiers: [.command], isActive: true),
        SlateShortcutSpec(
            id: "global.toggleFocusMode", scope: .global, key: "f", modifiers: [.control, .command], isActive: true
        ),
        // Recherche plein texte globale (docs/14) : aucun mecanisme de recherche
        // plein texte n'existe encore (Phase 15), seul un filtre LOCAL au dossier
        // affiche existe (`NoteListView.searchBar`, sans raccourci clavier dedie).
        SlateShortcutSpec(
            id: "global.search", scope: .global, key: "f", modifiers: [.command, .shift], isActive: false
        ),

        // Deplacement du focus clavier entre panneaux (docs/14 : "Focus sidebar / liste
        // / editeur"). ⌃⌘ plutot que ⌘ seul, deja pris par les bascules de visibilite
        // ci-dessus (une fonctionnalite DIFFERENTE, livree en Phase 3) ; ⌘⌥ egalement
        // deja pris par les conversions de titre (voir "formatting" plus bas).
        SlateShortcutSpec(
            id: "global.focusSidebar", scope: .global, key: "1", modifiers: [.control, .command], isActive: true
        ),
        SlateShortcutSpec(
            id: "global.focusList", scope: .global, key: "2", modifiers: [.control, .command], isActive: true
        ),
        SlateShortcutSpec(
            id: "global.focusEditor", scope: .global, key: "3", modifiers: [.control, .command], isActive: true
        ),

        // MARK: Actions de note (Phase 11, exposees globalement en Phase 14)

        SlateShortcutSpec(
            id: "noteActions.pin", scope: .noteActions, key: "p", modifiers: [.control, .command], isActive: true
        ),
        SlateShortcutSpec(
            id: "noteActions.duplicate", scope: .noteActions, key: "d", modifiers: [.command], isActive: true
        ),
        SlateShortcutSpec(
            id: "noteActions.lock", scope: .noteActions, key: "l", modifiers: [.control, .command], isActive: true
        ),
        SlateShortcutSpec(
            id: "noteActions.trash", scope: .noteActions, key: "delete", modifiers: [.command], isActive: true
        ),

        // MARK: Edition de blocs, raccourcis a modificateur (Phase 8/10)

        SlateShortcutSpec(
            id: "editing.moveBlockUp", scope: .editing, key: "up", modifiers: [.control, .command], isActive: true
        ),
        SlateShortcutSpec(
            id: "editing.moveBlockDown", scope: .editing, key: "down", modifiers: [.control, .command], isActive: true
        ),
        SlateShortcutSpec(
            id: "editing.copyCode", scope: .editing, key: "c", modifiers: [.control, .option], isActive: true
        ),

        // MARK: Formatage (Phase 7)

        SlateShortcutSpec(
            id: "formatting.bold", scope: .formatting, key: "b", modifiers: [.command], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.italic", scope: .formatting, key: "i", modifiers: [.command], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.underline", scope: .formatting, key: "u", modifiers: [.command], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.strikethrough", scope: .formatting, key: "x", modifiers: [.command, .shift], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.inlineCode", scope: .formatting, key: "e", modifiers: [.command], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.link", scope: .formatting, key: "k", modifiers: [.command], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.convertParagraph", scope: .formatting, key: "0",
            modifiers: [.command, .option], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.convertHeading1", scope: .formatting, key: "1",
            modifiers: [.command, .option], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.convertHeading2", scope: .formatting, key: "2",
            modifiers: [.command, .option], isActive: true
        ),
        SlateShortcutSpec(
            id: "formatting.convertHeading3", scope: .formatting, key: "3",
            modifiers: [.command, .option], isActive: true
        )
    ]
}
