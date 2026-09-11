import SlateModel
import Testing

@testable import SlateEditor

/// `SlashCommandRegistry` : registre PUR des commandes du menu "/" (docs/06, sous-etape
/// 6.1). Verifie l'exhaustivite/l'honnetete d'interface documentee dans sa doc de tete
/// (aucun type sans rendu reel, `media` vide aujourd'hui) et l'integrite structurelle
/// que le controleur/la vue popover supposent deja (id uniques, ordre par categorie).
@MainActor
@Suite("SlashCommandRegistry")
struct SlashCommandRegistryTests {
    @Test("Les identifiants des commandes sont tous uniques")
    func allCommandIDsAreUnique() {
        let ids = SlashCommandRegistry.allCommands.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test("Chaque targetType du registre a un rendu REEL (jamais .unsupported)")
    func everyTargetTypeHasRealRender() {
        for command in SlashCommandRegistry.allCommands {
            let kind = BlockRenderRouting.kind(for: command.targetType)
            if case .unsupported = kind {
                Issue.record("La commande \(command.id) cible \(command.targetType), sans rendu reel")
            }
        }
    }

    @Test("La categorie media est vide aujourd'hui, sans section fantome")
    func mediaCategoryIsEmpty() {
        let mediaCommands = SlashCommandRegistry.allCommands.filter { $0.category == .media }
        #expect(mediaCommands.isEmpty)
    }

    @Test("Les commandes sont regroupees par categorie, dans l'ordre de SlashCommandCategory.allCases")
    func commandsAreGroupedByCategoryOrder() {
        let categories = SlashCommandRegistry.allCommands.map(\.category)
        let expectedOrder = SlashCommandCategory.allCases

        // Les categories rencontrees, sans doublon, doivent suivre le meme ORDRE que
        // `expectedOrder` (une categorie vide -- media -- disparait simplement de la
        // sequence rencontree, sans casser l'ordre relatif des autres).
        var encountered: [SlashCommandCategory] = []
        for category in categories where encountered.last != category {
            encountered.append(category)
        }
        let expectedEncountered = expectedOrder.filter { encountered.contains($0) }
        #expect(encountered == expectedEncountered)
    }

    @Test("Le registre couvre exactement les 15 types de bloc a rendu reel (Phase 8 : callout, table)")
    func registryCoversExpectedTypes() {
        let targetTypes = Set(SlashCommandRegistry.allCommands.map(\.targetType))
        let expected: Set<BlockType> = [
            .paragraph,
            .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
            .bulletedList, .numberedList, .todo,
            .quote, .divider, .code,
            .callout, .table
        ]
        #expect(targetTypes == expected)
    }

    @Test("Aucun type reserve a une phase ulterieure, ni tableRow/tableCell, n'apparait dans le registre")
    func registryExcludesFutureTypes() {
        let targetTypes = Set(SlashCommandRegistry.allCommands.map(\.targetType))
        let excluded: [BlockType] = [
            .image, .file, .tableRow, .tableCell, .columnList, .column,
            .bookmark, .embed, .databaseView, .pageLink
        ]
        for type in excluded {
            #expect(!targetTypes.contains(type))
        }
    }

    @Test("Chaque commande porte un titre, un sous-titre et des alias non vides")
    func everyCommandHasTitleSubtitleAndAliases() {
        for command in SlashCommandRegistry.allCommands {
            #expect(!command.title.isEmpty)
            #expect(!command.subtitle.isEmpty)
            #expect(!command.aliases.isEmpty)
            #expect(!command.systemImage.isEmpty)
        }
    }

    @Test("La commande divider expose desormais un libelle localise, pas le rawValue brut")
    func dividerCommandUsesLocalizedLabel() {
        let divider = SlashCommandRegistry.allCommands.first { $0.targetType == .divider }
        #expect(divider?.title != BlockType.divider.rawValue)
    }
}
