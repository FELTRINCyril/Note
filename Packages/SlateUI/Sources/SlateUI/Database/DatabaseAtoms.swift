import SwiftUI

// Petits composants de PRESENTATION reutilises par plusieurs vues de base de donnees
// (design/tokens.md §18, `Slate P5 - Bases de donnees.dc.html`) : avatar de personne,
// barre de progression, case a cocher de cellule.

// MARK: - Avatar (champ "Personne")

/// Avatar circulaire d'initiales (champ Personne). `accent == nil` rend la variante
/// "Non attribue" (fond `surface.tertiary`, initiales `text.secondary`, artboard C : "?"
/// gris) -- pas une nouvelle paire de tokens, reutilisation directe des tokens de fond/
/// texte deja existants.
public struct DatabaseAvatarView: View {
    private let initials: String
    private let accent: SlateAccentColor?
    private let size: CGFloat

    public init(initials: String, accent: SlateAccentColor?, size: CGFloat = SlateGeometry.databaseAvatarSize) {
        self.initials = initials
        self.accent = accent
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(background)
            .overlay(
                Text(initials)
                    .slateFont(SlateTextStyle(size: size * 0.5, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(foreground)
            )
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(initials)
    }

    private var background: Color {
        guard let accent else { return SlateColor.surfaceTertiary }
        return slateAdaptiveColor(light: accent.lightRGB, dark: accent.darkRGB)
    }

    private var foreground: Color {
        guard let accent else { return SlateColor.textSecondary }
        return slateAdaptiveColor(light: accent.onAccentRGB(dark: false), dark: accent.onAccentRGB(dark: true))
    }
}

// MARK: - Barre de progression (champ Avancement)

/// Barre de progression d'une cellule "Avancement" : piste `separator`, remplissage
/// `accent.default`. `fraction` est deja bornee `0...1` par l'appelant.
public struct DatabaseProgressBarView: View {
    private let fraction: Double
    private let height: CGFloat

    public init(fraction: Double, height: CGFloat = SlateGeometry.databaseProgressBarHeight) {
        self.fraction = min(max(fraction, 0), 1)
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(SlateColor.separator)
                Capsule()
                    .fill(SlateColor.accentDefault)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: height)
    }
}

/// Cellule "Avancement" complete : barre + pourcentage tabulaire (artboard A).
public struct DatabaseProgressCellView: View {
    private let fraction: Double
    private let percentText: String

    public init(fraction: Double, percentText: String) {
        self.fraction = fraction
        self.percentText = percentText
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            DatabaseProgressBarView(fraction: fraction)
            Text(percentText)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textPrimary)
        }
    }
}

// MARK: - Case a cocher de cellule

/// Case a cocher d'une cellule de grille/liste (champ "Case a cocher"). Meme geometrie/
/// tokens que la case d'item de liste de l'editeur (`ChecklistItemView`,
/// `checklistCheckboxSize`/`checklistCheckboxHitSize`/`todoCheckboxBorder`) : le rendu
/// visuel doit rester identique partout dans Slate. `ChecklistItemView` ne l'expose pas
/// en sous-composant public (elle est toujours accolee a un texte de tache) -- ce type
/// reprend volontairement le meme dessin pour un usage sans texte attenant (cellule de
/// grille), voir le rapport de livraison pour ce doublon assume.
public struct DatabaseCheckboxToggle: View {
    @Binding private var isChecked: Bool

    public init(isChecked: Binding<Bool>) {
        self._isChecked = isChecked
    }

    public var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5, style: .continuous)
                    .fill(isChecked ? SlateColor.accentDefault : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall / 1.5, style: .continuous)
                            .strokeBorder(
                                isChecked ? .clear : SlateColor.todoCheckboxBorder,
                                lineWidth: SlateGeometry.strokeHairline * 1.5
                            )
                    )
                Image(systemName: "checkmark")
                    .slateIconFont(11, weight: .heavy, relativeTo: .body)
                    .foregroundStyle(SlateColor.textOnAccent)
                    .opacity(isChecked ? 1 : 0)
            }
            .frame(width: SlateGeometry.checklistCheckboxSize, height: SlateGeometry.checklistCheckboxSize)
            .frame(width: SlateGeometry.checklistCheckboxHitSize, height: SlateGeometry.checklistCheckboxHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SlateUIStrings.checklistLabel)
        .accessibilityValue(isChecked ? SlateUIStrings.checklistDone : SlateUIStrings.checklistTodo)
    }
}

#Preview("DatabaseAtoms - clair") {
    DatabaseAtomsGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseAtoms - sombre") {
    DatabaseAtomsGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseAtomsGalleryPreview: View {
    @State private var checked = true
    @State private var unchecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                DatabaseAvatarView(initials: "CM", accent: .purple)
                DatabaseAvatarView(initials: "NA", accent: .green)
                DatabaseAvatarView(initials: "?", accent: nil)
            }
            DatabaseProgressCellView(fraction: 0.72, percentText: "72 %")
                .frame(width: 160)
            HStack(spacing: Spacing.sm) {
                DatabaseCheckboxToggle(isChecked: $checked)
                DatabaseCheckboxToggle(isChecked: $unchecked)
            }
        }
        .padding(Spacing.lg)
        .background(SlateColor.bgEditor)
    }
}
