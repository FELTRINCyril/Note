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

    /// Variante de callout (neutre, information, attention, succes), qui determine le
    /// fond, la bordure et la couleur de libelle. Voir `design/tokens.md` §16 bis.
    ///
    /// Stockee sous forme neutre (identifiant textuel) et non comme un type d'UI :
    /// `SlateModel` ne connait aucune notion d'apparence, c'est `SlateUI` qui resout cet
    /// identifiant en couleurs via `SlateCalloutVariant`. Meme motif que
    /// `SlateHighlightColor` pour le surlignage inline. `nil` = variante neutre.
    public var calloutVariant: String?

    // MARK: Image (`BlockType.image`)

    /// Largeur d'affichage souhaitee, en points. `nil` = largeur naturelle/auto.
    public var imageWidth: Double?
    /// Hauteur d'affichage souhaitee, en points. `nil` = hauteur naturelle/auto.
    public var imageHeight: Double?
    /// Texte alternatif (accessibilite) de l'image.
    public var imageAltText: String?

    /// Legende affichee sous l'image (style `caption`, editable au clic). `nil` =
    /// aucune legende. Distincte de `imageAltText` : la legende est un contenu
    /// editorial visible, le texte alternatif est une description d'accessibilite qui
    /// peut ne jamais s'afficher a l'ecran.
    public var imageCaption: String?

    /// Alignement/palier de largeur de l'image, identifiant textuel (pas d'enum ici :
    /// `SlateModel` ne porte pas de logique de mise en page, seule l'UI interprete cet
    /// identifiant, meme motif que `calloutVariant` ci-dessus). Le design (artboard A)
    /// n'expose pas deux axes independants : une seule barre de cinq choix melange
    /// position et palier de largeur, reproduite cote `SlateUI` par
    /// `SlateImageAlignment` (`left`, `center`, `right`, `overflow`, `fullWidth`) ;
    /// cette propriete stocke directement son `rawValue`. `left`/`center`/`right`
    /// partagent le meme palier de largeur (colonne, 720 pt) et ne different que par la
    /// position ; `overflow` (960 pt) et `fullWidth` sont des paliers de largeur
    /// distincts. `nil` = defaut (`left`).
    public var imageAlignment: String?

    // MARK: Colonnes (`BlockType.columnList` / `BlockType.column`)

    /// Proportion relative (0...1) occupee par une `column` au sein de son `columnList`.
    public var columnWidthRatio: Double?
    /// Nombre de colonnes souhaite pour un `columnList` (indicatif, l'agencement reel
    /// depend du nombre de blocs `column` enfants).
    public var columnCount: Int?

    // MARK: Tableau (`BlockType.table` / `tableRow` / `tableCell`)

    /// Marque une `tableRow` comme ligne d'en-tete (fond distinct, texte en gras dans le
    /// rendu). Non-optionnel par choix, meme raison que `isChecked` ci-dessus.
    public var isHeaderRow: Bool = false

    /// Largeur d'affichage d'une colonne, en points (ex. "184 pt" dans l'indicateur de
    /// redimensionnement de l'artboard H). Portee par chaque `tableCell` de la colonne
    /// plutot que par une entite colonne dediee (qui n'existe pas, cf.
    /// `Block+Table.swift`) ; `Block.setTableColumnWidth(_:forColumnAt:)` la maintient
    /// coherente sur toutes les lignes. `nil` = largeur naturelle/auto.
    public var columnWidth: Double?

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
        calloutVariant: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        imageAltText: String? = nil,
        imageCaption: String? = nil,
        imageAlignment: String? = nil,
        columnWidthRatio: Double? = nil,
        columnCount: Int? = nil,
        isHeaderRow: Bool = false,
        columnWidth: Double? = nil,
        linkedNoteID: UUID? = nil,
        sourceURLString: String? = nil
    ) {
        self.language = language
        self.headingLevel = headingLevel
        self.isChecked = isChecked
        self.calloutIcon = calloutIcon
        self.calloutVariant = calloutVariant
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageAltText = imageAltText
        self.imageCaption = imageCaption
        self.imageAlignment = imageAlignment
        self.columnWidthRatio = columnWidthRatio
        self.columnCount = columnCount
        self.isHeaderRow = isHeaderRow
        self.columnWidth = columnWidth
        self.linkedNoteID = linkedNoteID
        self.sourceURLString = sourceURLString
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case headingLevel
        case isChecked
        case calloutIcon
        case calloutVariant
        case imageWidth
        case imageHeight
        case imageAltText
        case imageCaption
        case imageAlignment
        case columnWidthRatio
        case columnCount
        case isHeaderRow
        case columnWidth
        case linkedNoteID
        case sourceURLString
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        headingLevel = try container.decodeIfPresent(Int.self, forKey: .headingLevel)
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        calloutIcon = try container.decodeIfPresent(String.self, forKey: .calloutIcon)
        calloutVariant = try container.decodeIfPresent(String.self, forKey: .calloutVariant)
        imageWidth = try container.decodeIfPresent(Double.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Double.self, forKey: .imageHeight)
        imageAltText = try container.decodeIfPresent(String.self, forKey: .imageAltText)
        imageCaption = try container.decodeIfPresent(String.self, forKey: .imageCaption)
        imageAlignment = try container.decodeIfPresent(String.self, forKey: .imageAlignment)
        columnWidthRatio = try container.decodeIfPresent(Double.self, forKey: .columnWidthRatio)
        columnCount = try container.decodeIfPresent(Int.self, forKey: .columnCount)
        isHeaderRow = try container.decodeIfPresent(Bool.self, forKey: .isHeaderRow) ?? false
        columnWidth = try container.decodeIfPresent(Double.self, forKey: .columnWidth)
        linkedNoteID = try container.decodeIfPresent(UUID.self, forKey: .linkedNoteID)
        sourceURLString = try container.decodeIfPresent(String.self, forKey: .sourceURLString)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(headingLevel, forKey: .headingLevel)
        try container.encode(isChecked, forKey: .isChecked)
        try container.encodeIfPresent(calloutIcon, forKey: .calloutIcon)
        try container.encodeIfPresent(calloutVariant, forKey: .calloutVariant)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(imageAltText, forKey: .imageAltText)
        try container.encodeIfPresent(imageCaption, forKey: .imageCaption)
        try container.encodeIfPresent(imageAlignment, forKey: .imageAlignment)
        try container.encodeIfPresent(columnWidthRatio, forKey: .columnWidthRatio)
        try container.encodeIfPresent(columnCount, forKey: .columnCount)
        try container.encode(isHeaderRow, forKey: .isHeaderRow)
        try container.encodeIfPresent(columnWidth, forKey: .columnWidth)
        try container.encodeIfPresent(linkedNoteID, forKey: .linkedNoteID)
        try container.encodeIfPresent(sourceURLString, forKey: .sourceURLString)
    }
}
