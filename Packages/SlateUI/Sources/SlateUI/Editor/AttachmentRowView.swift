import SwiftUI

/// Ligne de piece jointe, artboard B de `Slate P2 - Medias & pieces jointes.dc.html`
/// (Phase 9). "Un seul fichier par bloc -- pas de grille de vignettes, qui rendrait la
/// selection de bloc ambigue" : cette vue affiche toujours EXACTEMENT un fichier.
///
/// Couvre les 3 etats de l'artboard :
/// - normal (survol -> Apercu / Telecharger / menu) ;
/// - `.failedImport` (glyphe + ligne de cause en `attachmentErrorCauseText`, jamais le
///   libelle du fichier -- "le rouge n'apparait que sur le glyphe et sur la ligne de
///   cause", artboard B) ;
/// - `.missing` (bordure tiretee, action "Localiser").
///
/// Dynamic Type (artboard D) : a partir de `.accessibility1`, la ligne passe de 52 pt a
/// hauteur libre et les actions descendent SOUS les metadonnees, plutot que de rester
/// hover-only (le survol n'est pas fiable au clavier/VoiceOver).
public struct AttachmentRowView<MenuItems: View>: View {
    public enum Status: Equatable {
        case normal
        case failedImport(cause: String)
        case missing(reason: String)
    }

    private let fileType: SlateAttachmentFileType
    private let fileName: String
    private let metadata: String
    private let status: Status
    /// Glyphe SF Symbol affiche dans la pastille pour `.generic` (audio, archive...).
    /// `SlateUI` ne connait pas les types de fichiers metier : c'est a l'appelant de
    /// choisir le symbole. Ignore pour `.pdf`/`.spreadsheet`, qui affichent un monogramme.
    private let genericSymbol: String
    private let onPreview: () -> Void
    private let onDownload: () -> Void
    private let onRetry: () -> Void
    private let onLocate: () -> Void
    @ViewBuilder private let menuItems: () -> MenuItems

    @State private var isHovering = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        fileType: SlateAttachmentFileType,
        fileName: String,
        metadata: String,
        status: Status = .normal,
        genericSymbol: String = "doc",
        onPreview: @escaping () -> Void = {},
        onDownload: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onLocate: @escaping () -> Void = {},
        @ViewBuilder menuItems: @escaping () -> MenuItems
    ) {
        self.fileType = fileType
        self.fileName = fileName
        self.metadata = metadata
        self.status = status
        self.genericSymbol = genericSymbol
        self.onPreview = onPreview
        self.onDownload = onDownload
        self.onRetry = onRetry
        self.onLocate = onLocate
        self.menuItems = menuItems
    }

    private var isAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    public var body: some View {
        Group {
            if isAccessibilityLayout {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    primaryRow
                    trailingContent
                }
            } else {
                HStack(spacing: Spacing.md) {
                    primaryRow
                    Spacer(minLength: Spacing.sm)
                    trailingContent
                }
                .frame(height: SlateGeometry.attachmentHeight)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, isAccessibilityLayout ? Spacing.sm : 0)
        .background(rowBackground)
        .overlay(rowBorder)
        .onHover { isHovering = $0 }
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: isHovering
        )
        .accessibilityElement(children: .contain)
    }

    private var primaryRow: some View {
        HStack(spacing: Spacing.md) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(fileName)
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                causeOrMetadataText
            }
        }
    }

    @ViewBuilder
    private var causeOrMetadataText: some View {
        switch status {
        case .normal:
            Text(metadata)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
        case let .failedImport(cause):
            // Le rouge ne porte QUE cette ligne, jamais le nom du fichier (artboard B).
            Text(cause)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.attachmentErrorCauseText)
        case let .missing(reason):
            Text(reason)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.attachmentMissingCauseText)
        }
    }

    @ViewBuilder
    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SlateGeometry.attachmentIconRadius)
                .fill(iconBackground)
            iconContent
        }
        .frame(width: SlateGeometry.attachmentIconSize, height: SlateGeometry.attachmentIconSize)
    }

    private var iconBackground: Color {
        switch status {
        case .normal: fileType.backgroundColor
        case .failedImport: SlateColor.attachmentErrorIconBackground
        case .missing: SlateColor.attachmentIconBackgroundFallback
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch status {
        case .normal:
            if let monogram = fileType.monogram {
                Text(monogram)
                    .slateFont(SlateTextStyle(size: 10, weight: .bold, relativeTo: .caption2, tracking: 0.3))
                    .foregroundStyle(fileType.labelColor)
            } else {
                Image(systemName: genericSymbol)
                    .slateIconFont(16, weight: .regular)
                    .foregroundStyle(fileType.labelColor)
            }
        case .failedImport:
            Image(systemName: "exclamationmark.triangle")
                .slateIconFont(16, weight: .regular)
                .foregroundStyle(SlateColor.attachmentErrorIconGlyph)
        case .missing:
            Image(systemName: "questionmark.circle")
                .slateIconFont(16, weight: .regular)
                .foregroundStyle(SlateColor.attachmentIconGlyphFallback)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch status {
        case .normal:
            hoverActions
        case .failedImport:
            Button("Reessayer", action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .missing:
            Button("Localiser", action: onLocate)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    /// Actions revelees au survol (artboard B : "Actions au survol : Apercu (barre
    /// d'espace), Telecharger, menu"). En Dynamic Type accessibilite, le survol n'etant
    /// pas fiable au clavier/VoiceOver, elles restent AFFICHEES en permanence sous les
    /// metadonnees plutot que masquees (artboard D).
    private var hoverActions: some View {
        HStack(spacing: 2) {
            actionButton(systemName: "magnifyingglass", label: "Apercu", action: onPreview)
            actionButton(systemName: "arrow.down.circle", label: "Telecharger", action: onDownload)
            Menu {
                menuItems()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .slateIconFont(SlateGeometry.attachmentActionIconSize, weight: .regular)
                    .foregroundStyle(SlateColor.textSecondary)
                    .frame(
                        width: SlateGeometry.attachmentActionButtonSize,
                        height: SlateGeometry.attachmentActionButtonSize
                    )
            }
            .menuStyle(.borderlessButton)
            .frame(width: SlateGeometry.attachmentActionButtonSize, height: SlateGeometry.attachmentActionButtonSize)
            .accessibilityLabel("Options du fichier")
        }
        .opacity(isAccessibilityLayout || isHovering ? 1 : 0)
        .allowsHitTesting(isAccessibilityLayout || isHovering)
        .accessibilityHidden(!isAccessibilityLayout && !isHovering)
    }

    private func actionButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .slateIconFont(SlateGeometry.attachmentActionIconSize, weight: .regular)
                .foregroundStyle(SlateColor.textSecondary)
                .frame(
                    width: SlateGeometry.attachmentActionButtonSize,
                    height: SlateGeometry.attachmentActionButtonSize
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
            .fill(isHovering && status == .normal ? SlateColor.stateHover : Color.clear)
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
            .strokeBorder(
                borderColor,
                style: StrokeStyle(lineWidth: SlateGeometry.strokeHairline, dash: isMissing ? [5, 3] : [])
            )
    }

    private var isMissing: Bool {
        if case .missing = status { return true }
        return false
    }

    private var borderColor: Color {
        isMissing ? SlateColor.attachmentMissingBorder : SlateColor.borderDefault
    }
}

public extension AttachmentRowView where MenuItems == EmptyView {
    /// Confort pour les appelants sans menu contextuel (ex: previews, etats d'echec/
    /// manquant, qui n'exposent pas de menu). Pas de valeur par defaut sur `menuItems`
    /// dans l'initialiseur generique ci-dessus : combinee a un `@ViewBuilder` generique,
    /// elle produit un avertissement du compilateur ("cannot use default expression for
    /// inference"), promis erreur dans un futur mode de langage Swift.
    init(
        fileType: SlateAttachmentFileType,
        fileName: String,
        metadata: String,
        status: Status = .normal,
        genericSymbol: String = "doc",
        onPreview: @escaping () -> Void = {},
        onDownload: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onLocate: @escaping () -> Void = {}
    ) {
        self.init(
            fileType: fileType,
            fileName: fileName,
            metadata: metadata,
            status: status,
            genericSymbol: genericSymbol,
            onPreview: onPreview,
            onDownload: onDownload,
            onRetry: onRetry,
            onLocate: onLocate
        ) {
            EmptyView()
        }
    }
}

#Preview("AttachmentRowView - catalogue d'etats, clair") {
    AttachmentRowStatesPreview()
        .frame(width: 500)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("AttachmentRowView - catalogue d'etats, sombre") {
    AttachmentRowStatesPreview()
        .frame(width: 500)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}

#Preview("AttachmentRowView - Dynamic Type accessibilite") {
    AttachmentRowStatesPreview()
        .frame(width: 380)
        .background(SlateColor.bgEditor)
        .environment(\.dynamicTypeSize, .accessibility2)
}

private struct AttachmentRowStatesPreview: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            AttachmentRowView(
                fileType: .pdf,
                fileName: "Specifications techniques v4.pdf",
                metadata: "PDF \u{b7} 2,4 Mo \u{b7} 12 pages"
            ) {
                Group {
                    Button("Renommer") {}
                    Button("Revele dans le Finder") {}
                    Button("Supprimer le bloc") {}
                }
            }

            AttachmentRowView(
                fileType: .spreadsheet,
                fileName: "Budget Q3.xlsx",
                metadata: "Tableur \u{b7} 148 Ko"
            )

            AttachmentRowView(
                fileType: .generic,
                fileName: "Reunion cadrage 12-08.m4a",
                metadata: "Audio \u{b7} 18,2 Mo \u{b7} 42:07",
                genericSymbol: "waveform"
            )

            AttachmentRowView(
                fileType: .generic,
                fileName: "montage-final.mov",
                metadata: "",
                status: .failedImport(cause: "Echec de l'import - fichier superieur a 2 Go")
            )

            AttachmentRowView(
                fileType: .pdf,
                fileName: "notes-terrain.pdf",
                metadata: "",
                status: .missing(reason: "Fichier introuvable - non synchronise depuis cet appareil")
            )
        }
        .padding()
    }
}
