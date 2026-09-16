import SwiftUI

/// Vue Calendrier (design/tokens.md §18, artboard B : "grille mois et vue semaine,
/// pastille d'entree"). Composants de PRESENTATION purs : `SlateUI` ne connait ni les
/// dates reelles ni le champ de date affiche, tout est fourni via `SlateDatabaseCalendarDay`.

/// Une case de jour, deja resolue par l'appelant (numero, appartenance au mois affiche,
/// jour courant, evenements a afficher).
public struct SlateDatabaseCalendarDay: Identifiable, Sendable, Equatable {
    public let id: Int
    public let dayNumber: Int
    public let isInCurrentMonth: Bool
    public let isToday: Bool
    public let eventTitles: [String]

    public init(id: Int, dayNumber: Int, isInCurrentMonth: Bool, isToday: Bool, eventTitles: [String] = []) {
        self.id = id
        self.dayNumber = dayNumber
        self.isInCurrentMonth = isInCurrentMonth
        self.isToday = isToday
        self.eventTitles = eventTitles
    }
}

/// Barre de navigation mois/semaine : titre (ex: "Septembre 2026") + chevrons +
/// bouton "Aujourd'hui".
public struct DatabaseCalendarNavigationBar: View {
    private let title: String
    private let onPrevious: () -> Void
    private let onToday: () -> Void
    private let onNext: () -> Void

    public init(
        title: String,
        onPrevious: @escaping () -> Void,
        onToday: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.title = title
        self.onPrevious = onPrevious
        self.onToday = onToday
        self.onNext = onNext
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
            Spacer(minLength: Spacing.xs)
            Button(action: onPrevious) {
                Image(systemName: "chevron.left").slateIconFont(13, weight: .semibold, relativeTo: .body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SlateColor.textSecondary)
            .accessibilityLabel(SlateUIStrings.databaseCalendarPreviousMonth)

            Button(action: onToday) {
                Text(SlateUIStrings.databaseCalendarTodayLabel)
                    .slateFont(SlateFont.label)
                    .foregroundStyle(SlateColor.textPrimary)
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "chevron.right").slateIconFont(13, weight: .semibold, relativeTo: .body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SlateColor.textSecondary)
            .accessibilityLabel(SlateUIStrings.databaseCalendarNextMonth)
        }
    }
}

/// Grille de mois, 7 colonnes. `onSelectDay` remonte l'identifiant opaque du jour tape.
public struct DatabaseCalendarMonthGridView: View {
    private let weekdaySymbols: [String]
    private let days: [SlateDatabaseCalendarDay]
    private let onSelectDay: (SlateDatabaseCalendarDay) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    public init(
        weekdaySymbols: [String],
        days: [SlateDatabaseCalendarDay],
        onSelectDay: @escaping (SlateDatabaseCalendarDay) -> Void = { _ in }
    ) {
        self.weekdaySymbols = weekdaySymbols
        self.days = days
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            LazyVGrid(columns: Self.columns, spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .slateFont(SlateTextStyle(size: 11, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(SlateColor.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Self.columns, spacing: SlateGeometry.strokeHairline) {
                ForEach(days) { day in
                    DatabaseCalendarDayCell(day: day)
                        .onTapGesture { onSelectDay(day) }
                }
            }
            .background(SlateColor.databaseGridCellBorder)
            .overlay(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                    .strokeBorder(SlateColor.databaseGridCellBorder)
            )
            .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
        }
    }
}

/// Une case de jour : numero (pastille `db.calendar.today` si aujourd'hui) + pastilles
/// d'evenements (`db.calendar.eventBg`).
public struct DatabaseCalendarDayCell: View {
    private let day: SlateDatabaseCalendarDay

    public init(day: SlateDatabaseCalendarDay) {
        self.day = day
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            dayNumberLabel
            ForEach(Array(day.eventTitles.prefix(2).enumerated()), id: \.offset) { _, title in
                Text(title)
                    .slateFont(SlateTextStyle(size: 10, relativeTo: .caption2))
                    .foregroundStyle(SlateColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 4)
                    .frame(height: SlateGeometry.databaseCalendarEventPillHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SlateColor.databaseCalendarEventBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5))
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(SlateColor.bgEditor)
        .opacity(day.isInCurrentMonth ? 1 : SlateOpacity.disabled)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var dayNumberLabel: some View {
        let text = Text(day.dayNumber, format: .number)
            .slateFont(SlateTextStyle(size: 11, relativeTo: .caption2, tabularNums: true))
        if day.isToday {
            text
                .foregroundStyle(SlateColor.textLink)
                .frame(
                    width: SlateGeometry.databaseCalendarDayBadgeSize,
                    height: SlateGeometry.databaseCalendarDayBadgeSize
                )
                .background(Circle().fill(SlateColor.databaseCalendarToday))
        } else {
            text.foregroundStyle(day.isInCurrentMonth ? SlateColor.textPrimary : SlateColor.textTertiary)
        }
    }
}

/// Vue semaine : une seule rangee de 7 jours, plus haute (pour davantage d'evenements
/// empiles). Reutilise `DatabaseCalendarDayCell` : meme rendu de jour, disposition
/// horizontale simple au lieu d'une grille 4 rangees.
public struct DatabaseCalendarWeekView: View {
    private let days: [SlateDatabaseCalendarDay]
    private let onSelectDay: (SlateDatabaseCalendarDay) -> Void

    public init(
        days: [SlateDatabaseCalendarDay],
        onSelectDay: @escaping (SlateDatabaseCalendarDay) -> Void = { _ in }
    ) {
        self.days = days
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        HStack(spacing: SlateGeometry.strokeHairline) {
            ForEach(days) { day in
                DatabaseCalendarDayCell(day: day)
                    .onTapGesture { onSelectDay(day) }
            }
        }
        .background(SlateColor.databaseGridCellBorder)
        .overlay(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall)
                .strokeBorder(SlateColor.databaseGridCellBorder)
        )
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
    }
}

#Preview("DatabaseCalendarViews - mois, sombre") {
    DatabaseCalendarGalleryPreview()
        .environment(\.colorScheme, .dark)
}

#Preview("DatabaseCalendarViews - mois, clair") {
    DatabaseCalendarGalleryPreview()
        .environment(\.colorScheme, .light)
}

private struct DatabaseCalendarGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabaseCalendarNavigationBar(title: "Septembre 2026", onPrevious: {}, onToday: {}, onNext: {})
            DatabaseCalendarMonthGridView(
                weekdaySymbols: ["L", "M", "M", "J", "V", "S", "D"],
                days: (1...28).map { number in
                    SlateDatabaseCalendarDay(
                        id: number,
                        dayNumber: number,
                        isInCurrentMonth: true,
                        isToday: number == 12,
                        eventTitles: number == 12 ? ["Editeur de blocs"] : []
                    )
                }
            )
        }
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}
