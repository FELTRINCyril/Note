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
/// appel a `refreshDerivedText()` par l'appelant (editeur de blocs ou code de test).
/// SwiftData ne fournit pas d'observation fiable des mutations d'une relation
/// `to-many` a l'interieur du modele lui-meme (pas d'equivalent `didSet` exploitable
/// sur une relation `@Model`) : le recalcul est donc explicite plutot qu'automatique et
/// silencieux.
///
/// ## `refreshDerivedText()` : point d'entree UNIQUE de recalcul (decision Cyril, Phase 4)
///
/// Ce nom (renomme depuis `updateDerivedText()`) est volontairement descriptif d'un
/// contrat : c'est LE seul endroit ou `plainText`/`snippetText` sont recalcules, et il
/// n'existe deliberement **aucun mecanisme d'observation automatique** en face (ni
/// `didSet`, ni hook de sauvegarde de `ModelContext`, ni notification). Cyril a tranche
/// que ce calcul reste une projection des donnees du modele (donc porte par
/// `SlateModel`), mais que son declenchement reste sous la responsabilite de l'appelant.
///
/// **A l'attention de l'editeur de blocs (Phase 5, `SlateEditor`)** : l'editeur doit
/// appeler `refreshDerivedText()` depuis son unique point de sauvegarde (le geste qui
/// persiste une note apres edition de son contenu), et depuis cet unique point
/// seulement. L'objectif explicite est d'avoir un seul site d'appel, facile a auditer
/// et impossible a oublier accidentellement - a l'inverse de multiples appels
/// disperses a chaque mutation de bloc, faciles a desynchroniser un jour ou l'autre.
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
    /// Recalcule par `refreshDerivedText()`.
    public var snippetText: String = ""

    /// Texte brut concatene de tous les blocs texte, dans l'ordre, pour la recherche
    /// plein texte (Phase 4/15). Recalcule par `refreshDerivedText()`.
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
    /// Les autres types (`divider`, `table`, `tableRow`, `columnList`, `column`,
    /// `image`, `file`, `databaseView`, `pageLink`...) ne contribuent pas de texte brut
    /// eux-memes, mais un type non porteur peut quand meme avoir des descendants
    /// porteurs (une `tableCell` sous un `table`/`tableRow`, un item de liste sous un
    /// autre) : voir `collectText`, qui descend recursivement dans `children`.
    ///
    /// `tableCell` (Phase 8) est delibermement dans cet ensemble : le texte d'une
    /// cellule de tableau doit rester trouvable par la recherche plein texte (Phase
    /// 15), au meme titre qu'un paragraphe. Le risque d'un extrait de note "absurde"
    /// (cellules concatenees sans structure visible) est juge acceptable : c'est deja
    /// le comportement assume pour les items de liste imbriques (une puce ou une
    /// sous-puce produit une ligne de plus dans `plainText`, sans marqueur visuel), et
    /// preferable a une recherche qui ne trouve pas le contenu d'un tableau.
    private static let textBearingTypes: Set<BlockType> = [
        .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
        .bulletedList, .numberedList, .todo, .quote, .callout, .code, .tableCell
    ]

    /// Parcourt `blocks` en profondeur (tries par `order` a chaque niveau) et retourne
    /// le texte brut de chaque bloc d'un type porteur de texte (`textBearingTypes`),
    /// non vide. Descend dans `children` meme pour un bloc dont le propre type n'est
    /// pas porteur (`table`, `tableRow`, `bulletedList` racine sans texte propre...) :
    /// c'est ce qui permet au texte d'un item de liste imbrique ou d'une cellule de
    /// tableau de remonter jusqu'a `plainText`, meme si `blocks` (la relation directe
    /// `Note.blocks`) ne contient que les blocs racine de la note.
    private static func collectText(from blocks: [Block]) -> [String] {
        blocks.sorted { $0.order < $1.order }.flatMap { block -> [String] in
            var texts: [String] = []
            if textBearingTypes.contains(block.type), let text = block.text?.plainText, !text.isEmpty {
                texts.append(text)
            }
            texts.append(contentsOf: collectText(from: block.children ?? []))
            return texts
        }
    }

    /// Recalcule `plainText` et `snippetText` a partir des blocs actuels (recursif, voir
    /// `collectText`). A appeler explicitement apres toute mutation de `blocks` ou du
    /// texte d'un bloc (voir la documentation de ce type) - **point d'entree unique**,
    /// voir la section dediee plus haut sur ce type.
    public func refreshDerivedText() {
        let orderedTexts = Self.collectText(from: blocks ?? [])

        plainText = orderedTexts.joined(separator: "\n")

        if plainText.count > Self.snippetMaxLength {
            let cutoff = plainText.index(plainText.startIndex, offsetBy: Self.snippetMaxLength)
            snippetText = String(plainText[..<cutoff])
        } else {
            snippetText = plainText
        }
    }
}
