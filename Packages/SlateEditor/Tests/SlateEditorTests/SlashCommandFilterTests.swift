import SlateModel
import Testing

@testable import SlateEditor

/// `SlashCommandFilter` : filtrage fuzzy PUR du menu "/" (docs/06, sous-etape 6.2).
/// Construit des `SlashCommand` ad hoc plutot que de dependre systematiquement du
/// registre reel -- cela isole le bareme de score de tout futur changement de
/// libelle/alias dans `SlashCommandRegistry`, tout en gardant quelques tests contre le
/// registre reel pour la couverture de bout en bout.
@MainActor
@Suite("SlashCommandFilter")
struct SlashCommandFilterTests {
    // MARK: - Helpers

    private func command(
        id: String, title: String, aliases: [String] = [], type: BlockType = .paragraph
    ) -> SlashCommand {
        SlashCommand(
            id: id, title: title, subtitle: "Sous-titre de \(id)", aliases: aliases,
            systemImage: "text.alignleft", category: .basic, targetType: type
        )
    }

    // MARK: - Requete vide

    @Test("Une requete vide rend toutes les commandes, dans l'ordre du registre, score 0, sans offset")
    func emptyQueryReturnsEverythingInOrder() {
        let commands = [
            command(id: "a", title: "Alpha"),
            command(id: "b", title: "Beta"),
            command(id: "c", title: "Gamma")
        ]

        let results = SlashCommandFilter.match(query: "", in: commands)

        #expect(results.map(\.id) == ["a", "b", "c"])
        #expect(results.allSatisfy { $0.score == 0 })
        #expect(results.allSatisfy { $0.matchedTitleOffsets.isEmpty })
    }

    // MARK: - Bareme : prefixe > contigu > sous-sequence > alias

    @Test("Un prefixe exact du titre est classe premier, devant un match contigu plus loin dans le titre")
    func exactPrefixRanksFirst() {
        let commands = [
            command(id: "containsElsewhere", title: "Case a cocher"), // "coc" contigu, pas en prefixe
            command(id: "prefix", title: "Cochee")                     // "coc" en prefixe
        ]

        let results = SlashCommandFilter.match(query: "coc", in: commands)

        #expect(results.map(\.id) == ["prefix", "containsElsewhere"])
        #expect(results[0].score > results[1].score)
    }

    @Test("Un match contigu dans le titre est classe devant une sous-sequence non contigue")
    func contiguousRanksAboveSubsequence() {
        let commands = [
            command(id: "subsequence", title: "Titre expose"), // "tex" : t-e-x non contigu ("Ti[t]r[e] [ex]pose")
            command(id: "contiguous", title: "Un texte")          // "tex" contigu ("texte")
        ]

        let results = SlashCommandFilter.match(query: "tex", in: commands)

        #expect(results.map(\.id) == ["contiguous", "subsequence"])
        #expect(results[0].score > results[1].score)
    }

    @Test("Un match sur un alias seul est classe derriere n'importe quel match du titre")
    func aliasMatchRanksBelowAnyTitleMatch() {
        let commands = [
            command(id: "aliasOnly", title: "Paragraphe", aliases: ["puce"]),
            command(id: "titleSubsequence", title: "Puissance")
        ]

        let results = SlashCommandFilter.match(query: "puc", in: commands)

        #expect(results.map(\.id) == ["titleSubsequence", "aliasOnly"])
    }

    @Test("Une requete qui ne matche ni titre ni alias exclut la commande du resultat")
    func noMatchExcludesCommand() {
        let commands = [command(id: "a", title: "Paragraphe", aliases: ["texte"])]

        let results = SlashCommandFilter.match(query: "zzz-inexistant", in: commands)

        #expect(results.isEmpty)
    }

    // MARK: - Insensibilite casse + accents

    @Test("Le filtrage ignore casse et accents, cote requete comme cote titre")
    func caseAndDiacriticInsensitive() {
        let commands = [command(id: "numbered", title: "Numérotée")]

        let upperNoAccent = SlashCommandFilter.match(query: "NUMEROTEE", in: commands)
        let lowerWithAccent = SlashCommandFilter.match(query: "numérotée", in: commands)

        #expect(upperNoAccent.map(\.id) == ["numbered"])
        #expect(lowerWithAccent.map(\.id) == ["numbered"])
    }

    // MARK: - Sous-sequence non contigue

    @Test("Une sous-sequence non contigue matche, meme sans occurrence contigue dans le titre")
    func nonContiguousSubsequenceMatches() {
        let commands = [command(id: "heading", title: "Titre 1")]

        // "t1" : les caracteres apparaissent dans l'ordre ("Titre [1]" -> t...1) mais pas
        // cote a cote.
        let results = SlashCommandFilter.match(query: "t1", in: commands)

        #expect(results.map(\.id) == ["heading"])
    }

    // MARK: - Stabilite de l'ordre a score egal

    @Test("A score egal, l'ordre du registre d'origine est conserve")
    func stableOrderAtEqualScore() {
        let commands = [
            command(id: "first", title: "Xylophone"),
            command(id: "second", title: "Xylographie"),
            command(id: "third", title: "Xylographe")
        ]

        // "xylo" est un prefixe exact des trois titres : meme score, l'ordre d'origine
        // doit survivre au tri.
        let results = SlashCommandFilter.match(query: "xylo", in: commands)

        #expect(results.map(\.id) == ["first", "second", "third"])
    }

    // MARK: - Offsets en CARACTERES, sur un titre non-ASCII

    @Test("matchedTitleOffsets est exprime en caracteres, aligne sur un titre contenant un accent")
    func matchedTitleOffsetsAreCharacterAligned() {
        let commands = [command(id: "quote", title: "Citation à retenir")]

        // "à" est le 10e caractere (index 9) du titre -- un decompte en UTF-16 serait
        // identique ici (caractere latin de base), mais l'intention du test est de fixer
        // la CONVENTION (offsets de caracteres), pas de forcer une divergence UTF-16 qui
        // n'existe pas pour ce caractere precis.
        let results = SlashCommandFilter.match(query: "à retenir", in: commands)

        #expect(results.map(\.id) == ["quote"])
        let offsets = results[0].matchedTitleOffsets
        let titleCharacters = Array("Citation à retenir")
        #expect(offsets == Array(9..<titleCharacters.count))
    }

    @Test("Un match par alias ne rend jamais d'offset dans le titre")
    func aliasMatchHasNoTitleOffsets() {
        let commands = [command(id: "a", title: "Paragraphe", aliases: ["puce"])]

        let results = SlashCommandFilter.match(query: "puc", in: commands)

        #expect(results.map(\.id) == ["a"])
        #expect(results[0].matchedTitleOffsets.isEmpty)
    }

    // MARK: - Contre le registre reel (couverture de bout en bout)

    @Test("Le filtrage fonctionne contre le registre reel : chaque commande se retrouve avec son propre titre")
    func filterWorksAgainstRealRegistry() {
        let commands = SlashCommandRegistry.allCommands

        for expected in commands {
            let results = SlashCommandFilter.match(query: expected.title, in: commands)
            #expect(results.contains { $0.id == expected.id })
        }
    }

    @Test("Un alias francais et son equivalent anglais retrouvent la meme commande dans le registre reel")
    func frenchAndEnglishAliasesFindSameCommand() {
        let commands = SlashCommandRegistry.allCommands

        let french = SlashCommandFilter.match(query: "titre", in: commands)
        let english = SlashCommandFilter.match(query: "heading", in: commands)

        #expect(french.contains { $0.id == "heading1" })
        #expect(english.contains { $0.id == "heading1" })
    }
}
