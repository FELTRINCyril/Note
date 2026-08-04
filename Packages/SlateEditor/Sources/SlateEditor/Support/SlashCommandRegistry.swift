import SlateModel

/// Registre STATIQUE des commandes offertes par le menu "/" (docs/06_slash_commandes.md,
/// sous-etape 6.1). `allCommands` est la SEULE source de verite consommee par le
/// controleur et par `SlashCommandFilter` -- aucune autre liste de types de bloc ne doit
/// etre maintenue en parallele pour cet ecran.
///
/// ## Types offerts : reutilisation du routage de rendu, pas une nouvelle liste
/// La liste ci-dessous doit rester en phase avec les types qui ont un rendu REEL
/// aujourd'hui (`BlockRenderKind`/`BlockRenderRouting.kind(for:)`, la meme regle
/// d'honnetete d'interface que `BlockConversion.convertibleTypes` -- voir sa
/// documentation de tete pour le principe general : "jamais une entree qui a l'air
/// actionnable sans agir"). Concretement :
/// - `basic` : `paragraph`, les 6 niveaux de titre, les 3 types de liste, `quote`,
///   `divider`. Tous rendus via un cas NON `.unsupported` de `BlockRenderRouting`.
/// - `advanced` : `code`, meme raison.
/// - `media` : VOLONTAIREMENT VIDE. `image`/`file` ont un `BlockType` reserve mais
///   retombent aujourd'hui sur `.unsupported` dans `BlockRenderRouting` -- leur rendu
///   riche (import de fichier, apercu) arrive en Phase 9. Les proposer maintenant
///   ouvrirait une commande qui "marche" en apparence (elle change bien `block.type`)
///   mais affiche `UnsupportedBlockContentView`, exactement la classe de mensonge
///   d'interface que ce projet refuse depuis la 5.4/5.5.
/// - EXCLUS explicitement, meme motif : `callout`, `table` (Phase 8), `columnList`/
///   `column` (Phase 10), `bookmark`/`embed`/`databaseView`/`pageLink` (v2). Chaque type
///   qui gagnera un rendu reel dans une phase ulterieure devra rejoindre `allCommands` a
///   ce moment-la (et sa categorie `media`/`advanced` alors cessera d'etre vide) --
///   jamais avant. Cette liste est donc EXTENSIBLE par construction, pas fermee.
///
/// ## Convention des alias
/// Chaque `aliases` couvre le FRANCAIS et l'ANGLAIS, en minuscules SANS accents (ex.
/// heading1 : "titre", "h1", "heading", "grand titre") -- l'utilisateur tape sa requete
/// dans la langue qui lui vient, independamment de la langue d'affichage de `title`.
/// `SlashCommandFilter` replie de toute facon la requete ET les alias au moment de la
/// comparaison (voir sa documentation de tete), mais stocker les alias DEJA sans accents
/// documente l'intention au site de declaration et evite un aller-retour mental entre
/// "cette chaine porte-t-elle un accent que le pliage va de toute facon supprimer".
///
/// ## Pourquoi un enum plutot qu'une struct/un tableau charge au demarrage
/// Aucun etat, aucune dependance externe (pas de `ModelContext`, pas de reseau) : un
/// enum sans cas, comme `BlockRenderRouting`, documente que ce type n'est qu'une
/// FACADE de calcul, jamais instancie. `@MainActor` est impose par le contrat de cette
/// sous-etape (les deux autres agents -- vue popover, controleur -- codent contre lui
/// en parallele) ; rien dans le corps actuel n'exige d'isolation, mais l'annotation
/// prepare la Phase 7+ ou une commande pourrait un jour consulter un etat isole au
/// thread principal (ex. `FormattingController`).
@MainActor
public enum SlashCommandRegistry {
    /// Toutes les commandes disponibles, regroupees par categorie dans l'ordre de
    /// `SlashCommandCategory.allCases` (basic, media, advanced). Une categorie sans
    /// commande (aujourd'hui `media`) ne produit simplement aucune entree -- voir la
    /// documentation de tete de fichier, "Types offerts" : c'est a l'appelant (vue
    /// popover) de ne pas afficher de section vide, pas a ce registre de la simuler.
    public static var allCommands: [SlashCommand] {
        SlashCommandCategory.allCases.flatMap(commands(for:))
    }

    private static func commands(for category: SlashCommandCategory) -> [SlashCommand] {
        switch category {
        case .basic:
            basicCommands
        case .media:
            []
        case .advanced:
            advancedCommands
        }
    }

    private static var basicCommands: [SlashCommand] {
        [
            SlashCommand(
                id: "paragraph",
                title: EditorStrings.blockTypeLabel(.paragraph),
                subtitle: EditorStrings.slashCommandSubtitle(.paragraph),
                aliases: ["texte", "text", "paragraphe", "paragraph"],
                systemImage: "text.alignleft",
                category: .basic,
                targetType: .paragraph
            ),
            heading(
                level: 1, systemImage: "1.square",
                aliases: ["titre", "titre 1", "h1", "heading", "heading 1", "grand titre"]
            ),
            heading(
                level: 2, systemImage: "2.square",
                aliases: ["titre", "titre 2", "h2", "heading", "heading 2", "titre moyen"]
            ),
            heading(
                level: 3, systemImage: "3.square",
                aliases: ["titre", "titre 3", "h3", "heading", "heading 3", "petit titre"]
            ),
            heading(
                level: 4, systemImage: "4.square",
                aliases: ["titre", "titre 4", "h4", "heading", "heading 4", "sous-titre"]
            ),
            heading(
                level: 5, systemImage: "5.square",
                aliases: ["titre", "titre 5", "h5", "heading", "heading 5", "sous-titre"]
            ),
            heading(
                level: 6, systemImage: "6.square",
                aliases: ["titre", "titre 6", "h6", "heading", "heading 6", "sous-titre"]
            ),
            SlashCommand(
                id: "bulletedList",
                title: EditorStrings.blockTypeLabel(.bulletedList),
                subtitle: EditorStrings.slashCommandSubtitle(.bulletedList),
                aliases: ["liste", "puces", "liste a puces", "bulleted", "bullet list", "list"],
                systemImage: "list.bullet",
                category: .basic,
                targetType: .bulletedList
            ),
            SlashCommand(
                id: "numberedList",
                title: EditorStrings.blockTypeLabel(.numberedList),
                subtitle: EditorStrings.slashCommandSubtitle(.numberedList),
                aliases: ["liste", "numerotee", "liste numerotee", "numbered", "numbered list", "ordered list"],
                systemImage: "list.number",
                category: .basic,
                targetType: .numberedList
            ),
            SlashCommand(
                id: "todo",
                title: EditorStrings.blockTypeLabel(.todo),
                subtitle: EditorStrings.slashCommandSubtitle(.todo),
                aliases: ["tache", "case a cocher", "checkbox", "todo", "to-do", "task list"],
                systemImage: "checklist",
                category: .basic,
                targetType: .todo
            ),
            SlashCommand(
                id: "quote",
                title: EditorStrings.blockTypeLabel(.quote),
                subtitle: EditorStrings.slashCommandSubtitle(.quote),
                aliases: ["citation", "quote", "blockquote"],
                systemImage: "text.quote",
                category: .basic,
                targetType: .quote
            ),
            SlashCommand(
                id: "divider",
                title: EditorStrings.blockTypeLabel(.divider),
                subtitle: EditorStrings.slashCommandSubtitle(.divider),
                aliases: ["separateur", "ligne", "divider", "horizontal rule", "hr"],
                systemImage: "minus",
                category: .basic,
                targetType: .divider
            )
        ]
    }

    private static var advancedCommands: [SlashCommand] {
        [
            SlashCommand(
                id: "code",
                title: EditorStrings.blockTypeLabel(.code),
                subtitle: EditorStrings.slashCommandSubtitle(.code),
                aliases: ["code", "bloc de code", "code block", "snippet"],
                systemImage: "chevron.left.forwardslash.chevron.right",
                category: .advanced,
                targetType: .code
            )
        ]
    }

    /// Construit une commande "titre de niveau N" -- extrait pour eviter de repeter six
    /// fois la meme resolution `blockTypeLabel`/`slashCommandSubtitle`/`id`/`targetType`.
    private static func heading(level: Int, systemImage: String, aliases: [String]) -> SlashCommand {
        let type = headingType(forLevel: level)
        return SlashCommand(
            id: "heading\(level)",
            title: EditorStrings.blockTypeLabel(type),
            subtitle: EditorStrings.slashCommandSubtitle(type),
            aliases: aliases,
            systemImage: systemImage,
            category: .basic,
            targetType: type
        )
    }

    private static func headingType(forLevel level: Int) -> BlockType {
        switch level {
        case 1: .heading1
        case 2: .heading2
        case 3: .heading3
        case 4: .heading4
        case 5: .heading5
        default: .heading6
        }
    }
}
