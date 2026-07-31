import SwiftUI
import SlateModel
import SlateUI

/// Selection d'icone d'un dossier ("changer d'icone" du menu contextuel/`...`).
///
/// `Folder.iconName` est un simple nom de SF Symbol : cette feuille propose une liste
/// courte et curatee plutot qu'un catalogue exhaustif, pour rester sobre (menu de
/// Phase 3, pas un editeur d'icones complet).
struct FolderIconPickerSheet: View {
    let folder: Folder
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private static let curatedIcons = [
        "folder", "folder.fill", "tray", "archivebox", "briefcase",
        "book.closed", "tag", "star", "bookmark", "house", "graduationcap", "cart"
    ]

    private let columns = [GridItem(.adaptive(minimum: SlateGeometry.pickerHitTarget), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "sidebar.folder.iconPicker.title", bundle: .module))
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(Self.curatedIcons, id: \.self) { icon in
                    Button {
                        onSelect(icon)
                        dismiss()
                    } label: {
                        let isCurrentIcon = icon == folder.iconName
                        Image(systemName: icon)
                            .slateIconFont(SlateGeometry.pickerGlyphSize, relativeTo: .body)
                            .frame(width: SlateGeometry.pickerHitTarget, height: SlateGeometry.pickerHitTarget)
                            .background(
                                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium, style: .continuous)
                                    .fill(isCurrentIcon ? SlateColor.accentSubtle : SlateColor.surfaceSecondary)
                            )
                            .foregroundStyle(isCurrentIcon ? SlateColor.accentDefault : SlateColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon)
                    .accessibilityAddTraits(icon == folder.iconName ? .isSelected : [])
                }
            }
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", bundle: .module)) {
                    dismiss()
                }
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 320)
    }
}
