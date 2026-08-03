import SwiftUI

/// Cellule generique de liste (titre + extrait optionnel + zones libres avant/apres),
/// sans aucune notion metier (pas de note, pas de SwiftData, pas d'`import SlateModel`) :
/// elle sait dessiner un etat, pas ce qu'elle represente. `SlateFeatures` compose cette
/// cellule pour construire la vraie `NoteCell` (titre de note, extrait de blocs,
/// indicateurs epingle/verrouille/favori, date relative).
///
/// La spec E3 (`design/04_liste_notes/Slate E1-E3.dc.html`, "Etats de cellule - NoteCell",
/// "NoteCell" y designe le composant COMPOSITE final) nomme `NoteCell` comme vivant dans
/// `SlateUI` : c'est une erreur au regard de l'architecture (`SlateUI` ne doit connaitre
/// aucune notion de Note). `ListCell` est la primitive generique correspondante ;
/// `NoteCell` sera construit par-dessus dans `SlateFeatures`.
///
/// Couvre l'integralite du "Catalogue d'etats - NoteCell" de la spec E3 :
/// - normale (fond transparent, filet `separator` en bas) ;
/// - survol (`state.hover`, 120 ms) ;
/// - selectionnee, fenetre active (`accentSelectionFill`, filet masque) ;
/// - selectionnee, fenetre inactive (`state.selectedInactive`, filet masque) ;
/// - focus clavier seul (anneau `focusRing` 3 pt EN INSET -- pas en offset, voir
///   `SlateGeometry.noteCellFocusRingInset`) ;
/// - focus clavier + selection cumules ;
/// - indicateurs cumules (le contenu de `leading` est libre, la cellule ne sait pas ce
///   qu'il represente) ;
/// - desactivee (`opacity.disabled`).
///
/// Le titre et l'extrait passent respectivement par `SlateColor.foreground(_:onAccentFill:)`
/// (premier plan PRINCIPAL) et `SlateColor.foregroundSecondary(_:onAccentFill:)` (premier
/// plan SECONDAIRE, blanc 95% -- spec E3 : "le secondaire sur selection est passe de
/// blanc 85% a blanc 95%"), via `EnvironmentValues.slateIsOnAccentFill` publie par cette
/// cellule -- exactement le mecanisme anticipe par `OnAccentFill.swift` en phase 3.
public struct ListCell<Leading: View, Trailing: View>: View {
    private let title: String
    private let isTitlePlaceholder: Bool
    private let snippet: String?
    private let isSnippetPlaceholder: Bool
    private let isSelected: Bool
    private let isFocused: Bool
    private let isDisabled: Bool
    private let accessibilityLabelOverride: String?
    private let leading: Leading
    private let trailing: Trailing

    @State private var isHovering = false
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        isTitlePlaceholder: Bool = false,
        snippet: String? = nil,
        isSnippetPlaceholder: Bool = false,
        isSelected: Bool = false,
        isFocused: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel accessibilityLabelOverride: String? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.isTitlePlaceholder = isTitlePlaceholder
        self.snippet = snippet
        self.isSnippetPlaceholder = isSnippetPlaceholder
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.isDisabled = isDisabled
        self.accessibilityLabelOverride = accessibilityLabelOverride
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                leading
                Text(title)
                    .slateFont(SlateFont.listTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(titleColor)
                Spacer(minLength: Spacing.xs)
                trailing
            }
            if let snippet {
                Text(snippet)
                    .slateFont(SlateFont.listSnippet)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .foregroundStyle(snippetColor)
            }
        }
        // Le contenu (titre, extrait, indicateurs, date...) doit savoir s'il est pose sur
        // l'aplat plein de selection pour choisir un premier plan lisible. Voir
        // `OnAccentFill.swift` et la doc de tete ci-dessus.
        .environment(\.slateIsOnAccentFill, isSelectedInActiveWindow)
        .padding(.horizontal, SlateGeometry.noteCellPaddingHorizontal)
        .padding(.vertical, SlateGeometry.noteCellPaddingVertical)
        .frame(minHeight: SlateGeometry.noteCellMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cellBackground)
        .overlay(alignment: .bottom) { separatorOverlay }
        .overlay(focusRingOverlay)
        .opacity(isDisabled ? SlateOpacity.disabled : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard !isDisabled else { return }
            isHovering = hovering
        }
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationFast, reduceMotion: reduceMotion),
            value: isHovering
        )
        .accessibilityElement(children: accessibilityLabelOverride == nil ? .combine : .ignore)
        .modifier(OptionalAccessibilityLabelModifier(label: accessibilityLabelOverride))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Selection "active" au sens visuel : selectionnee ET fenetre au premier plan. Meme
    /// regle que `SidebarRow.isSelectedInActiveWindow`.
    private var isSelectedInActiveWindow: Bool {
        isSelected && controlActiveState != .inactive
    }

    @ViewBuilder
    private var cellBackground: some View {
        if isSelected {
            if controlActiveState == .inactive {
                SlateColor.stateSelectedInactive
            } else {
                SlateColor.accentSelectionFill
            }
        } else if isHovering {
            SlateColor.stateHover
        } else {
            Color.clear
        }
    }

    /// Filet 1 pt `separator`, masque sur la cellule selectionnee (spec E3 : "filet 1 pt
    /// separator masque sur la cellule selectionnee") -- que la fenetre soit active ou
    /// non : c'est l'etat de selection qui masque le filet, pas seulement l'aplat plein.
    @ViewBuilder
    private var separatorOverlay: some View {
        if !isSelected {
            Rectangle()
                .fill(SlateColor.separator)
                .frame(height: SlateGeometry.strokeHairline)
        }
    }

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            Rectangle()
                .inset(by: SlateGeometry.noteCellFocusRingInset)
                .stroke(SlateColor.focusRing, lineWidth: SlateGeometry.focusRingWidth)
        }
    }

    private var baseTitleColor: Color {
        if isTitlePlaceholder {
            return SlateColor.textTertiary
        }
        return isDisabled ? SlateColor.textDisabled : SlateColor.textPrimary
    }

    private var titleColor: Color {
        SlateColor.foreground(baseTitleColor, onAccentFill: isSelectedInActiveWindow)
    }

    private var baseSnippetColor: Color {
        isSnippetPlaceholder ? SlateColor.textTertiary : SlateColor.textSecondary
    }

    /// Premier plan SECONDAIRE (spec E3) : c'est CE texte qui a motive la correction de
    /// la regle de contraste (voir `ContrastRatio.swift`) -- l'extrait de la cellule
    /// selectionnee est le cas le plus exigeant qui se pose sur `accentSelectionFill`.
    private var snippetColor: Color {
        SlateColor.foregroundSecondary(baseSnippetColor, onAccentFill: isSelectedInActiveWindow)
    }
}

/// Applique `.accessibilityLabel` uniquement si une valeur explicite est fournie. Meme
/// motif que `SidebarCounter.OptionalAccessibilityLabelModifier`, duplique ici plutot que
/// partage : ce sont deux modificateurs prives, sans API commune a exposer.
private struct OptionalAccessibilityLabelModifier: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

#Preview("ListCell - catalogue d'etats (clair)") {
    ListCellStatesPreview()
        .frame(width: 300)
        .background(SlateColor.bgList)
}

#Preview("ListCell - catalogue d'etats (sombre)") {
    ListCellStatesPreview()
        .frame(width: 300)
        .background(SlateColor.bgList)
        .preferredColorScheme(.dark)
}

#Preview("ListCell - fenetre inactive") {
    ListCellStatesPreview()
        .frame(width: 300)
        .background(SlateColor.bgList)
        .environment(\.controlActiveState, .inactive)
}

/// Rassemble tous les etats du catalogue E3 pour les previews, y compris le cas
/// CRITIQUE : une cellule selectionnee avec extrait ET indicateurs cumules (c'est ce cas
/// precis qui a revele le defaut de contraste corrige en phase 4, voir `ContrastRatio.swift`).
private struct ListCellStatesPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ListCell(title: "Normale", snippet: "Un bloc = un noeud. Le modele porte le type.")
            ListCell(title: "Survol", snippet: "Un bloc = un noeud. Le modele porte le type.")
            ListCell(
                title: "Selectionnee, extrait + indicateurs (cas critique)",
                snippet: "Un bloc = un noeud. Le modele porte le type, la vue ne decide de rien.",
                isSelected: true
            ) {
                HStack(spacing: 2) {
                    Image(systemName: "pin.fill")
                        .slateIconFont(SlateGeometry.noteCellIndicatorIconSize)
                        .foregroundStyle(SlateColor.foreground(SlateColor.accentDefault, onAccentFill: true))
                    Image(systemName: "star.fill")
                        .slateIconFont(SlateGeometry.noteCellIndicatorIconSize)
                        .foregroundStyle(SlateColor.foreground(SlateColor.semanticWarning, onAccentFill: true))
                    Image(systemName: "lock.fill")
                        .slateIconFont(SlateGeometry.noteCellIndicatorIconSize)
                        .foregroundStyle(SlateColor.foreground(SlateColor.textSecondary, onAccentFill: true))
                }
            } trailing: {
                Text("09:48")
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.foregroundSecondary(SlateColor.textSecondary, onAccentFill: true))
            }
            ListCell(title: "Selectionnee, fenetre inactive", snippet: "Lundi revue de sprint.", isSelected: true)
            ListCell(title: "Focus clavier seul", snippet: "Anneau 3 pt en inset.", isFocused: true)
            ListCell(
                title: "Focus + selection cumulables",
                snippet: "Les deux se cumulent sans jamais se confondre.",
                isSelected: true,
                isFocused: true
            )
            ListCell(
                title: "Nouvelle note",
                isTitlePlaceholder: true,
                snippet: "Aucun contenu",
                isSnippetPlaceholder: true
            )
            ListCell(title: "Desactivee", snippet: "Non selectionnable.", isDisabled: true)
        }
    }
}
