import AppKit
import SwiftUI

// Chrome de la vue Grille au-dela des cellules : en-tete de colonne, poignee de
// redimensionnement, poignee/indicateur de reordonnancement, barre de calculs, ligne
// d'ajout (design/tokens.md §18, artboard A).

// MARK: - En-tete de colonne

/// En-tete de colonne complet : icone de type + titre + chevron de tri optionnel +
/// glyphe de menu, sur `TableHeaderCell` (Phase 8) -- REUTILISE tel quel comme
/// enveloppe (fond/bordure/police), pas redefini ici.
public struct DatabaseColumnHeaderCell: View {
    private let title: String
    private let systemImage: String
    private let sortDirection: SlateDatabaseSortDirection?
    private let showsMenuGlyph: Bool
    private let showsTrailingBorder: Bool
    private let onTap: () -> Void

    public init(
        title: String,
        systemImage: String,
        sortDirection: SlateDatabaseSortDirection? = nil,
        showsMenuGlyph: Bool = false,
        showsTrailingBorder: Bool = true,
        onTap: @escaping () -> Void = {}
    ) {
        self.title = title
        self.systemImage = systemImage
        self.sortDirection = sortDirection
        self.showsMenuGlyph = showsMenuGlyph
        self.showsTrailingBorder = showsTrailingBorder
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            TableHeaderCell(showsTrailingBorder: showsTrailingBorder) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: systemImage)
                        .slateIconFont(SlateGeometry.searchFieldIconSize, relativeTo: .subheadline)
                        .foregroundStyle(SlateColor.textSecondary)
                    Text(title)
                    Spacer(minLength: Spacing.xs)
                    if let sortDirection {
                        Image(systemName: sortDirection == .ascending ? "chevron.up" : "chevron.down")
                            .slateIconFont(9, weight: .bold, relativeTo: .caption2)
                            .foregroundStyle(SlateColor.textSecondary)
                    }
                    if showsMenuGlyph {
                        Image(systemName: "chevron.down")
                            .slateIconFont(9, weight: .bold, relativeTo: .caption2)
                            .foregroundStyle(SlateColor.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Sens de tri applique a une colonne (chevron d'en-tete + menu de tris, artboard D).
public enum SlateDatabaseSortDirection: String, Sendable, Equatable {
    case ascending
    case descending
}

/// Poignee de redimensionnement d'une colonne de grille : invisible au repos, 4 pt en
/// `accent.default` au survol/saisie -- meme comportement que le redimensionneur de
/// colonnes de l'editeur (Phase 10, `ColumnsBlockView.ColumnResizer`, prive), reproduit
/// ici pour un `Binding<CGFloat>` de LARGEUR directe (pas des fractions).
public struct DatabaseColumnResizeHandle: View {
    @Binding private var width: CGFloat
    private let minWidth: CGFloat

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(width: Binding<CGFloat>, minWidth: CGFloat = SlateGeometry.databaseColumnMinWidth) {
        self._width = width
        self.minWidth = minWidth
    }

    private var isActive: Bool { isHovering || isDragging }

    public var body: some View {
        RoundedRectangle(cornerRadius: SlateGeometry.databaseColumnResizerWidth / 2)
            .fill(isActive ? SlateColor.accentDefault : Color.clear)
            .frame(width: isActive ? SlateGeometry.databaseColumnResizerWidth : SlateGeometry.strokeHairline)
            .frame(width: Spacing.sm)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                let animation = SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion)
                withAnimation(animation) { isHovering = hovering }
                if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        let start = dragStartWidth ?? width
                        dragStartWidth = start
                        width = max(minWidth, start + value.translation.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragStartWidth = nil
                    }
            )
            .accessibilityLabel(SlateUIStrings.databaseColumnResizeLabel)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: width = max(minWidth, width + Spacing.sm)
                case .decrement: width = max(minWidth, width - Spacing.sm)
                @unknown default: break
                }
            }
    }
}

/// Indicateur de reordonnancement de colonne : ligne verticale pleine hauteur affichee
/// sur la colonne cible pendant un glisser d'en-tete. Reutilise `blockDropIndicator`
/// (Phase 5/10) tel quel, meme langage visuel que le depot de bloc lateral.
public struct DatabaseColumnDropIndicator: View {
    public init() {}

    public var body: some View {
        Capsule(style: .continuous)
            .fill(SlateColor.blockDropIndicator)
            .frame(width: SlateGeometry.databaseColumnResizerWidth)
            .accessibilityHidden(true)
    }
}

public extension View {
    /// Rend une colonne d'en-tete GLISSABLE pour son reordonnancement (drag & drop de
    /// l'en-tete entier, meme idiome que `BlockHandle.draggable` sur la poignee de
    /// bloc). `columnID` est un identifiant opaque : `SlateUI` ne connait pas le modele
    /// de colonne reel.
    func databaseColumnDraggable(columnID: String) -> some View {
        draggable(columnID)
            .accessibilityLabel(SlateUIStrings.databaseColumnReorderLabel)
    }
}

// MARK: - Barre de calculs

/// Type d'agregat affichable en pied de colonne (artboard A : "Somme, Moyenne, Min,
/// Max, Vides, Remplies, Pourcentage rempli").
public enum SlateDatabaseColumnCalculation: String, Sendable, Equatable, CaseIterable, Identifiable {
    case none
    case count
    case sum
    case average
    case min
    case max
    case empty
    case filled
    case percentFilled

    public var id: String { rawValue }

    public var displayName: String { SlateUIStrings.databaseCalculationDisplayName(self) }
}

/// Cellule de la barre de calculs (artboard A : "au repos, `Calcul...` en
/// `text.tertiary`, discret mais cliquable"). `resultText` est `nil` tant qu'aucun
/// calcul n'est choisi -- l'appelant fournit deja le resultat formatte
/// (ex: "Moyenne : 54 %"), ce composant ne calcule rien.
public struct DatabaseCalculationCell: View {
    private let resultText: String?
    private let isEmphasized: Bool
    private let showsTrailingBorder: Bool
    private let onTap: () -> Void

    public init(
        resultText: String?,
        isEmphasized: Bool = false,
        showsTrailingBorder: Bool = true,
        onTap: @escaping () -> Void = {}
    ) {
        self.resultText = resultText
        self.isEmphasized = isEmphasized
        self.showsTrailingBorder = showsTrailingBorder
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Text(resultText ?? SlateUIStrings.databaseCalculationPlaceholder)
                .slateFont(isEmphasized ? SlateFont.bodyEmphasis : SlateFont.caption)
                .foregroundStyle(resultText == nil ? SlateColor.textTertiary : SlateColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
        .background(SlateColor.databaseGridHeaderBackground)
        .overlay(alignment: .trailing) {
            if showsTrailingBorder {
                Rectangle().fill(SlateColor.databaseGridCellBorder).frame(width: SlateGeometry.strokeHairline)
            }
        }
    }
}

// MARK: - Ligne d'ajout

/// Ligne "+ Nouvelle fiche" en pied de grille/Kanban (artboard A/B). `title` est fourni
/// par l'appelant (peut devenir un menu si plusieurs templates existent, artboard D).
public struct DatabaseAddRowButton: View {
    private let title: String
    private let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus")
                    .slateIconFont(12, weight: .semibold, relativeTo: .callout)
                Text(title)
            }
            .slateFont(SlateFont.label)
            .foregroundStyle(SlateColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

#Preview("DatabaseGridChrome - clair") {
    DatabaseGridChromePreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseGridChrome - sombre") {
    DatabaseGridChromePreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseGridChromePreview: View {
    @State private var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                DatabaseColumnHeaderCell(title: "Chantier", systemImage: "text.alignleft")
                DatabaseColumnHeaderCell(
                    title: "Statut",
                    systemImage: "circle",
                    sortDirection: .ascending,
                    showsMenuGlyph: true
                )
                .frame(width: width)
                DatabaseColumnResizeHandle(width: $width)
            }
            DatabaseAddRowButton(title: "Nouvelle fiche") {}
            HStack(spacing: 0) {
                DatabaseCalculationCell(resultText: "6 fiches", showsTrailingBorder: true) {}
                DatabaseCalculationCell(resultText: "Moyenne : 54 %", isEmphasized: true) {}
                DatabaseCalculationCell(resultText: nil, showsTrailingBorder: false) {}
            }
        }
        .frame(width: 520)
        .background(SlateColor.bgEditor)
    }
}
