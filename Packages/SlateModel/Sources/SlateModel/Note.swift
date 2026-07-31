import Foundation
import SwiftData

/// Une unite de contenu = une page. Contient une liste ordonnee de blocs. Voir
/// `docs/GLOSSAIRE.md` §1 et §2 (on dit toujours "Note", jamais "Page"/"Document").
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles ; `folder` est optionnel ; `blocks` est optionnel avec une valeur par
/// defaut `[]`.
///
/// ## `snippetText` / `plainText` : stockes, pas calcules a la volee
///
/// Deux raisons structurantes de les stocker plutot que de les calculer au moment de
/// l'affichage :
///
/// 1. **Performance de la liste de notes** (Phase 4) : un calcul a la volee obligerait,
///    pour chaque ligne de la liste, a faire remonter la relation `blocks` (fault
///    SwiftData) puis a decoder chaque `RichText` pour en extraire du texte brut. Sur
///    une liste de centaines de notes affichee en continu (scroll), c'est cher et
///    repete a chaque rafraichissement. Une propriete stockee se lit directement, sans
///    toucher aux blocs.
/// 2. **Recherche plein texte** (Phase 15) : `#Predicate` de SwiftData ne sait filtrer
///    que sur des proprietes stockees de types simples. Il ne peut pas "regarder dans"
///    une relation `blocks` puis decoder du `RichText` pour chaque bloc au moment de la
///    requete. En stockant `plainText` a plat sur `Note`, un predicat
///    `plainText.localizedStandardContains(query)` devient possible directement.
///
/// Contrepartie assumee : ces deux champs ne se mettent pas a jour seuls. Toute
/// creation/modification/suppression de bloc affectant le texte doit etre suivie d'un
/// appel a `updateDerivedText()` par l'appelant (editeur de blocs ou code de test).
/// SwiftData ne fournit pas d'observation fiable des mutations d'une relation
/// `to-many` a l'interieur du modele lui-meme (pas d'equivalent `didSet` exploitable
/// sur une relation `@Model`) : le recalcul est donc explicite plutot qu'automatique et
/// silencieux.
@Model
public final class Note {
    public var id: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date.now
    public var modifiedAt: Date = Date.now

    public var isPinned: Bool = false
    public var isLocked: Bool = false
    public var isFavorite: Bool = false
    public var isTrashed: Bool = false
    public var trashedAt: Date?

    public var iconName: String?

    /// Image de couverture. Externalisee comme les pieces jointes : un gros binaire ne
    /// doit pas rester directement dans les lignes du store SwiftData/CloudKit.
    @Attribute(.externalStorage)
    public var coverImageData: Data?

    /// Apercu texte affiche dans la liste de notes (voir `docs/GLOSSAIRE.md` §4).
    /// Recalcule par `updateDerivedText()`.
    public var snippetText: String = ""

    /// Texte brut concatene de tous les blocs texte, dans l'ordre, pour la recherche
    /// plein texte (Phase 15). Recalcule par `updateDerivedText()`.
    public var plainText: String = ""

    /// Dossier porteur. L'inverse est declare du cote `Folder.notes`.
    public var folder: Folder?

    /// Blocs de contenu. Supprimer cette note supprime tous ses blocs (et, par
    /// cascade, leurs pieces jointes et blocs enfants).
    @Relationship(deleteRule: .cascade, inverse: \Block.note)
    public var blocks: [Block]? = []

    public init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        isPinned: Bool = false,
        isLocked: Bool = false,
        isFavorite: Bool = false,
        isTrashed: Bool = false,
        trashedAt: Date? = nil,
        iconName: String? = nil,
        coverImageData: Data? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isFavorite = isFavorite
        self.isTrashed = isTrashed
        self.trashedAt = trashedAt
        self.iconName = iconName
        self.coverImageData = coverImageData
        self.folder = folder
    }

    /// Longueur maximale conservee pour `snippetText`.
    private static let snippetMaxLength = 160

    /// Types de bloc porteurs de texte, pris en compte pour `plainText`/`snippetText`.
    /// Les autres types (`divider`, `table`, `columnList`, `column`, `image`, `file`,
    /// `databaseView`, `pageLink`...) ne contribuent pas de texte brut ici.
    private static let textBearingTypes: Set<BlockType> = [
        .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
        .bulletedList, .numberedList, .todo, .quote, .callout, .code
    ]

    /// Recalcule `plainText` et `snippetText` a partir des blocs actuels, tries par
    /// `order`. A appeler explicitement apres toute mutation de `blocks` ou du texte
    /// d'un bloc (voir la documentation de ce type).
    public func updateDerivedText() {
        let orderedTexts = (blocks ?? [])
            .filter { Self.textBearingTypes.contains($0.type) }
            .sorted { $0.order < $1.order }
            .compactMap { $0.text?.plainText }
            .filter { !$0.isEmpty }

        plainText = orderedTexts.joined(separator: "\n")

        if plainText.count > Self.snippetMaxLength {
            let cutoff = plainText.index(plainText.startIndex, offsetBy: Self.snippetMaxLength)
            snippetText = String(plainText[..<cutoff])
        } else {
            snippetText = plainText
        }
    }
}
