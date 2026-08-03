import SwiftUI

/// En-tete de section de liste generique (titre + compteur tabulaire optionnel), sans
/// aucune notion de date ni de note. `SlateFeatures` compose cette primitive pour
/// `DateSectionHeader` ("Aujourd'hui", "Hier"...) -- la spec E3 nomme `DateSectionHeader`
/// comme vivant dans `SlateUI`, ce qui est une erreur d'architecture au meme titre que
/// `NoteCell` (voir la doc de tete de `ListCell.swift`).
///
/// 13 pt Semibold `text.secondary` (spec E3 : "list.dateHeader.text 13 Semibold
/// text.secondary + compteur tabulaire"). Le compteur reutilise `SlateFont.sidebarCounter`
/// (12 pt, chiffres tabulaires) plutot qu'un nouveau token : meme role, meme rendu que le
/// compteur de sidebar.
///
/// `background` reste au choix de l'appelant (defaut transparent) : la spec exige un
/// "fond opaque au defilement" pour les en-tetes epingles (`pinnedViews: [.sectionHeaders]`)
/// et "en-tetes epingles sur aplat bg.list au lieu du fond floute" en Reduce Transparency
/// -- deux decisions qui dependent du contexte de defilement (liste de notes complete vs
/// section isolee) et donc de l'appelant, pas de cette primitive generique.
public struct ListSectionHeader: View {
    private let title: String
    private let count: Int?
    private let background: Color

    public init(_ title: String, count: Int? = nil, background: Color = .clear) {
        self.title = title
        self.count = count
        self.background = background
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
                .slateFont(SlateFont.listDateHeader)
                .foregroundStyle(SlateColor.textSecondary)
            if let count {
                Text(count, format: .number)
                    .slateFont(SlateFont.sidebarCounter)
                    .foregroundStyle(SlateColor.textSecondary)
            }
            Spacer(minLength: Spacing.xs)
        }
        .padding(.horizontal, SlateGeometry.noteCellPaddingHorizontal)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("ListSectionHeader") {
    VStack(alignment: .leading, spacing: 0) {
        ListSectionHeader("Epinglees", count: 2)
        ListSectionHeader("Aujourd'hui", count: 2)
        ListSectionHeader("7 jours precedents", count: 1)
        ListSectionHeader("2025", count: 12)
    }
    .background(SlateColor.bgList)
}

#Preview("ListSectionHeader - sombre") {
    VStack(alignment: .leading, spacing: 0) {
        ListSectionHeader("Epinglees", count: 2)
        ListSectionHeader("Aujourd'hui", count: 2)
    }
    .background(SlateColor.bgList)
    .preferredColorScheme(.dark)
}

#Preview("ListSectionHeader - epinglee au defilement, opaque") {
    ListSectionHeader("Aujourd'hui", count: 2, background: SlateColor.bgList)
        .background(SlateColor.bgList)
}
