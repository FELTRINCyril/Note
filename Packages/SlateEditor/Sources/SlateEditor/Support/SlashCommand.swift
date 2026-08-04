import SlateModel

/// Une des trois categories affichees par le menu "/" (docs/06_slash_commandes.md,
/// spec fonctionnelle : "Categories : Basique, Media, Avance"). `CaseIterable` fournit
/// directement l'ORDRE d'affichage voulu par la spec -- `SlashCommandRegistry.allCommands`
/// regroupe ses commandes selon cet ordre de `allCases`, jamais un tri alphabetique ou
/// declare a la main ailleurs.
public enum SlashCommandCategory: String, CaseIterable, Sendable {
    case basic
    case media
    case advanced
}

/// Une entree du menu "/" : un type de bloc INSERABLE/CONVERTIBLE aujourd'hui, avec son
/// libelle, sa description, ses alias de recherche et son icone -- tous DEJA localises
/// (voir `SlashCommandRegistry` pour la construction). Structure pure (aucun AppKit,
/// aucun `ModelContext`) : l'action reelle (inserer un nouveau bloc, ou convertir le
/// bloc courant s'il est vide -- docs/06, spec fonctionnelle) est decidee par le
/// CONTROLEUR qui consomme `targetType`, jamais par ce type-ci. Separer la description
/// de la commande de son execution est ce qui rend `SlashCommandRegistry`/
/// `SlashCommandFilter` testables sans construire de `Note`/`Block`.
public struct SlashCommand: Identifiable, Sendable, Equatable {
    /// Identifiant STABLE de la commande, independant de la localisation (contrairement
    /// a `title`) -- utilise par le controleur pour retrouver une commande selectionnee
    /// (ex. "heading1", "bulletedList", "divider") et par les tests pour verifier
    /// l'unicite du registre.
    public let id: String
    /// Libelle affiche, deja localise.
    public let title: String
    /// Description courte affichee sous le titre, deja localisee -- une vraie phrase
    /// utile ("Grand titre de section"), jamais une paraphrase du titre (voir la
    /// documentation de tete de `SlashCommandRegistry`).
    public let subtitle: String
    /// Termes de recherche additionnels, en MINUSCULES SANS ACCENTS (voir la
    /// documentation de tete de `SlashCommandRegistry`, section "Convention des alias") :
    /// couvrent le francais ET l'anglais pour que la recherche fonctionne quelle que
    /// soit la langue tapee, independamment de la langue d'affichage de `title`.
    public let aliases: [String]
    /// Nom d'un symbole SF (`Image(systemName:)`), a la charge de la vue popover
    /// (hors perimetre de ce fichier) de resoudre en glyphe reel.
    public let systemImage: String
    public let category: SlashCommandCategory
    /// Type de bloc obtenu en choisissant cette commande. Contrainte d'exhaustivite :
    /// voir la documentation de tete de `SlashCommandRegistry`, section "Types offerts".
    public let targetType: BlockType

    public init(
        id: String,
        title: String,
        subtitle: String,
        aliases: [String],
        systemImage: String,
        category: SlashCommandCategory,
        targetType: BlockType
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.aliases = aliases
        self.systemImage = systemImage
        self.category = category
        self.targetType = targetType
    }
}
