import Foundation

/// Actions de note exposees aux commandes globales de la barre de menu (voir
/// `SlateAppCommands`), publiees par `NoteListView` via `.focusedSceneValue`
/// (`SlateFocusedValues.swift`). `nil` des qu'aucune note n'est selectionnee : les
/// entrees de menu correspondantes se desactivent alors automatiquement plutot que
/// d'agir sur une selection vide -- comble le manque documente dans `STATUT.md` :
/// Ctrl+Cmd+P (epingler), Cmd+D (dupliquer), Ctrl+Cmd+L (verrouiller) et Cmd+Retour
/// arriere (corbeille) n'etaient actifs QUE menu contextuel deja ouvert (voir
/// `NoteContextMenuContent`), faute d'une `CommandGroup` au niveau de l'app.
@MainActor
public struct NoteMenuCommandActions {
    public let pinTitle: String
    public let togglePin: () -> Void
    public let duplicateTitle: String
    public let duplicate: () -> Void
    /// "Verrouiller" reste desactive si la selection contient deja au moins une note
    /// verrouillee -- meme regle que `NoteContextMenuContent.isLockDisabled(for:)`,
    /// deverrouiller ne passant jamais par un simple raccourci (voir sa documentation).
    public let isLockDisabled: Bool
    public let lock: () -> Void
    public let trashTitle: String
    public let trash: () -> Void

    public init(
        pinTitle: String,
        togglePin: @escaping () -> Void,
        duplicateTitle: String,
        duplicate: @escaping () -> Void,
        isLockDisabled: Bool,
        lock: @escaping () -> Void,
        trashTitle: String,
        trash: @escaping () -> Void
    ) {
        self.pinTitle = pinTitle
        self.togglePin = togglePin
        self.duplicateTitle = duplicateTitle
        self.duplicate = duplicate
        self.isLockDisabled = isLockDisabled
        self.lock = lock
        self.trashTitle = trashTitle
        self.trash = trash
    }
}
