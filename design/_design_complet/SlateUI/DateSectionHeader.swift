//  DateSectionHeader.swift — SlateUI (E3)
//  En-tête de groupe épinglé au scroll. Hiérarchie sans lourdeur :
//  13 pt Semibold `list.dateHeader.text`, fond flouté pour rester lisible au défilement.

import SwiftUI

/// Groupes façon Notes, du plus récent au plus ancien.
public enum SlateDateGroup: Hashable, Identifiable {
    case pinned
    case today, yesterday, last7Days, last30Days
    case month(Int, year: Int)     // mois de l'année en cours
    case year(Int)

    public var id: String { title }

    public var title: String {
        switch self {
        case .pinned: "Épinglées"
        case .today: "Aujourd'hui"
        case .yesterday: "Hier"
        case .last7Days: "7 jours précédents"
        case .last30Days: "30 jours précédents"
        case .month(let m, _):
            let f = DateFormatter(); f.locale = .current
            return f.monthSymbols[max(0, min(11, m - 1))].capitalized
        case .year(let y): String(y)
        }
    }

    var systemImage: String? { self == .pinned ? "pin.fill" : nil }

    /// Classe une note dans son groupe (calendrier de l'utilisateur, pas d'arithmétique brute).
    public static func group(for note: SlateNote, now: Date = .now,
                            calendar: Calendar = .current) -> SlateDateGroup {
        if note.isPinned { return .pinned }
        let d = note.date
        if calendar.isDateInToday(d) { return .today }
        if calendar.isDateInYesterday(d) { return .yesterday }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: d),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 7 { return .last7Days }
        if days <= 30 { return .last30Days }
        let y = calendar.component(.year, from: d)
        if y == calendar.component(.year, from: now) {
            return .month(calendar.component(.month, from: d), year: y)
        }
        return .year(y)
    }
}

public struct DateSectionHeader: View {
    let group: SlateDateGroup
    var count: Int?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(_ group: SlateDateGroup, count: Int? = nil) {
        self.group = group; self.count = count
    }

    public var body: some View {
        HStack(spacing: SlateSpace.xs) {
            if let symbol = group.systemImage {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SlateColors.textSecondary)
                    .accessibilityHidden(true)
            }
            Text(group.title)
                .slateFont(.label)
                .fontWeight(.semibold)
                .foregroundStyle(SlateColors.textSecondary)
            if let count {
                Text("\(count)")
                    .slateFont(.caption)
                    .tabularDigits()
                    .foregroundStyle(SlateColors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, SlateSpace.l - SlateSpace.xxs)
        .padding(.top, SlateSpace.m)
        .padding(.bottom, SlateSpace.xs)
        .background {
            // Le contenu défile dessous : fond opaque/flouté pour rester lisible.
            if reduceTransparency { SlateColors.bgList } else { Rectangle().fill(.background) }
        }
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(count == nil ? group.title : "\(group.title), \(count!) notes")
    }
}
