import Foundation

/// Un resultat de recherche pour une commande "/" (sous-etape 6.2). Type PUR, aucune
/// dependance AppKit/SwiftUI : la vue popover (hors perimetre de ce fichier) le
/// consomme directement pour afficher titre/sous-titre/mise en evidence.
public struct SlashCommandMatch: Identifiable, Sendable, Equatable {
    public var id: String { command.id }
    public let command: SlashCommand
    /// Score du match, voir la documentation de tete de `SlashCommandFilter` pour le
    /// bareme -- plus haut est meilleur. `0` pour une requete vide (voir `match(query:in:)`).
    public let score: Int
    /// Offsets de CARACTERES (`String.Character`, PAS UTF-16) dans `command.title`
    /// correspondant aux caracteres de la requete, pour un rendu en gras cote UI. Ce
    /// projet a deja ete mordu une fois par une confusion d'unites entre UTF-16 et
    /// graphemes (voir `Support/RichTextOffset.swift`, et la documentation de
    /// `RichTextEditingTextView.insertNewline` pour l'incident d'origine) : ces offsets-
    /// ci sont volontairement dans la MEME convention "caracteres" que `RichTextOffset`,
    /// meme si ce type n'est pas reutilise directement (il modelise une position dans le
    /// texte d'un BLOC edite, pas dans un libelle d'UI ponctuel comme un titre de
    /// commande). Vide si le match provient d'un alias et non du titre (rien a mettre en
    /// evidence dans un texte que l'utilisateur ne voit pas).
    public let matchedTitleOffsets: [Int]

    public init(command: SlashCommand, score: Int, matchedTitleOffsets: [Int]) {
        self.command = command
        self.score = score
        self.matchedTitleOffsets = matchedTitleOffsets
    }
}

/// Filtrage fuzzy des commandes "/" (docs/06_slash_commandes.md, sous-etape 6.2 :
/// "Filtrage en temps reel pendant qu'on tape apres le /, fuzzy match sur nom + alias").
/// Logique PURE (aucun AppKit/SwiftUI, aucune isolation d'acteur requise) : testable
/// sans fenetre, sans `@MainActor`, exactement comme `BlockConversion`/`BlockOperations`
/// le sont deja pour l'edition de blocs.
///
/// ## Insensibilite casse + accents
/// La comparaison replie CASSE et DIACRITIQUES des DEUX cotes (requete ET titres/alias)
/// via `String.folding(options: [.caseInsensitive, .diacriticInsensitive], locale:)` --
/// necessaire pour qu'une requete tapee sans accent ("titre") retrouve un titre affiche
/// AVEC accent ailleurs dans l'app ("Numérotée" par exemple), et inversement.
///
/// Le pliage se fait CARACTERE PAR CARACTERE (`foldedCharacters(of:)`) plutot qu'en une
/// seule passe sur la chaine entiere : plier la chaine entiere pourrait en theorie
/// changer son NOMBRE de caracteres pour certains scripts (ligatures, formes
/// combinees...), ce qui casserait l'alignement 1-pour-1 entre un index dans le titre
/// plie et l'offset de caractere correspondant dans le titre ORIGINAL -- exactement le
/// genre de decalage silencieux deja corrige une fois dans ce projet pour UTF-16 (voir
/// `RichTextOffset`). Plier chaque caractere independamment garantit que le tableau
/// resultant a TOUJOURS la meme longueur que `Array(title)`, donc que ses index sont
/// directement des offsets de caracteres valides dans le titre d'origine. Les titres et
/// alias de ce module etant du francais/anglais courant, ce risque ne s'est jamais
/// materialise en pratique, mais la garantie structurelle ne coute rien a preserver.
///
/// ## Bareme de score (documente ici, pas seulement dans le code)
/// Quatre niveaux, strictement ordonnes du meilleur au moins bon -- l'espacement large
/// entre eux (300/200/100/50) laisse de la place pour un futur raffinement INTRA-niveau
/// (ex. bonus de densite pour une sous-sequence "compacte") sans jamais faire chevaucher
/// deux niveaux different :
/// 1. **Prefixe exact du titre replie** (300) : la requete est exactement le debut du
///    titre. Le cas le plus frequent en frappe reelle ("tit" -> "Titre 1"), merite le
///    classement le plus haut.
/// 2. **Match CONTIGU ailleurs dans le titre** (200) : la requete apparait telle quelle,
///    mais pas en debut de titre (ex. "cocher" dans "Case a cocher").
/// 3. **Sous-sequence NON contigue dans le titre** (100) : les caracteres de la requete
///    apparaissent dans l'ordre, mais avec des trous (ex. "ttl" dans "Titre").
/// 4. **Match sur un ALIAS** (50) : aucun des trois niveaux precedents n'a matche le
///    titre, mais la requete est une sous-sequence d'au moins un alias. Toujours moins
///    bon qu'un match sur le titre, meme un match "faible" (sous-sequence) du titre --
///    le titre est ce que l'utilisateur RECONNAIT visuellement, un alias n'est qu'un
///    filet de secours pour la recherche.
///
/// Une commande sans aucun de ces quatre matches est EXCLUE du resultat (pas un score de
/// zero) : `SlashCommandMatch` ne represente que des resultats pertinents.
///
/// ## Ordre stable, a score egal
/// `sorted(by:)` de la bibliotheque standard n'est PAS documente comme stable (voir
/// `.swiftlint.yml`/la doc Swift officielle : c'est un detail d'implementation, pas une
/// garantie). Ce fichier trie donc explicitement sur un couple (score DESC, index
/// d'origine dans `commands` ASC) via `enumerated()` -- deux commandes de meme score
/// gardent alors TOUJOURS l'ordre du registre, quelle que soit l'implementation de tri
/// choisie par le runtime.
public enum SlashCommandFilter {
    private static let titlePrefixScore = 300
    private static let titleContiguousScore = 200
    private static let titleSubsequenceScore = 100
    private static let aliasScore = 50

    /// Filtre `commands` selon `query`. Requete vide -> toutes les commandes, dans
    /// l'ordre de `commands`, score `0`, `matchedTitleOffsets` vide (voir la
    /// documentation de tete de fichier). Requete non vide -> fuzzy sur titre + alias,
    /// bareme documente en tete de fichier, trie par score decroissant puis par ordre
    /// d'origine dans `commands` (stabilite explicite).
    public static func match(query: String, in commands: [SlashCommand]) -> [SlashCommandMatch] {
        guard !query.isEmpty else {
            return commands.map { SlashCommandMatch(command: $0, score: 0, matchedTitleOffsets: []) }
        }

        // Pliage de la requete en UNE seule passe (contrairement au titre/aux alias,
        // plies CARACTERE PAR CARACTERE plus bas) : aucun offset n'est jamais expose
        // DANS la requete elle-meme (seuls ceux dans `command.title` le sont), donc rien
        // ici n'exige l'alignement 1-pour-1 que le pliage caractere par caractere
        // garantit pour le titre -- voir la documentation de tete de fichier.
        let queryCharacters = Array(fold(query))
        guard !queryCharacters.isEmpty else {
            return commands.map { SlashCommandMatch(command: $0, score: 0, matchedTitleOffsets: []) }
        }

        let scored: [(index: Int, match: SlashCommandMatch)] = commands.enumerated().compactMap { index, command in
            guard let result = matchResult(for: command, queryCharacters: queryCharacters) else { return nil }
            return (index: index, match: result)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.match.score != rhs.match.score {
                    return lhs.match.score > rhs.match.score
                }
                return lhs.index < rhs.index
            }
            .map(\.match)
    }

    // MARK: - Resolution d'un match pour une commande

    private static func matchResult(for command: SlashCommand, queryCharacters: [Character]) -> SlashCommandMatch? {
        let titleCharacters = Array(command.title)
        let foldedTitleCharacters = titleCharacters.map { fold(String($0)) }

        if let prefixOffsets = prefixMatch(query: queryCharacters, in: foldedTitleCharacters) {
            return SlashCommandMatch(command: command, score: titlePrefixScore, matchedTitleOffsets: prefixOffsets)
        }
        if let contiguousOffsets = contiguousMatch(query: queryCharacters, in: foldedTitleCharacters) {
            return SlashCommandMatch(
                command: command, score: titleContiguousScore, matchedTitleOffsets: contiguousOffsets
            )
        }
        if let subsequenceOffsets = subsequenceMatch(query: queryCharacters, in: foldedTitleCharacters) {
            return SlashCommandMatch(
                command: command, score: titleSubsequenceScore, matchedTitleOffsets: subsequenceOffsets
            )
        }
        if matchesAnyAlias(query: queryCharacters, aliases: command.aliases) {
            return SlashCommandMatch(command: command, score: aliasScore, matchedTitleOffsets: [])
        }
        return nil
    }

    // MARK: - Niveau 1 : prefixe exact du titre

    private static func prefixMatch(query: [Character], in foldedTitle: [String]) -> [Int]? {
        guard foldedTitle.count >= query.count else { return nil }
        for offset in query.indices {
            guard foldedTitle[offset] == String(query[offset]) else { return nil }
        }
        return Array(0..<query.count)
    }

    // MARK: - Niveau 2 : match contigu, ailleurs qu'au debut

    private static func contiguousMatch(query: [Character], in foldedTitle: [String]) -> [Int]? {
        guard foldedTitle.count >= query.count, !query.isEmpty else { return nil }
        let lastPossibleStart = foldedTitle.count - query.count
        // Demarre a 1 : un demarrage a 0 aurait deja ete capte par `prefixMatch` --
        // recommencer a 0 ici produirait un match identique, jamais atteint en pratique
        // puisque `prefixMatch` est essaye avant, mais autant l'exclure explicitement
        // plutot que de compter sur l'ordre d'appel pour l'empecher silencieusement.
        guard lastPossibleStart >= 1 else { return nil }
        for start in 1...lastPossibleStart {
            var matches = true
            for offset in query.indices where foldedTitle[start + offset] != String(query[offset]) {
                matches = false
                break
            }
            if matches {
                return Array(start..<(start + query.count))
            }
        }
        return nil
    }

    // MARK: - Niveau 3 : sous-sequence non contigue dans le titre

    /// Avance GREEDY caractere par caractere : pour chaque caractere de la requete,
    /// cherche la PREMIERE occurrence disponible a partir du pointeur courant. Suffisant
    /// pour ce registre (quelques dizaines de commandes courtes) -- pas besoin d'un
    /// algorithme optimisant la "compacite" du match, le bareme ne le demande pas (voir
    /// la documentation de tete de fichier).
    private static func subsequenceMatch(query: [Character], in foldedTitle: [String]) -> [Int]? {
        guard !query.isEmpty else { return nil }
        var offsets: [Int] = []
        var searchStart = 0
        for character in query {
            guard let foundIndex = foldedTitle[searchStart...].firstIndex(where: { $0 == String(character) }) else {
                return nil
            }
            offsets.append(foundIndex)
            searchStart = foundIndex + 1
        }
        return offsets
    }

    // MARK: - Niveau 4 : sous-sequence dans un alias (aucun offset expose)

    private static func matchesAnyAlias(query: [Character], aliases: [String]) -> Bool {
        aliases.contains { alias in
            let foldedAlias = Array(fold(alias))
            return isSubsequence(query, of: foldedAlias)
        }
    }

    private static func isSubsequence(_ query: [Character], of target: [Character]) -> Bool {
        guard !query.isEmpty else { return false }
        var searchStart = 0
        for character in query {
            guard let foundIndex = target[searchStart...].firstIndex(of: character) else { return false }
            searchStart = foundIndex + 1
        }
        return true
    }

    // MARK: - Pliage casse + accents

    /// Voir la documentation de tete de fichier, "Insensibilite casse + accents" --
    /// replie un `String` (typiquement un seul caractere) sur casse et diacritiques.
    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
