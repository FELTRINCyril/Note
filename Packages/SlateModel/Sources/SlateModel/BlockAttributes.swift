import Foundation

/// Metadonnees propres au type d'un `Block` : langage d'un bloc code, etat coche
/// d'une tache, largeur d'une image, configuration d'une colonne, etc.
///
/// ## Conception pour l'extensibilite
///
/// Cette struct est serialisee en base (propriete `Block.attributes`, stockee comme
/// donnee encodee par SwiftData). Les phases 8 (tableau), 10 (colonnes) et d'autres a
/// venir ajouteront des champs. Pour ne jamais casser la lecture de donnees deja
/// ecrites quand un champ est ajoute plus tard :
///
/// - Toutes les proprietes sont **optionnelles avec valeur par defaut `nil`**, sauf
///   `isChecked` qui utilise une valeur par defaut non-optionnelle (`false`) plutot
///   qu'un `Bool?` : `discouraged_optional_boolean` est une regle SwiftLint active sur
///   ce projet, et un booleen absent d'anciennes donnees a de toute facon un sens par
///   defaut clair ("pas coche").
/// - Le decodage est ecrit a la main (`init(from:)`) avec `decodeIfPresent` pour
///   **chaque** champ : une valeur JSON/plist qui ne contient pas encore un champ
///   ajoute ulterieurement se decode sans erreur, avec la valeur par defaut. C'est
///   deliberement plus explicite que de compter sur la synthese automatique de
///   `Codable`, dont le comportement face aux cles manquantes differe selon que la
///   propriete est optionnelle ou non et n'est pas garanti stable a travers les
///   versions du langage.
/// - A l'inverse, des donnees ecrites par une version *future* de l'app (avec des
///   champs que cette version ne connait pas encore) se decodent aussi sans erreur :
///   `JSONDecoder`/`PropertyListDecoder` ignorent nativement les cles absentes des
///   `CodingKeys` declares ici.
///
/// Regle pour toute evolution future : n'ajouter que des proprietes optionnelles (ou a
/// valeur par defaut), jamais de propriete requise, et ajouter la ligne
/// `decodeIfPresent` correspondante dans `init(from:)`.
public struct BlockAttributes: Codable, Hashable, Sendable {
    // MARK: Bloc code (`BlockType.code`)

    /// Identifiant de langage pour la coloration syntaxique (ex. "swift", "python").
    public var language: String?

    // MARK: Titres (`BlockType.heading1` ... `heading6`)

    /// Niveau de titre redondant avec le `BlockType` (1 a 6), conserve pour permettre
    /// a l'editeur de lire le niveau sans dupliquer un switch sur `BlockType` partout.
    public var headingLevel: Int?

    // MARK: Liste a cocher (`BlockType.todo`)

    /// Etat coche d'un item `todo`. Non-optionnel par choix (voir note de conception
    /// ci-dessus) : `false` est la valeur par defaut naturelle.
    public var isChecked: Bool = false

    // MARK: Callout (`BlockType.callout`)

    /// Icone/emoji affiche devant le contenu d'un callout.
    public var calloutIcon: String?

    // MARK: Image (`BlockType.image`)

    /// Largeur d'affichage souhaitee, en points. `nil` = largeur naturelle/auto.
    public var imageWidth: Double?
    /// Hauteur d'affichage souhaitee, en points. `nil` = hauteur naturelle/auto.
    public var imageHeight: Double?
    /// Texte alternatif (accessibilite) de l'image.
    public var imageAltText: String?

    // MARK: Colonnes (`BlockType.columnList` / `BlockType.column`)

    /// Proportion relative (0...1) occupee par une `column` au sein de son `columnList`.
    public var columnWidthRatio: Double?
    /// Nombre de colonnes souhaite pour un `columnList` (indicatif, l'agencement reel
    /// depend du nombre de blocs `column` enfants).
    public var columnCount: Int?

    // MARK: Lien vers une note (`BlockType.pageLink`)

    /// Identifiant de la `Note` ciblee par un bloc `pageLink`.
    public var linkedNoteID: UUID?

    // MARK: Signet / embed (`BlockType.bookmark` / `BlockType.embed`, v2)

    /// URL source d'un signet ou d'un contenu embarque.
    public var sourceURLString: String?

    public init(
        language: String? = nil,
        headingLevel: Int? = nil,
        isChecked: Bool = false,
        calloutIcon: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        imageAltText: String? = nil,
        columnWidthRatio: Double? = nil,
        columnCount: Int? = nil,
        linkedNoteID: UUID? = nil,
        sourceURLString: String? = nil
    ) {
        self.language = language
        self.headingLevel = headingLevel
        self.isChecked = isChecked
        self.calloutIcon = calloutIcon
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageAltText = imageAltText
        self.columnWidthRatio = columnWidthRatio
        self.columnCount = columnCount
        self.linkedNoteID = linkedNoteID
        self.sourceURLString = sourceURLString
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case headingLevel
        case isChecked
        case calloutIcon
        case imageWidth
        case imageHeight
        case imageAltText
        case columnWidthRatio
        case columnCount
        case linkedNoteID
        case sourceURLString
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        headingLevel = try container.decodeIfPresent(Int.self, forKey: .headingLevel)
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        calloutIcon = try container.decodeIfPresent(String.self, forKey: .calloutIcon)
        imageWidth = try container.decodeIfPresent(Double.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Double.self, forKey: .imageHeight)
        imageAltText = try container.decodeIfPresent(String.self, forKey: .imageAltText)
        columnWidthRatio = try container.decodeIfPresent(Double.self, forKey: .columnWidthRatio)
        columnCount = try container.decodeIfPresent(Int.self, forKey: .columnCount)
        linkedNoteID = try container.decodeIfPresent(UUID.self, forKey: .linkedNoteID)
        sourceURLString = try container.decodeIfPresent(String.self, forKey: .sourceURLString)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(headingLevel, forKey: .headingLevel)
        try container.encode(isChecked, forKey: .isChecked)
        try container.encodeIfPresent(calloutIcon, forKey: .calloutIcon)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(imageAltText, forKey: .imageAltText)
        try container.encodeIfPresent(columnWidthRatio, forKey: .columnWidthRatio)
        try container.encodeIfPresent(columnCount, forKey: .columnCount)
        try container.encodeIfPresent(linkedNoteID, forKey: .linkedNoteID)
        try container.encodeIfPresent(sourceURLString, forKey: .sourceURLString)
    }
}
