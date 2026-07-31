/// Point d'entree du module SlateFeatures.
///
/// Depuis la Phase 3 (voir `docs/03_sidebar_navigation.md`), ce module porte la
/// coquille reelle de l'app (`MainWindowView`, `SidebarView`) et l'`AppState`
/// global : ils ont migre depuis `App/`, qui n'est plus qu'une coquille fine
/// instanciant le container SwiftData et affichant `MainWindowView`.
public enum SlateFeatures {
    /// Version des features assemblees, incrementee a chaque phase qui les enrichit.
    /// Sert de marqueur trivial pour verifier que le module est bien lie.
    public static let placeholderVersion = 3
}
