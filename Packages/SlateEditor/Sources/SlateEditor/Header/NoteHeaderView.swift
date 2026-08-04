import SlateModel
import SlateUI
import SwiftUI

/// En-tete d'une note (spec E4) : couverture optionnelle (200 pt pleine largeur),
/// icone optionnelle (64 pt, chevauchant la couverture de 32 pt quand les deux sont
/// presents), titre EDITABLE (le seul champ editable de la 5.1, voir
/// `docs/05_editeur_blocs.md`), et ligne de metadonnees.
///
/// ## Sous-titre : absent du modele, delibere (pas un oubli)
/// La maquette E4 montre un champ "sous-titre" ("Ajouter un sous-titre") sous le titre.
/// `SlateModel.Note` n'a PAS de propriete sous-titre : ce n'est pas cette phase qui
/// decide d'en ajouter une (une evolution du modele releve de `data-modeler`, avec
/// migration de schema associee). Cette vue rend donc l'en-tete SANS sous-titre,
/// deliberement, et le signale au lieu d'improviser un substitut (ex. detourner un
/// champ existant). Voir le rapport de livraison de la Phase 5.1.
struct NoteHeaderView: View {
    let note: Note
    let metadataLine: String
    let strings: NoteEditorStrings
    let onAddIcon: () -> Void
    let onAddCover: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverImageData = note.coverImageData {
                NoteCoverView(imageData: coverImageData, accessibilityLabel: strings.noteCoverAccessibilityLabel)
            }

            EditorContentColumn {
                VStack(alignment: .leading, spacing: 0) {
                    if let iconName = note.iconName {
                        NoteIconView(iconName: iconName, accessibilityLabel: strings.noteIconAccessibilityLabel)
                            .padding(.leading, SlateGeometry.editorGutter)
                            .padding(.top, note.coverImageData == nil ? Spacing.sm : -SlateGeometry.editorIconOverlap)
                            .padding(.bottom, Spacing.sm)
                    }

                    headerActions
                        .padding(.leading, SlateGeometry.editorGutter)
                        .padding(.bottom, Spacing.sm)

                    titleField
                        .padding(.leading, SlateGeometry.editorGutter)

                    Text(metadataLine)
                        .slateFont(SlateFont.caption)
                        .foregroundStyle(SlateColor.textTertiary)
                        .padding(.top, Spacing.md)
                        .padding(.leading, SlateGeometry.editorGutter)
                }
                .padding(.top, note.coverImageData == nil ? SlateGeometry.editorContentTopPadding : 0)
                .padding(.bottom, SlateGeometry.editorHeaderToBodySpacing)
            }
        }
        .onHover { hovering in
            let animation = SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion)
            withAnimation(animation) {
                isHoveringHeader = hovering
            }
        }
    }

    private var titleField: some View {
        TextField(strings.untitledPlaceholder, text: titleBinding)
            .textFieldStyle(.plain)
            .slateFont(SlateFont.titleNote)
            .foregroundStyle(SlateColor.textPrimary)
    }

    private var titleBinding: Binding<String> {
        Binding(get: { note.title }, set: { note.title = $0 })
    }

    @ViewBuilder private var headerActions: some View {
        HStack(spacing: Spacing.md) {
            if note.iconName == nil {
                headerAction(
                    symbol: "face.smiling",
                    label: strings.addIconLabel,
                    help: strings.addIconAccessibilityLabel,
                    action: onAddIcon
                )
            }
            if note.coverImageData == nil {
                headerAction(
                    symbol: "photo",
                    label: strings.addCoverLabel,
                    help: strings.addCoverAccessibilityLabel,
                    action: onAddCover
                )
            }
        }
        .opacity(isHoveringHeader ? 1 : 0)
        .allowsHitTesting(isHoveringHeader)
        .accessibilityHidden(!isHoveringHeader)
    }

    private func headerAction(symbol: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .slateIconFont(SlateGeometry.sidebarIconSize, relativeTo: .callout)
                Text(label)
                    .slateFont(SlateFont.label)
            }
            .foregroundStyle(SlateColor.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
    }
}

#Preview("NoteHeaderView - clair, sans couverture ni icone") {
    NoteHeaderView(
        note: Note(title: "Feuille de route Q3"),
        metadataLine: "Modifiee aujourd'hui a 14:22 - 428 mots",
        strings: NoteEditorStrings(),
        onAddIcon: {},
        onAddCover: {}
    )
    .frame(width: 900)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("NoteHeaderView - sombre, avec icone") {
    let note = Note(title: "Architecture de l'editeur", iconName: "puzzlepiece.extension")
    return NoteHeaderView(
        note: note,
        metadataLine: "Modifiee lundi a 09:12 - 1204 mots",
        strings: NoteEditorStrings(),
        onAddIcon: {},
        onAddCover: {}
    )
    .frame(width: 900)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}
