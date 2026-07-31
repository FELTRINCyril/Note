import SwiftUI

/// Ligne generique de barre laterale, sans aucune notion metier (pas de dossier, pas de
/// SwiftData) : elle sait dessiner un etat, pas ce qu'elle represente. `SlateFeatures`
/// compose cette ligne pour les vraies vues (`FolderRow`, favoris...).
///
/// Couvre l'integralite du "Catalogue d'etats" de la spec E2
/// (`design/03_sidebar/Slate_E1-E2_coquille-sidebar.html`) :
/// - normale (fond transparent) ;
/// - survol (`state.hover`, 120 ms) ;
/// - selectionnee, fenetre active (`accent.default` + `text.onAccent`) ;
/// - selectionnee, fenetre inactive (`state.selectedInactive`, via `controlActiveState`) ;
/// - focus clavier seul (anneau `focusRing` 3 pt, decalage 1 pt, sans fond) ;
/// - focus clavier + selection cumules (l'anneau reste visible par-dessus l'aplat) ;
/// - desactivee (`opacity.disabled`).
///
/// Deux regles de la spec sont respectees explicitement :
/// - l'indentation s'applique au CONTENU (icone/libelle), jamais au fond -- la pastille
///   de selection reste pleine largeur ;
/// - la selection est un APLAT, le focus clavier est un ANNEAU : les deux se cumulent
///   sans jamais se confondre visuellement.
public struct SidebarRow<Leading: View, Trailing: View>: View {
    private let title: String
    private let indentLevel: Int
    private let isSelected: Bool
    private let isFocused: Bool
    private let isDisabled: Bool
    private let leading: Leading
    private let trailing: Trailing

    @State private var isHovering = false
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        indentLevel: Int = 0,
        isSelected: Bool = false,
        isFocused: Bool = false,
        isDisabled: Bool = false,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.indentLevel = indentLevel
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.isDisabled = isDisabled
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            leading
            Text(title)
                .slateFont(SlateFont.sidebarItem)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.middle)
                .foregroundStyle(labelColor)
            Spacer(minLength: Spacing.xs)
            trailing
        }
        // Le contenu (icone, libelle, compteur/chevron...) doit savoir s'il est pose sur
        // l'aplat plein de selection pour choisir une couleur de premier plan lisible
        // (voir `OnAccentFill.swift`). Uniquement vrai en fenetre active : en fenetre
        // inactive le fond bascule sur `state.selectedInactive`, neutre, ou `text.tertiary`
        // reste lisible.
        .environment(\.slateIsOnAccentFill, isSelectedInActiveWindow)
        .padding(.leading, Spacing.sm + CGFloat(indentLevel) * SlateGeometry.sidebarIndentStep)
        .padding(.trailing, Spacing.sm)
        .frame(minHeight: SlateGeometry.sidebarRowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous))
        .overlay(focusRingOverlay)
        .padding(.horizontal, SlateGeometry.sidebarGutter)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Selection "active" au sens visuel : selectionnee ET fenetre au premier plan.
    /// Fenetre inactive -> `controlActiveState.inactive` -> bascule sur
    /// `state.selectedInactive` (spec : "toute selection passe en state.selectedInactive").
    private var isSelectedInActiveWindow: Bool {
        isSelected && controlActiveState != .inactive
    }

    @ViewBuilder
    private var rowBackground: some View {
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

    private var labelColor: Color {
        if isSelectedInActiveWindow {
            return SlateColor.textOnAccent
        }
        return isDisabled ? SlateColor.textDisabled : SlateColor.textPrimary
    }

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall, style: .continuous)
                .inset(by: -SlateGeometry.focusRingOffset)
                .stroke(SlateColor.focusRing, lineWidth: SlateGeometry.focusRingWidth)
        }
    }
}

#Preview("SidebarRow - catalogue d'etats (clair)") {
    SidebarRowStatesPreview()
        .frame(width: 240)
        .background(SlateColor.bgSidebarOpaque)
}

#Preview("SidebarRow - catalogue d'etats (sombre)") {
    SidebarRowStatesPreview()
        .frame(width: 240)
        .background(SlateColor.bgSidebarOpaque)
        .preferredColorScheme(.dark)
}

#Preview("SidebarRow - fenetre inactive") {
    SidebarRowStatesPreview()
        .frame(width: 240)
        .background(SlateColor.bgSidebarOpaque)
        .environment(\.controlActiveState, .inactive)
}

/// Rassemble tous les etats du catalogue pour les previews : evite de dupliquer sept
/// blocs d'appel identiques dans chaque `#Preview`.
private struct SidebarRowStatesPreview: View {
    var body: some View {
        VStack(spacing: 2) {
            SidebarRow(title: "Normale") {
                Circle().fill(SlateFolderColor.yellow.color).frame(width: 8, height: 8)
            }
            SidebarRow(title: "Selectionnee", isSelected: true) {
                Circle().fill(SlateFolderColor.yellow.color).frame(width: 8, height: 8)
            }
            // Cas precedemment casse (defaut de revue) : le compteur restait en
            // `text.tertiary` sur l'aplat de selection, illisible (~1,59:1). Aucune
            // preview ne le montrait -- celle-ci le montre explicitement, corrige.
            SidebarRow(title: "Selectionnee avec compteur", isSelected: true) {
                Circle().fill(SlateFolderColor.violet.color).frame(width: 8, height: 8)
            } trailing: {
                SidebarCounter(count: 12)
            }
            SidebarRow(title: "Focus clavier seul", isFocused: true) {
                Circle().fill(SlateFolderColor.yellow.color).frame(width: 8, height: 8)
            }
            SidebarRow(title: "Focus + selection", isSelected: true, isFocused: true) {
                Circle().fill(SlateFolderColor.yellow.color).frame(width: 8, height: 8)
            }
            SidebarRow(title: "Indentee, niveau 1", indentLevel: 1) {
                Circle().fill(SlateFolderColor.violet.color).frame(width: 8, height: 8)
            } trailing: {
                SidebarCounter(count: 4)
            }
            SidebarRow(title: "Desactivee", isDisabled: true) {
                Circle().fill(SlateFolderColor.graphite.color).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}
