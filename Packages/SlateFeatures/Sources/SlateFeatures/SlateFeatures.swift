/// Point d'entree du module SlateFeatures.
///
/// Phase 1 : ce fichier n'existe que pour que le package expose un module compilable
/// et testable. Les ecrans complets assembles (barre laterale, liste de notes,
/// reglages, bases de donnees, IA) commencent a etre construits a partir de la
/// Phase 3 (voir docs/03_sidebar_navigation.md et suivants). Les 3 colonnes de la
/// Phase 1 vivent volontairement dans App/ et migreront ici en Phase 3 - ne pas les
/// anticiper dans ce module.
public enum SlateFeatures {
    /// Version des features assemblees, incrementee a chaque phase qui les enrichit.
    /// Sert de marqueur trivial pour verifier que le module est bien lie.
    public static let placeholderVersion = 1
}
