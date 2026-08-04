import Foundation

/// Chaines visibles de l'en-tete et du corps de note, injectees par l'appelant plutot
/// que codees en dur dans `SlateEditor`.
///
/// ## Pourquoi une injection, et pas `String(localized:)` directement ici
/// `SlateEditor` (ce package) n'a, a ce jour, ni `defaultLocalization` ni de cible de
/// ressource declaree dans son `Package.swift` -- contrairement a `SlateFeatures`, qui
/// a les deux (voir son `Package.swift`, commentaire sur `defaultLocalization`).
/// Consequence VERIFIEE : sans ressource declaree, `Bundle.module` n'existe meme pas
/// pour ce module (erreur de compilation `type 'Bundle' has no member 'module'`), donc
/// `String(localized:bundle: .module)` est impossible ici tel quel ; et un
/// `Localizable.xcstrings` ajoute sans modifier `Package.swift` serait un fichier mort
/// (`swift build` le signale comme "unhandled", jamais reellement empaquete).
///
/// Modifier `Package.swift` est hors du perimetre confie a cet agent pour la 5.1
/// (Cyril s'en charge). En attendant : ce type porte les chaines par PARAMETRE, comme
/// le fait deja `SlateUI` pour les siennes (ex. `BlockContainer.placeholder`,
/// `BlockHandle` -- un composant reutilisable qui ne peut pas se localiser lui-meme
/// recoit sa copie de l'appelant). Les valeurs par defaut ci-dessous sont du francais
/// simple, utile pour les previews/tests de ce module, mais ne constituent PAS la
/// version livree a l'utilisateur : c'est `SlateFeatures` (qui a une localisation
/// fonctionnelle, `fr` + `en`) qui doit fournir les valeurs reelles au point
/// d'integration (`NoteDocumentView` instancie depuis `SlateFeatures`).
public struct NoteEditorStrings: Sendable, Equatable {
    /// Titre vide. Spec E4 : "Sans titre".
    public var untitledPlaceholder: String
    /// Libelle de l'affordance d'ajout d'icone, visible seulement quand la note n'a pas
    /// d'icone.
    public var addIconLabel: String
    /// Libelle d'accessibilite du bouton d'ajout d'icone.
    public var addIconAccessibilityLabel: String
    /// Libelle de l'affordance d'ajout de couverture, visible seulement quand la note
    /// n'a pas de couverture.
    public var addCoverLabel: String
    /// Libelle d'accessibilite du bouton d'ajout de couverture.
    public var addCoverAccessibilityLabel: String
    /// Libelle d'accessibilite de l'icone de note (quand elle existe).
    public var noteIconAccessibilityLabel: String
    /// Libelle d'accessibilite de l'image de couverture (quand elle existe).
    public var noteCoverAccessibilityLabel: String
    /// Prefixe du rendu de repli d'un type de bloc non encore pris en charge (suivi du
    /// nom technique du type, ex. "Type de bloc pas encore pris en charge : image").
    public var unsupportedBlockLabelPrefix: String

    public init(
        untitledPlaceholder: String = "Sans titre",
        addIconLabel: String = "Ajouter une icone",
        addIconAccessibilityLabel: String = "Ajouter une icone a la note",
        addCoverLabel: String = "Ajouter une couverture",
        addCoverAccessibilityLabel: String = "Ajouter une image de couverture a la note",
        noteIconAccessibilityLabel: String = "Icone de la note",
        noteCoverAccessibilityLabel: String = "Image de couverture",
        unsupportedBlockLabelPrefix: String = "Type de bloc pas encore pris en charge :"
    ) {
        self.untitledPlaceholder = untitledPlaceholder
        self.addIconLabel = addIconLabel
        self.addIconAccessibilityLabel = addIconAccessibilityLabel
        self.addCoverLabel = addCoverLabel
        self.addCoverAccessibilityLabel = addCoverAccessibilityLabel
        self.noteIconAccessibilityLabel = noteIconAccessibilityLabel
        self.noteCoverAccessibilityLabel = noteCoverAccessibilityLabel
        self.unsupportedBlockLabelPrefix = unsupportedBlockLabelPrefix
    }
}
