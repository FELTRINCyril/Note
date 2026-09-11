import SwiftUI

/// Zone de depot d'un bloc image vide, artboard A de
/// `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9). Couvre les DEUX premiers etats
/// du parcours ("1 vide", "2 survol de depot") : le chargement et l'image affichee sont
/// d'autres vues (`MediaUploadProgressView`, `ImageFrameView`), `SlateEditor` bascule
/// entre les trois selon l'etat reel du bloc.
///
/// Vue pure : ne connait ni `SlateModel` ni le systeme de fichiers. `onChooseFile` est
/// invoque par le lien "choisissez sur le Mac" ; le glisser-deposer lui-meme (calcul de
/// `isTargeted`, decodage du contenu depose) reste a la charge de `SlateEditor`.
public struct MediaDropzoneView: View {
    private let isTargeted: Bool
    private let draggedFileName: String?
    private let onChooseFile: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        isTargeted: Bool,
        draggedFileName: String? = nil,
        onChooseFile: @escaping () -> Void = {}
    ) {
        self.isTargeted = isTargeted
        self.draggedFileName = draggedFileName
        self.onChooseFile = onChooseFile
    }

    public var body: some View {
        Group {
            if isTargeted {
                activeContent
            } else {
                idleContent
            }
        }
        .frame(height: SlateGeometry.mediaDropzoneHeight)
        .frame(maxWidth: .infinity)
        .background(background)
        .overlay(border)
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: isTargeted
        )
        .accessibilityElement(children: .combine)
    }

    /// Etat "1 vide" (artboard A) : icone + libelle + lien d'action, alignes a gauche.
    private var idleContent: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "photo.on.rectangle")
                .slateIconFont(20, weight: .regular)
                .foregroundStyle(SlateColor.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ajouter une image")
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
                HStack(spacing: Spacing.xs) {
                    Text("Glissez un fichier, collez, ou")
                        .slateFont(SlateFont.caption)
                        .foregroundStyle(SlateColor.textSecondary)
                    Button("choisissez sur le Mac", action: onChooseFile)
                        .buttonStyle(.plain)
                        .slateFont(SlateFont.caption)
                        .foregroundStyle(SlateColor.accentDefault)
                        .underline()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
    }

    /// Etat "2 survol de depot" (artboard A) : icone + libelle centres, teinte accent.
    private var activeContent: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.up.doc")
                .slateIconFont(20, weight: .semibold)
                .foregroundStyle(SlateColor.mediaDropzoneActiveLabel)
            Text(activeLabel)
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.mediaDropzoneActiveLabel)
        }
        .frame(maxWidth: .infinity)
    }

    private var activeLabel: String {
        if let draggedFileName {
            "Deposer \u{ab} \(draggedFileName) \u{bb}"
        } else {
            "Deposer le fichier ici"
        }
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
            .fill(isTargeted ? SlateColor.mediaDropzoneActiveBackground : SlateColor.mediaDropzoneBackground)
    }

    private var border: some View {
        let lineWidth = isTargeted
            ? SlateGeometry.mediaDropzoneActiveBorderWidth
            : SlateGeometry.mediaDropzoneBorderWidth
        return RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
            .strokeBorder(
                isTargeted ? SlateColor.mediaDropzoneActiveBorder : SlateColor.mediaDropzoneBorder,
                style: StrokeStyle(lineWidth: lineWidth, dash: [5, 3])
            )
    }
}

#Preview("MediaDropzoneView - repos, clair") {
    MediaDropzoneView(isTargeted: false)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("MediaDropzoneView - survol de depot, clair") {
    MediaDropzoneView(isTargeted: true, draggedFileName: "schema-blocs.png")
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("MediaDropzoneView - repos, sombre") {
    MediaDropzoneView(isTargeted: false)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

#Preview("MediaDropzoneView - survol de depot, sombre") {
    MediaDropzoneView(isTargeted: true, draggedFileName: "schema-blocs.png")
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}
