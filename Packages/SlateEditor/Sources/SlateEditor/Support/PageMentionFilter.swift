import Foundation

/// Une note proposable par le selecteur de page "@"/"[[" (docs/16_liens_internes.md) :
/// projection MINIMALE de `SlateModel.Note` (identifiant + titre), pour que ce fichier
/// reste testable sans construire de vrai `Note`/`ModelContext` -- meme motif que
/// `SlashCommand`/`SlashCommandMatch` pour le menu "/", qui ne portent eux non plus
/// aucune dependance a un type SwiftUI/AppKit.
public struct NoteMentionCandidate: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String

    public init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
}

/// Un resultat de recherche de page, voir `PageMentionFilter.match(query:in:)`.
public struct NoteMentionMatch: Identifiable, Sendable, Equatable {
    public var id: UUID { candidate.id }
    public let candidate: NoteMentionCandidate

    public init(candidate: NoteMentionCandidate) {
        self.candidate = candidate
    }
}

/// Filtrage flou des notes pour le selecteur de page "@"/"[[" (docs/16_liens_internes.md :
/// "recherche parmi les notes existantes"). Logique PURE, meme esprit que
/// `SlashCommandFilter` (Phase 6) -- insensible a la casse et aux diacritiques, testable
/// sans AppKit/SwiftUI ni `ModelContext`.
///
/// ## Bareme volontairement plus simple que `SlashCommandFilter`
/// Trois niveaux au lieu de quatre (pas d'equivalent "alias", une note n'a qu'un
/// titre) : prefixe exact (meilleur), contient la requete quelque part, sous-sequence
/// non contigue (le plus faible). Une note qui ne matche AUCUN de ces trois niveaux est
/// EXCLUE du resultat -- exactement comme `SlashCommandFilter`, un score de zero
/// n'existe pas ici.
///
/// ## Pas de fermeture sur "aucun resultat"
/// A la difference du menu "/", zero resultat est un etat NORMAL et attendu du
/// selecteur de page (voir `EditorController+PageMention.swift`, "Créer la page X") :
/// ce fichier ne decide donc d'aucune regle de fermeture, il se contente de retourner
/// une liste vide, laissee a l'appelant.
public enum PageMentionFilter {
    private static let prefixScore = 3
    private static let containsScore = 2
    private static let subsequenceScore = 1

    /// Filtre `candidates` selon `query`. Requete vide -> toutes les notes, triees par
    /// titre (ordre naturel), stable par `id` en cas de titres identiques.
    public static func match(query: String, in candidates: [NoteMentionCandidate]) -> [NoteMentionMatch] {
        guard !query.isEmpty else {
            return candidates
                .sorted { lhs, rhs in
                    let comparison = lhs.title.localizedStandardCompare(rhs.title)
                    return comparison == .orderedSame
                        ? lhs.id.uuidString < rhs.id.uuidString
                        : comparison == .orderedAscending
                }
                .map { NoteMentionMatch(candidate: $0) }
        }

        let foldedQuery = fold(query)
        guard !foldedQuery.isEmpty else { return [] }

        let scored: [(score: Int, match: NoteMentionMatch)] = candidates.compactMap { candidate in
            guard let score = score(for: candidate, foldedQuery: foldedQuery) else { return nil }
            return (score, NoteMentionMatch(candidate: candidate))
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let comparison = lhs.match.candidate.title.localizedStandardCompare(rhs.match.candidate.title)
                return comparison == .orderedSame
                    ? lhs.match.candidate.id.uuidString < rhs.match.candidate.id.uuidString
                    : comparison == .orderedAscending
            }
            .map(\.match)
    }

    private static func score(for candidate: NoteMentionCandidate, foldedQuery: String) -> Int? {
        let foldedTitle = fold(candidate.title)
        if foldedTitle.hasPrefix(foldedQuery) { return prefixScore }
        if foldedTitle.contains(foldedQuery) { return containsScore }
        if isSubsequence(Array(foldedQuery), of: Array(foldedTitle)) { return subsequenceScore }
        return nil
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

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
