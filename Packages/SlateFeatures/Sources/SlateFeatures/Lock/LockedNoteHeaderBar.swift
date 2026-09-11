import SwiftUI
import SlateModel
import SlateUI

/// Barre de titre d'une note verrouillee (design P3, artboard C : "Le titre reste
/// visible : c'est un choix explicite"). Volontairement NON editable ici (contrairement
/// au titre d'une note deverrouillee, `NoteHeaderView` dans `SlateEditor`) : le contexte
/// est un ecran de verrou, pas l'editeur.
struct LockedNoteHeaderBar: View {
    let title: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "lock")
                .slateIconFont(SlateGeometry.noteCellIndicatorIconSize, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.textSecondary)
            Text(title)
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: SlateGeometry.sidebarFooterHeight + Spacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SlateColor.separator)
                .frame(height: SlateGeometry.strokeHairline)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("LockedNoteHeaderBar - clair") {
    LockedNoteHeaderBar(title: "Comptes bancaires")
        .background(SlateColor.bgEditor)
}

#Preview("LockedNoteHeaderBar - sombre") {
    LockedNoteHeaderBar(title: "Comptes bancaires")
        .background(SlateColor.bgEditor)
        .preferredColorScheme(.dark)
}
