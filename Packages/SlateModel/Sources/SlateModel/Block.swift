import Foundation
import SwiftData

/// Plus petite unite de contenu editable d'une note (paragraphe, titre, image,
/// tableau...). Voir `docs/GLOSSAIRE.md` §1 et §3.
///
/// Contraintes CloudKit : toutes les proprietes ont une valeur par defaut ;
/// `note`, `parent`, `attachment` sont optionnels ; `children` est optionnel avec une
/// valeur par defaut `[]`.
///
/// ## Imbrication et ordre
/// `parent`/`children` porte l'imbrication (item de liste, colonne d'un
/// `columnList`...). `order` porte la position d'un bloc parmi ses freres, **au sein
/// du meme niveau** : soit parmi les blocs racine d'une note (`parent == nil`), soit
/// parmi les enfants d'un meme bloc parent. SwiftData n'a pas de relation ordonnee
/// nativement (`docs/02_modele_donnees.md`) : c'est cette propriete qui fait foi, pas
/// l'ordre d'insertion dans le tableau `children`/`blocks`. Toute lecture ordonnee doit
/// trier explicitement par `order`.
@Model
public final class Block {
    public var id: UUID = UUID()

    /// Position parmi les blocs freres (voir note ci-dessus).
    public var order: Int = 0

    /// Type de bloc, determine le rendu et les attributs pertinents.
    public var type: BlockType = BlockType.paragraph

    /// Stockage brut de `text` (voir l'accesseur calcule `text` ci-dessous). Nom
    /// distinct pour ne pas entrer en conflit avec la propriete publique.
    ///
    /// ATTENTION, decision structurante : `RichText` ne peut PAS etre stocke
    /// directement comme propriete `@Model` (`public var text: RichText?`).
    ///
    /// Cause racine, reproduite sur un modele jetable isole pour ecarter tout effet de
    /// bord de `Block` lui-meme. L'erreur exacte au premier acces est :
    ///
    ///     SwiftData/ModelCoders.swift:98: Fatal error:
    ///     Composite Coder only supports Keyed Container
    ///
    /// `RichText` encode pourtant bien dans un conteneur *keyed* (voir son
    /// `encode(to:)`). Le probleme est un niveau plus bas : l'encodage d'un
    /// `AttributedString` produit en interne un conteneur **unkeyed** (un tableau de
    /// runs), et le "composite coder" de SwiftData, qui serialise les proprietes
    /// `Codable` d'un `@Model`, ne sait descendre que dans des conteneurs keyed. Il
    /// leve donc un `fatalError` (le process meurt, ce n'est pas une erreur Swift
    /// recuperable) au lieu d'echouer proprement.
    ///
    /// Ce n'est donc pas un defaut de `RichText` : son round-trip `Codable` via
    /// `JSONEncoder`/`JSONDecoder` fonctionne parfaitement (voir `RichTextTests`).
    /// `BlockAttributes`, Codable "plat" sans conteneur imbrique unkeyed, persiste sans
    /// probleme via le meme mecanisme SwiftData - ce qui isole la cause a la structure
    /// de l'encodage, pas au fait d'etre `Codable`.
    ///
    /// Regle a retenir pour la suite du projet : **toute propriete `@Model` dont
    /// l'encodage `Codable` contient un conteneur unkeyed imbrique doit etre stockee en
    /// `Data` et exposee via un accesseur calcule**, comme ci-dessous.
    ///
    /// Contournement retenu, entierement local a `Block` (aucune modification de
    /// `RichText`, hors du perimetre de cet agent) : ne jamais laisser SwiftData
    /// gerer `RichText` comme attribut. `textData` est un simple `Data?` (type
    /// primitif, sans ambiguite pour SwiftData/CloudKit) ; l'encodage/decodage JSON de
    /// `RichText` est fait explicitement par l'accesseur `text` ci-dessous, hors du
    /// chemin interne de persistance de SwiftData.
    private var textData: Data?

    /// Contenu texte riche (formatage inline : gras, italique, lien, surlignage...).
    /// `nil` pour les blocs sans texte (`divider`, `image` sans legende, `table`,
    /// `columnList`, `column`...).
    ///
    /// Propriete calculee (non stockee directement par SwiftData, voir `textData` et
    /// sa documentation). Encode/decode explicitement en JSON a chaque acces : cout
    /// negligeable pour un contenu texte de bloc (quelques paragraphes au plus), a
    /// surveiller si un usage futur y mettait des volumes de texte inhabituels.
    @Transient
    public var text: RichText? {
        get {
            guard let textData else { return nil }
            return try? JSONDecoder().decode(RichText.self, from: textData)
        }
        set {
            guard let newValue else {
                textData = nil
                return
            }
            textData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Metadonnees propres au type de bloc (langage de code, etat coche, largeur
    /// d'image, config de colonne...). Toujours presentes (valeur par defaut), voir
    /// `BlockAttributes`.
    public var attributes: BlockAttributes = BlockAttributes()

    /// Note porteuse. L'inverse est declare du cote `Note.blocks`.
    public var note: Note?

    /// Bloc parent pour l'imbrication (item de liste, colonne...). `nil` si ce bloc
    /// est a la racine de la note.
    public var parent: Block?

    /// Blocs enfants directs. Supprimer ce bloc supprime recursivement tous ses
    /// enfants.
    @Relationship(deleteRule: .cascade, inverse: \Block.parent)
    public var children: [Block]? = []

    /// Piece jointe (image, fichier) rattachee a ce bloc, le cas echeant. Supprimer ce
    /// bloc supprime sa piece jointe.
    @Relationship(deleteRule: .cascade, inverse: \Attachment.block)
    public var attachment: Attachment?

    /// Base de donnees inline hebergee par ce bloc, uniquement pertinent pour
    /// `type == .databaseView` (Phase 17, voir `Database.hostMode`). Supprimer ce bloc
    /// supprime la base entiere (champs, lignes, cellules) qu'il heberge.
    @Relationship(deleteRule: .cascade, inverse: \Database.hostBlock)
    public var databaseView: Database?

    public init(
        id: UUID = UUID(),
        order: Int = 0,
        type: BlockType = .paragraph,
        text: RichText? = nil,
        attributes: BlockAttributes = BlockAttributes(),
        note: Note? = nil,
        parent: Block? = nil
    ) {
        self.id = id
        self.order = order
        self.type = type
        self.text = text
        self.attributes = attributes
        self.note = note
        self.parent = parent
    }
}
