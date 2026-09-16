import SlateModel
import SlateUI
import SwiftUI

/// Vue Calendrier (17.5) : place chaque ligne au jour de `DatabaseViewModel.
/// calendarFieldID` (premier champ `.date`/`.createdDate`/`.modifiedDate` par defaut).
/// Partage les memes lignes filtrees/triees que les autres vues
/// (`DatabaseViewModel.visibleRows`).
struct DatabaseCalendarView: View {
    @Bindable var viewModel: DatabaseViewModel

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if dateFields.count > 1 {
                fieldPicker
            }
            if let fieldID = viewModel.calendarFieldID {
                DatabaseCalendarNavigationBar(
                    title: monthTitle,
                    onPrevious: { shiftMonth(by: -1) },
                    onToday: { viewModel.calendarMonthAnchor = .now },
                    onNext: { shiftMonth(by: 1) }
                )
                DatabaseCalendarMonthGridView(weekdaySymbols: weekdaySymbols, days: days(for: fieldID))
            } else {
                DatabaseCalendarEmptyStateView()
            }
        }
        .padding(Spacing.lg)
        .background(SlateColor.bgEditor)
    }

    private var dateFields: [DatabaseFieldSnapshot] {
        viewModel.snapshot.fields.filter { $0.type == .date || $0.type == .createdDate || $0.type == .modifiedDate }
    }

    private var fieldPicker: some View {
        Picker(String(localized: "database.calendar.fieldPicker", bundle: .module), selection: Binding(
            get: { viewModel.calendarFieldID ?? dateFields.first?.id },
            set: { viewModel.calendarFieldID = $0 }
        )) {
            ForEach(dateFields) { field in
                Text(field.name).tag(Optional(field.id))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: viewModel.calendarMonthAnchor).capitalized
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        let firstWeekday = calendar.firstWeekday - 1
        guard !symbols.isEmpty else { return [] }
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
    }

    private func shiftMonth(by delta: Int) {
        let anchor = viewModel.calendarMonthAnchor
        guard let newDate = calendar.date(byAdding: .month, value: delta, to: anchor) else { return }
        viewModel.calendarMonthAnchor = newDate
    }

    private func days(for fieldID: UUID) -> [SlateDatabaseCalendarDay] {
        let anchor = viewModel.calendarMonthAnchor
        guard let monthInterval = calendar.dateInterval(of: .month, for: anchor) else { return [] }
        guard let firstWeekOfMonth = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        let today = Date.now

        let eventsByDay = eventTitlesByDay(fieldID: fieldID)

        var result: [SlateDatabaseCalendarDay] = []
        var cursor = firstWeekOfMonth.start
        for index in 0..<42 {
            let dayNumber = calendar.component(.day, from: cursor)
            let isInCurrentMonth = calendar.isDate(cursor, equalTo: anchor, toGranularity: .month)
            let key = dayKey(cursor)
            result.append(
                SlateDatabaseCalendarDay(
                    id: index,
                    dayNumber: dayNumber,
                    isInCurrentMonth: isInCurrentMonth,
                    isToday: calendar.isDate(cursor, inSameDayAs: today),
                    eventTitles: eventsByDay[key] ?? []
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func eventTitlesByDay(fieldID: UUID) -> [String: [String]] {
        var result: [String: [String]] = [:]
        let titleField = viewModel.snapshot.fields.first { $0.type == .text }
        for row in viewModel.visibleRows {
            let evaluated = viewModel.evaluatedValue(fieldID: fieldID, row: row)
            guard case .date(let date)? = evaluated else { continue }
            let title = titleField.flatMap { DatabaseCellFormatting.displayText(row.values[$0.id], field: $0) }
                ?? String(localized: "database.kanban.untitledCard", bundle: .module)
            result[dayKey(date), default: []].append(title)
        }
        return result
    }

    private func dayKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private struct DatabaseCalendarEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "calendar")
                .slateIconFont(28, relativeTo: .largeTitle)
                .foregroundStyle(SlateColor.textTertiary)
            Text(String(localized: "database.calendar.emptyState", bundle: .module))
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
    }
}
