import Foundation
import SlateModel

/// Identifie un groupe de regroupement temporel de la liste de notes (spec E3,
/// "Groupes : Epinglees -> Aujourd'hui -> Hier -> 7 jours -> 30 jours -> mois (annee en
/// cours) -> annees decroissantes"). La section "Epinglees" n'est PAS un cas de cet
/// enum : elle est portee separement par `NoteListView` via
/// `NoteListQuery.notes(in:pinned: .pinnedOnly)`, jamais par `NoteDateGrouper` (voir la
/// documentation de tete de `NoteListQuery.swift` : les epinglees ne doivent jamais
/// apparaitre deux fois).
public enum NoteDateGroupKind: Hashable {
    case today
    case yesterday
    case previous7Days
    case previous30Days
    /// Mois de l'annee EN COURS uniquement (spec E3) : un mois d'une annee passee ne
    /// produit jamais ce cas, seulement `.year`. `month` est 1...12.
    case month(year: Int, month: Int)
    case year(Int)
}

/// Un groupe temporel de la liste de notes : son identite (`NoteDateGroupKind`) et les
/// notes qu'il porte, dans l'ordre ou elles ont ete recues par `NoteDateGrouper.group`
/// (cette fonction ne re-trie jamais - voir sa documentation).
public struct NoteDateGroup: Identifiable {
    public var id: NoteDateGroupKind { kind }
    public let kind: NoteDateGroupKind
    public let notes: [Note]
}

/// Regroupement temporel de la liste de notes, exactement comme Notes d'Apple
/// (`docs/04_liste_notes.md`, spec E3). Fonction PURE et testable : ni `Date()` ni
/// `Calendar.current` ne sont lus a l'interieur de `group` - `calendar` et `now` sont
/// systematiquement les parametres recus, jamais relus depuis l'environnement reel, ce
/// qui rend les cas limites (minuit, changement de mois/annee, fuseaux horaires)
/// deterministes et testables (voir `NoteDateGrouperTests`).
///
/// ## Bornes exactes retenues pour "7 jours precedents" et "30 jours precedents"
///
/// `deltaDays` est l'ecart en JOURS CALENDAIRES (jamais en secondes - voir la note plus
/// bas sur l'heure d'ete) entre le debut du jour de la note et le debut du jour de
/// `now`, via `Calendar.dateComponents([.day], from:to:)`.
///
/// - `deltaDays <= 0` -> `.today`. Le cas strictement negatif (une note "du futur", par
///   exemple `modifiedAt` legerement apres `now` a cause d'une horloge desynchronisee)
///   est traite comme aujourd'hui plutot que de produire un groupe absurde : c'est un
///   choix de robustesse, pas un comportement attendu en usage normal.
/// - `deltaDays == 1` -> `.yesterday`.
/// - `deltaDays` dans `2...7` -> `.previous7Days`. Aujourd'hui (0) et hier (1) ont deja
///   leur propre groupe : la fenetre "7 jours precedents" continue donc a partir du
///   surlendemain (J-2) et va jusqu'a J-7 inclus, soit 6 jours.
/// - `deltaDays` dans `8...30` -> `.previous30Days`, en continuite directe avec la
///   fenetre precedente (J-8 a J-30 inclus, soit 23 jours).
/// - au-dela (`deltaDays > 30`) : `.month(year:month:)` si l'annee de la note est celle
///   de `now`, sinon `.year` de l'annee de la note. Une note de janvier de l'annee en
///   cours alors que `now` est en decembre tombe donc dans `.month`, jamais dans
///   `.year` : "l'annee en cours" prime sur `deltaDays`, exactement comme demande par
///   la spec ("mois de l'annee en cours").
///
/// ## Pourquoi `Calendar`, jamais un calcul en secondes
///
/// Les jours n'ont pas tous 86 400 secondes (passage a l'heure d'ete/hiver : certains
/// jours en ont 82 800 ou 90 000). Un calcul par soustraction de `TimeInterval` et
/// division par 86 400 classerait une note du 30 mars a 23h50 (veille du passage a
/// l'heure d'ete en zone Europe) dans le mauvais groupe un jour sur deux dans l'annee.
/// Toute comparaison passe donc par `Calendar.startOfDay(for:)` et
/// `Calendar.dateComponents([.day], from:to:)`, qui delegent au calendrier le calcul
/// correct compte tenu du fuseau horaire et des transitions d'heure d'ete.
public enum NoteDateGrouper {
    /// Regroupe `notes` en groupes temporels ordonnes (Aujourd'hui -> Hier -> 7 jours ->
    /// 30 jours -> mois de l'annee en cours, du plus recent au plus ancien -> annees
    /// passees, decroissantes). Un groupe absent de `notes` n'apparait pas dans le
    /// resultat (pas de groupe vide).
    ///
    /// Ne re-trie JAMAIS les notes a l'interieur d'un groupe : l'ordre a l'interieur
    /// d'un groupe reprend exactement l'ordre de `notes` en entree (deja trie en amont
    /// par `NoteListQuery`) - grouper n'est pas trier.
    ///
    /// - Parameter notes: dejas filtrees (dossier, recherche, hors epinglees - voir
    ///   `NoteDateGroupKind`) et deja triees par l'appelant.
    /// - Parameter referenceDate: date de reference a utiliser POUR CHAQUE note. Permet
    ///   au critere de tri choisi par l'utilisateur (`NoteSortCriterion`) de changer la
    ///   date qui determine le groupe : `\.modifiedAt` par defaut (comportement de
    ///   Notes d'Apple), `\.createdAt` si l'utilisateur trie par date de creation.
    /// - Parameter calendar: injecte, jamais `Calendar.current` lu en dur - voir la
    ///   documentation de tete de ce type.
    /// - Parameter now: injecte, jamais `Date.now`/`Date()` lu en dur - voir la
    ///   documentation de tete de ce type.
    public static func group(
        notes: [Note],
        referenceDate: (Note) -> Date,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [NoteDateGroup] {
        let startOfToday = calendar.startOfDay(for: now)
        let currentYear = calendar.component(.year, from: now)

        var todayNotes: [Note] = []
        var yesterdayNotes: [Note] = []
        var previous7Notes: [Note] = []
        var previous30Notes: [Note] = []
        var monthBuckets: [Int: [Note]] = [:]
        var yearBuckets: [Int: [Note]] = [:]

        for note in notes {
            let date = referenceDate(note)
            let startOfNoteDay = calendar.startOfDay(for: date)
            let deltaDays = calendar.dateComponents([.day], from: startOfNoteDay, to: startOfToday).day ?? 0

            if deltaDays <= 0 {
                todayNotes.append(note)
            } else if deltaDays == 1 {
                yesterdayNotes.append(note)
            } else if deltaDays <= 7 {
                previous7Notes.append(note)
            } else if deltaDays <= 30 {
                previous30Notes.append(note)
            } else {
                let year = calendar.component(.year, from: date)
                if year == currentYear {
                    let month = calendar.component(.month, from: date)
                    monthBuckets[month, default: []].append(note)
                } else {
                    yearBuckets[year, default: []].append(note)
                }
            }
        }

        var groups: [NoteDateGroup] = []
        if !todayNotes.isEmpty {
            groups.append(NoteDateGroup(kind: .today, notes: todayNotes))
        }
        if !yesterdayNotes.isEmpty {
            groups.append(NoteDateGroup(kind: .yesterday, notes: yesterdayNotes))
        }
        if !previous7Notes.isEmpty {
            groups.append(NoteDateGroup(kind: .previous7Days, notes: previous7Notes))
        }
        if !previous30Notes.isEmpty {
            groups.append(NoteDateGroup(kind: .previous30Days, notes: previous30Notes))
        }
        for month in monthBuckets.keys.sorted(by: >) {
            let kind = NoteDateGroupKind.month(year: currentYear, month: month)
            groups.append(NoteDateGroup(kind: kind, notes: monthBuckets[month] ?? []))
        }
        for year in yearBuckets.keys.sorted(by: >) {
            groups.append(NoteDateGroup(kind: .year(year), notes: yearBuckets[year] ?? []))
        }
        return groups
    }
}
