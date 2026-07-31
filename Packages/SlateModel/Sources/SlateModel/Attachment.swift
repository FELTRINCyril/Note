import Foundation
import SwiftData

/// Binaire rattache a un `Block` (image, fichier). Voir `docs/GLOSSAIRE.md` §1.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ou sont
/// optionnelles ; `block` est optionnel (l'inverse est declare du cote
/// `Block.attachment`). Le binaire (`data`) est marque `.externalStorage` : Core Data /
/// CloudKit ne doit pas stocker de gros blobs directement dans le store SQLite, ils
/// sont externalises (et deviennent un `CKAsset` cote CloudKit).
@Model
public final class Attachment {
    public var id: UUID = UUID()
    public var filename: String = ""

    /// Type de contenu (UTI, ex. "public.jpeg", "com.adobe.pdf").
    public var uti: String = ""

    /// Contenu binaire. Externalise : SwiftData stocke ce champ hors du fichier de
    /// base principal (obligatoire pour rester raisonnable en taille de store et
    /// compatible avec la limite de taille des lignes CloudKit).
    @Attribute(.externalStorage)
    public var data: Data?

    /// Largeur en pixels, uniquement pertinent pour une image.
    public var width: Int?
    /// Hauteur en pixels, uniquement pertinent pour une image.
    public var height: Int?

    public var createdAt: Date = Date.now

    /// Bloc porteur. L'inverse est declare du cote `Block.attachment`.
    public var block: Block?

    public init(
        id: UUID = UUID(),
        filename: String = "",
        uti: String = "",
        data: Data? = nil,
        width: Int? = nil,
        height: Int? = nil,
        createdAt: Date = .now,
        block: Block? = nil
    ) {
        self.id = id
        self.filename = filename
        self.uti = uti
        self.data = data
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.block = block
    }
}
