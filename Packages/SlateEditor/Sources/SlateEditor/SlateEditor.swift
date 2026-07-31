/// Point d'entree du module SlateEditor.
///
/// Phase 1 : ce fichier n'existe que pour que le package expose un module compilable
/// et testable. Le moteur d'edition par blocs (rendu, focus/caret, menu `/`, formatage
/// inline, drag & drop, colonnes) commence a etre construit a partir de la Phase 5
/// (voir docs/05_editeur_blocs.md et suivants). Ne rien ajouter ici en avance de phase.
public enum SlateEditor {
    /// Version du moteur d'edition, incrementee a chaque phase qui l'enrichit.
    /// Sert de marqueur trivial pour verifier que le module est bien lie.
    public static let placeholderVersion = 1
}
