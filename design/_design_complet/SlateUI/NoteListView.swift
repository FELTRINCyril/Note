//  NoteListView.swift — E3, colonne du milieu (300 pt).
//  Recherche + tri, groupes épinglés au scroll, états vides.

import SwiftUI

public enum SlateNoteSort: String, CaseIterable, Identifiable {
    case modified, created, title
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .modified: "Date de modification"
        case .created: "Date de création"
        case .title: "Titre"
        }
    }
    var systemImage: String {
        switch self {
        case .modified: "clock.arrow.circlepath"
        case .created: "calendar"
        case .title: "textformat.abc"
        }
    }
}

public struct NoteListView: View {
    let notes: [SlateNote]
    let folderName: String
    @Binding var selection: UUID?
    @State private var query = ""
    @State private var sort: SlateNoteSort = .modified
    @State private var ascending = false
    @FocusState private var searchFocused: Bool

    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.slateAccent) private var accent

    public init(notes: [SlateNote], folderName: String, selection: Binding<UUID?>) {
        self.notes = notes; self.folderName = folderName; self._selection = selection
    }

    private var windowIsKey: Bool { controlActiveState == .key || controlActiveState == .active }

    private var filtered: [SlateNote] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(q)
            || (!$0.isLocked && $0.snippet.localizedCaseInsensitiveContains(q))
        }
    }

    private var grouped: [(group: SlateDateGroup, notes: [SlateNote])] {
        let sorted = filtered.sorted { a, b in
            let asc = ascending
            switch sort {
            case .modified, .created: return asc ? a.date < b.date : a.date > b.date
            case .title: return asc
                ? a.title.localizedStandardCompare(b.title) == .orderedAscending
                : a.title.localizedStandardCompare(b.title) == .orderedDescending
            }
        }
        // En tri par titre, on aplatit : les groupes de date n'ont plus de sens.
        if sort == .title {
            let pinned = sorted.filter(\.isPinned), rest = sorted.filter { !$0.isPinned }
            return [(.pinned, pinned), (.today, rest)].filter { !$0.1.isEmpty }
        }
        var buckets: [SlateDateGroup: [SlateNote]] = [:]
        for n in sorted { buckets[SlateDateGroup.group(for: n), default: []].append(n) }
        let order: [SlateDateGroup] = [.pinned, .today, .yesterday, .last7Days, .last30Days]
        var out = order.compactMap { g in buckets[g].map { (g, $0) } }
        out += buckets.keys
            .filter { if case .month = $0 { true } else { false } }
            .sorted { lhs, rhs in
                guard case .month(let a, _) = lhs, case .month(let b, _) = rhs else { return false }
                return a > b
            }
            .map { ($0, buckets[$0]!) }
        out += buckets.keys
            .filter { if case .year = $0 { true } else { false } }
            .sorted { lhs, rhs in
                guard case .year(let a) = lhs, case .year(let b) = rhs else { return false }
                return a > b
            }
            .map { ($0, buckets[$0]!) }
        return out
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(SlateColors.separator)
            if notes.isEmpty {
                emptyFolder
            } else if filtered.isEmpty {
                noResults
            } else {
                list
            }
        }
        .background(SlateColors.bgList)
        .accessibilityLabel("Liste de notes, \(folderName)")
    }

    // MARK: Barre de recherche + tri

    private var header: some View {
        HStack(spacing: SlateSpace.s) {
            HStack(spacing: SlateSpace.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SlateColors.textTertiary)
                TextField("Rechercher", text: $query)
                    .textFieldStyle(.plain)
                    .slateFont(.label)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(SlateColors.textTertiary)
                        .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(.horizontal, SlateSpace.s)
            .frame(height: SlateMetrics.controlS)
            .background(SlateColors.surfaceSecondary,
                        in: RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous))
            .overlay {
                if searchFocused {
                    RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous)
                        .strokeBorder(accent.focusRing, lineWidth: SlateStroke.focusRingWidth)
                }
            }

            Menu {
                Picker("Trier par", selection: $sort) {
                    ForEach(SlateNoteSort.allCases) { s in
                        Label(s.label, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Toggle("Ordre croissant", isOn: $ascending)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .font(.system(size: SlateMetrics.iconS))
            .foregroundStyle(SlateColors.textSecondary)
            .help("Trier les notes")
            .accessibilityLabel("Trier les notes, actuellement \(sort.label)")
        }
        .padding(.horizontal, SlateSpace.m)
        .padding(.vertical, SlateSpace.s + SlateSpace.xxs)
    }

    // MARK: Liste

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(grouped, id: \.group.id) { section in
                    Section {
                        ForEach(section.notes) { note in
                            NoteCell(note: note,
                                     relativeDate: Self.relativeDate(note.date),
                                     selection: selection == note.id
                                        ? (windowIsKey ? .active : .inactive) : .none,
                                     onActivate: { selection = note.id })
                        }
                    } header: {
                        DateSectionHeader(section.group, count: section.notes.count)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    /// « Aujourd'hui · 14:22 », « lundi », « 12 mars 2025 » selon l'ancienneté.
    static func relativeDate(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let f = DateFormatter(); f.locale = .current
        if calendar.isDateInToday(date) { f.dateFormat = "HH:mm"; return f.string(from: date) }
        if calendar.isDateInYesterday(date) { f.dateFormat = "'Hier' HH:mm"; return f.string(from: date) }
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if days <= 7 { f.dateFormat = "EEEE"; return f.string(from: date).capitalized }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            f.setLocalizedDateFormatFromTemplate("d MMM"); return f.string(from: date)
        }
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy"); return f.string(from: date)
    }

    // MARK: États vides

    private var emptyFolder: some View {
        SlateEmptyState(systemImage: "note.text",
                        title: "Aucune note",
                        message: "« \(folderName) » est vide. Créez une première note pour commencer.",
                        actionTitle: "Nouvelle note",
                        action: {})
    }

    private var noResults: some View {
        SlateEmptyState(systemImage: "magnifyingglass",
                        title: "Aucun résultat",
                        message: "Aucune note ne correspond à « \(query) » dans « \(folderName) ».",
                        actionTitle: "Rechercher partout",
                        action: {})
    }
}

public struct SlateEmptyState: View {
    let systemImage: String, title: String, message: String
    var actionTitle: String?
    var action: (() -> Void)?

    public init(systemImage: String, title: String, message: String,
                actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage; self.title = title; self.message = message
        self.actionTitle = actionTitle; self.action = action
    }

    public var body: some View {
        VStack(spacing: SlateSpace.m) {
            Image(systemName: systemImage)
                .font(.system(size: SlateMetrics.controlL, weight: .light))
                .foregroundStyle(SlateColors.textTertiary)
            VStack(spacing: SlateSpace.xs) {
                Text(title)
                    .slateFont(.subtitle)
                    .foregroundStyle(SlateColors.textSecondary)
                Text(message)
                    .slateFont(.caption)
                    .foregroundStyle(SlateColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .slateFont(.label)
            }
        }
        .padding(.horizontal, SlateSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
