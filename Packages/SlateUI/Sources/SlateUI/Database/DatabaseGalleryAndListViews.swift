import SwiftUI

/// Vues Galerie et Liste (design/tokens.md §18, artboard C). Composants de
/// PRESENTATION purs.

/// Taille de vignette de galerie (artboard C : "S 96 / M 160 / L 240 pt").
public enum SlateDatabaseGalleryThumbnailSize: String, Sendable, Equatable, CaseIterable {
    case small
    case medium
    case large

    public var height: CGFloat {
        switch self {
        case .small: SlateGeometry.databaseGalleryThumbnailSmall
        case .medium: SlateGeometry.databaseGalleryThumbnailMedium
        case .large: SlateGeometry.databaseGalleryThumbnailLarge
        }
    }
}

/// Carte de galerie : vignette (fournie par l'appelant, ou cadre neutre "Sans apercu"
/// si `thumbnail` est `nil` -- artboard C : "jamais la premiere image du corps, trop
/// imprevisible") + titre + statut + metadonnee.
public struct DatabaseGalleryCardView<Thumbnail: View>: View {
    private let title: String
    private let pill: (title: String, style: SlateDatabasePillStyle)?
    private let metaText: String?
    private let thumbnailSize: SlateDatabaseGalleryThumbnailSize
    private let thumbnail: Thumbnail?

    public init(
        title: String,
        pill: (title: String, style: SlateDatabasePillStyle)? = nil,
        metaText: String? = nil,
        thumbnailSize: SlateDatabaseGalleryThumbnailSize = .small,
        @ViewBuilder thumbnail: () -> Thumbnail
    ) {
        self.title = title
        self.pill = pill
        self.metaText = metaText
        self.thumbnailSize = thumbnailSize
        self.thumbnail = thumbnail()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                SlateColor.databaseGridHeaderBackground
                if let thumbnail {
                    thumbnail
                } else {
                    Image(systemName: "photo")
                        .slateIconFont(22, weight: .regular, relativeTo: .largeTitle)
                        .foregroundStyle(SlateColor.textTertiary)
                }
            }
            .frame(height: thumbnailSize.height)
            .clipped()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .slateFont(SlateFont.bodyEmphasis)
                    .foregroundStyle(SlateColor.textPrimary)
                    .lineLimit(1)
                if let pill {
                    DatabasePillView(pill.title, style: pill.style, isCompact: true)
                }
                Text(metaText ?? SlateUIStrings.databaseGalleryNoPreview)
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(metaText == nil ? SlateColor.textTertiary : SlateColor.textSecondary)
            }
            .padding(Spacing.sm)
        }
        .background(SlateColor.databaseCardBackground)
        .overlay(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium).strokeBorder(SlateColor.borderDefault))
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium))
        .accessibilityElement(children: .combine)
    }
}

/// Ligne compacte de la vue Liste (34 pt, artboard C). Distincte de `ListCell` (64 pt,
/// liste de notes) : densite volontairement differente, voir la doc de tete du fichier
/// `Slate P5 - Bases de donnees.dc.html` artboard C.
public struct DatabaseListRowView: View {
    private let title: String
    private let pill: (title: String, style: SlateDatabasePillStyle)?
    private let trailingText: String?
    private let isHovered: Bool

    public init(
        title: String,
        pill: (title: String, style: SlateDatabasePillStyle)? = nil,
        trailingText: String? = nil,
        isHovered: Bool = false
    ) {
        self.title = title
        self.pill = pill
        self.trailingText = trailingText
        self.isHovered = isHovered
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.xs)
            if let pill {
                DatabasePillView(pill.title, style: pill.style, isCompact: true)
            }
            if let trailingText {
                Text(trailingText)
                    .slateFont(SlateTextStyle(size: 13, relativeTo: .footnote, tabularNums: true))
                    .foregroundStyle(SlateColor.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.leading, SlateGeometry.databaseListRowIndent)
        .padding(.trailing, Spacing.md)
        .frame(height: SlateGeometry.databaseListRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? SlateColor.stateHover : Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview("DatabaseGalleryAndListViews - clair") {
    DatabaseGalleryListGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseGalleryAndListViews - sombre") {
    DatabaseGalleryListGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseGalleryListGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                DatabaseGalleryCardView(
                    title: "Editeur de blocs",
                    pill: ("En cours", SlateDatabasePillStyle(accent: .blue, bullet: .square)),
                    metaText: "Camille - 12 sept."
                ) { EmptyView() }
                DatabaseGalleryCardView(
                    title: "Assistant IA",
                    pill: ("A faire", SlateDatabasePillStyle(accent: nil, bullet: .hollowCircle))
                ) { EmptyView() }
            }
            .frame(width: 420)

            VStack(spacing: 0) {
                ListSectionHeader("Camille", count: 2)
                DatabaseListRowView(
                    title: "Editeur de blocs",
                    pill: ("En cours", SlateDatabasePillStyle(accent: .blue, bullet: .square)),
                    trailingText: "12 sept."
                )
                DatabaseListRowView(
                    title: "Verrouillage de notes",
                    pill: ("Livre", SlateDatabasePillStyle(accent: .green, bullet: .check)),
                    trailingText: "28 aout",
                    isHovered: true
                )
            }
            .frame(width: 400)
            .background(SlateColor.bgList)
        }
        .padding(Spacing.lg)
        .background(SlateColor.bgEditor)
    }
}
