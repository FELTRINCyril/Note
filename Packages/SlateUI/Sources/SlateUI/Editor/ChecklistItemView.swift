import SwiftUI

/// Item de liste a cocher (design/tokens.md §16, artboard G). Composant de
/// PRESENTATION pur : `isDone` est un `Binding` fourni par l'appelant (`SlateEditor`),
/// qui reste seul a connaitre le modele reel derriere la case.
public struct ChecklistItemView<Content: View>: View {
    @Binding private var isDone: Bool
    private let level: Int
    private let content: Content

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isDone: Binding<Bool>, level: Int = 0, @ViewBuilder content: () -> Content) {
        self._isDone = isDone
        self.level = level
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            checkbox
            content
                .slateFont(SlateFont.body)
                .strikethrough(isDone) // la barre porte l'etat, pas seulement la couleur
                .foregroundStyle(isDone ? SlateColor.todoTextDone : SlateColor.textPrimary)
        }
        .padding(.leading, CGFloat(level) * SlateGeometry.editorListIndentStep)
        .padding(.vertical, SlateGeometry.editorBlockSpacing / 2)
    }

    private var checkbox: some View {
        Button {
            isDone.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5, style: .continuous)
                    .fill(isDone ? SlateColor.accentDefault : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5, style: .continuous)
                            .strokeBorder(
                                isDone ? .clear : SlateColor.todoCheckboxBorder,
                                lineWidth: SlateGeometry.strokeHairline * 1.5
                            )
                    )
                Image(systemName: "checkmark")
                    .slateIconFont(11, weight: .heavy, relativeTo: .body)
                    .foregroundStyle(SlateColor.textOnAccent)
                    .opacity(isDone ? 1 : 0)
            }
            .frame(width: SlateGeometry.checklistCheckboxSize, height: SlateGeometry.checklistCheckboxSize)
            .overlay(focusRing)
            .frame(width: SlateGeometry.checklistCheckboxHitSize, height: SlateGeometry.checklistCheckboxHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityLabel(SlateUIStrings.checklistLabel)
        .accessibilityValue(isDone ? SlateUIStrings.checklistDone : SlateUIStrings.checklistTodo)
    }

    /// Meme geometrie de contour que `BlockContainer.focusRing` (anneau, jamais un
    /// aplat) : le focus clavier de la case reste distinguable de l'etat coche.
    @ViewBuilder private var focusRing: some View {
        if isFocused {
            ZStack {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5)
                    .strokeBorder(SlateColor.focusRing, lineWidth: SlateGeometry.focusRingWidth)
                    .padding(-SlateGeometry.focusRingOffset)
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5)
                    .strokeBorder(SlateColor.accentDefault, lineWidth: SlateGeometry.strokeHairline)
            }
        }
    }
}

#Preview("ChecklistItemView - etats, clair") {
    ChecklistGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("ChecklistItemView - etats, sombre") {
    ChecklistGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct ChecklistGalleryPreview: View {
    @State private var done = true
    @State private var notDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChecklistItemView(isDone: $done) { Text("Tache faite - barree et attenuee") }
            ChecklistItemView(isDone: $notDone) { Text("Tache a faire") }
            ChecklistItemView(isDone: $notDone, level: 1) { Text("Sous-tache imbriquee") }
        }
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}
