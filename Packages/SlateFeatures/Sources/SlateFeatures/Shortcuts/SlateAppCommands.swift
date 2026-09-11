import SlateEditor
import SwiftUI

/// Commandes de la barre de menu macOS -- Fichier, Edition, Format, Affichage
/// (`docs/14_raccourcis_clavier.md`, "attendu sur macOS natif"). Branchee depuis
/// `App/SlateApp.swift` via `.commands { SlateAppCommands() }`.
///
/// Chaque entree lit son action via `@FocusedValue` (voir `SlateFocusedValues.swift`) :
/// c'est la vue actuellement affichee (barre laterale, liste de notes, coquille
/// principale) qui publie sa propre action, jamais l'inverse -- ce fichier ne connait ni
/// `AppState` ni `ModelContext`. Une entree dont l'action n'est pas publiee (aucune
/// fenetre au premier plan, ou aucune note selectionnee) se DESACTIVE plutot que de ne
/// rien faire silencieusement -- regle d'honnetete d'interface appliquee a chaque phase
/// depuis la 6.
///
/// ## Format et edition de blocs : volontairement NON branches en actions reelles
/// Leurs raccourcis fonctionnent deja pendant la frappe (interception bas niveau dans
/// `SlateEditor`, voir `RichTextEditingTextView+Formatting.swift`/`BlockTreeView.swift`).
/// Les dupliquer ici comme vraies commandes de menu risquerait de casser ce qui existe
/// deja : l'ordre de livraison AppKit des equivalents clavier donne la priorite a la
/// barre de menu (`-[NSApplication sendEvent:]` interroge `mainMenu.performKeyEquivalent(with:)`
/// AVANT la chaine de repondeurs), donc un item de menu ACTIF sur Cmd+B intercepterait
/// l'evenement avant meme que le `NSTextView` focalise ne le voie -- une regression sur
/// un raccourci deja livre pour un gain purement cosmetique. Les entrees restent
/// affichees, DESACTIVEES (un item de menu desactive n'est jamais consulte par le
/// matching de touches equivalentes AppKit, donc aucun risque d'interception), pour la
/// decouvrabilite visuelle. Leur combinaison reelle est documentee dans
/// `docs/RACCOURCIS.md`.
public struct SlateAppCommands: Commands {
    @FocusedValue(\.newNoteAction) private var newNoteAction
    @FocusedValue(\.newFolderAction) private var newFolderAction
    @FocusedValue(\.noteMenuActions) private var noteMenuActions
    @FocusedValue(\.toggleSidebarAction) private var toggleSidebarAction
    @FocusedValue(\.toggleListAction) private var toggleListAction
    @FocusedValue(\.toggleFocusModeAction) private var toggleFocusModeAction
    @FocusedValue(\.focusSidebarAction) private var focusSidebarAction
    @FocusedValue(\.focusListAction) private var focusListAction
    @FocusedValue(\.editorFocusAction) private var editorFocusAction

    public init() {}

    public var body: some Commands {
        fileMenuCommands
        editMenuCommands
        formatMenuCommands
        viewMenuCommands
    }

    // MARK: - Fichier

    /// Remplace le "Nouvelle fenetre" par defaut de `WindowGroup` (lui aussi sur
    /// Cmd+N) : sans ce remplacement, les deux shortcuts Cmd+N cohabiteraient (celui,
    /// implicite, de `WindowGroup`, et celui, local, de `SidebarFooterView`) -- corrige
    /// au passage un risque de collision preexistant, pas seulement un ajout.
    private var fileMenuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String(localized: "sidebar.footer.newNote", bundle: .module)) {
                newNoteAction?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(newNoteAction == nil)

            Button(String(localized: "sidebar.footer.newFolder", bundle: .module)) {
                newFolderAction?()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(newFolderAction == nil)
        }
    }

    // MARK: - Edition (actions de note, Phase 11, manque comble en Phase 14)

    private var editMenuCommands: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()

            Button(noteMenuActions?.pinTitle ?? String(localized: "noteList.contextMenu.pin", bundle: .module)) {
                noteMenuActions?.togglePin()
            }
            .keyboardShortcut("p", modifiers: [.control, .command])
            .disabled(noteMenuActions == nil)

            Button(
                noteMenuActions?.duplicateTitle
                    ?? String(localized: "noteList.contextMenu.duplicate.one", bundle: .module)
            ) {
                noteMenuActions?.duplicate()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(noteMenuActions == nil)

            Button(String(localized: "noteList.contextMenu.lock", bundle: .module)) {
                noteMenuActions?.lock()
            }
            .keyboardShortcut("l", modifiers: [.control, .command])
            .disabled(noteMenuActions == nil || noteMenuActions?.isLockDisabled == true)

            Button(
                noteMenuActions?.trashTitle
                    ?? String(localized: "noteList.contextMenu.moveToTrash.one", bundle: .module)
            ) {
                noteMenuActions?.trash()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(noteMenuActions == nil)
        }
    }

    // MARK: - Format (voir la documentation de tete de fichier : desactive par choix)

    private var formatMenuCommands: some Commands {
        CommandMenu(String(localized: "menu.format.title", bundle: .module)) {
            Button(String(localized: "menu.format.bold", bundle: .module)) {}
                .keyboardShortcut("b", modifiers: .command)
                .disabled(true)
            Button(String(localized: "menu.format.italic", bundle: .module)) {}
                .keyboardShortcut("i", modifiers: .command)
                .disabled(true)
            Button(String(localized: "menu.format.underline", bundle: .module)) {}
                .keyboardShortcut("u", modifiers: .command)
                .disabled(true)
            Button(String(localized: "menu.format.strikethrough", bundle: .module)) {}
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(true)
            Button(String(localized: "menu.format.inlineCode", bundle: .module)) {}
                .keyboardShortcut("e", modifiers: .command)
                .disabled(true)
            Button(String(localized: "menu.format.link", bundle: .module)) {}
                .keyboardShortcut("k", modifiers: .command)
                .disabled(true)
            Divider()
            Button(String(localized: "menu.format.convertParagraph", bundle: .module)) {}
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(true)
            Button(String(localized: "menu.format.convertHeading1", bundle: .module)) {}
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(true)
            Button(String(localized: "menu.format.convertHeading2", bundle: .module)) {}
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(true)
            Button(String(localized: "menu.format.convertHeading3", bundle: .module)) {}
                .keyboardShortcut("3", modifiers: [.command, .option])
                .disabled(true)
        }
    }

    // MARK: - Affichage

    /// Pas de `.keyboardShortcut` sur les 3 premiers items (bascules de colonnes) :
    /// Cmd+1/Cmd+2 sont deja actifs via les boutons locaux de `MainWindowView`
    /// (toolbar), un second enregistrement de la meme combinaison sur un item de menu
    /// serait redondant. `docs/RACCOURCIS.md` documente la combinaison reelle.
    ///
    /// Les 3 derniers items (deplacement du focus, Phase 14) portent en revanche une
    /// VRAIE combinaison (⌃⌘1/⌃⌘2/⌃⌘3, libre -- Cmd+1/Cmd+2 seuls sont deja pris par
    /// les bascules ci-dessus, Cmd+Opt+1..3 par les conversions de titre du menu
    /// Format) : c'est ICI, et seulement ici, qu'un vrai deplacement de focus clavier a
    /// lieu (`focusSidebarAction`/`focusListAction` -> `MainWindowView.focusedPanel` ;
    /// `editorFocusAction` -> `EditorController.selectBlock(_:)`, voir
    /// `EditorFocusedValues.swift` dans `SlateEditor`).
    private var viewMenuCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Button(String(localized: "toolbar.toggleSidebar", bundle: .module)) {
                toggleSidebarAction?()
            }
            .disabled(toggleSidebarAction == nil)

            Button(String(localized: "toolbar.toggleList", bundle: .module)) {
                toggleListAction?()
            }
            .disabled(toggleListAction == nil)

            Button(String(localized: "menu.view.toggleFocusMode", bundle: .module)) {
                toggleFocusModeAction?()
            }
            .disabled(toggleFocusModeAction == nil)

            Divider()

            Button(String(localized: "menu.view.focusSidebar", bundle: .module)) {
                focusSidebarAction?()
            }
            .keyboardShortcut("1", modifiers: [.control, .command])
            .disabled(focusSidebarAction == nil)

            Button(String(localized: "menu.view.focusList", bundle: .module)) {
                focusListAction?()
            }
            .keyboardShortcut("2", modifiers: [.control, .command])
            .disabled(focusListAction == nil)

            Button(String(localized: "menu.view.focusEditor", bundle: .module)) {
                editorFocusAction?()
            }
            .keyboardShortcut("3", modifiers: [.control, .command])
            .disabled(editorFocusAction == nil)
        }
    }
}
