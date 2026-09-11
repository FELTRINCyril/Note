import Foundation

/// Etat de disponibilite REEL des reglages de l'onglet "General" (design P4,
/// artboard A). Meme regle d'honnetete d'interface que `AISettingsAvailability` :
/// une constante `false` ici signifie "aucun code n'implemente ce comportement",
/// jamais "pas encore code cote UI".
enum GeneralSettingsAvailability {
    /// Aucune persistance de "derniere note ouverte" entre deux lancements
    /// n'existe (`AppState` ne survit pas au relancement de l'app).
    static let isReopenLastNoteEditable = false

    /// La synchronisation iCloud est un flag de COMPILATION (`SLATE_CLOUDKIT`, voir
    /// `SlateContainer.isCloudKitEnabled`), pas un reglage utilisateur : rien ne
    /// permet de la faire basculer a l'execution.
    static let isCloudSyncEditable = false

    /// "Nouvelle note : dans le dossier courant" decrit deja le SEUL comportement
    /// implemente (`SidebarView.createNewNote`) -- aucune alternative n'existe pour
    /// en faire un choix.
    static let isNewNoteDestinationEditable = false
}
