/// Point d'entree du module SlateServices.
///
/// Phase 1 : ce fichier n'existe que pour que le package expose un module compilable
/// et testable. Les services transverses (synchronisation CloudKit, verrouillage
/// biometrique, import/export, integration IA, transcription) commencent a etre
/// construits a partir des phases correspondantes (voir docs/12_verrouillage.md,
/// docs/18_ia.md...). Ne rien ajouter ici en avance de phase.
public enum SlateServices {
    /// Version des services, incrementee a chaque phase qui les enrichit.
    /// Sert de marqueur trivial pour verifier que le module est bien lie.
    public static let placeholderVersion = 1
}
