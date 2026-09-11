import SlateModel
import SlateUI
import SwiftUI

/// Encadre (`BlockType.callout`), Phase 8, artboard F. `RichTextBlockView` porte le
/// texte, editable comme les autres blocs de cette phase. Les 4 variantes
/// (`neutral`/`info`/`warning`/`success`, `SlateCalloutVariant`) sont selectionnables et
/// persistees (`BlockAttributes.calloutVariant`, pont par `CalloutVariantResolver`).
///
/// ## `CalloutBlockView` (`SlateUI`) non reutilise tel quel
/// Ce composant fige son icone a `variant.symbol` ("pin.fill" pour `.neutral`, repli
/// provisoire documente de son cote), sans point d'injection pour un glyphe LIBRE choisi
/// par l'utilisateur (docs/08 : "la variante neutre prend une icone/emoji libre"). Ce
/// fichier reconstruit donc la MEME mise en page en reutilisant les TOKENS de
/// `SlateCalloutVariant` (fond/bordure/couleur de libelle/icone), avec :
/// - variante `.neutral` : un champ de saisie libre a la place du glyphe fixe, AUCUN
///   libelle de variante (design : "seule la variante neutre... aucun libelle" --
///   `SlateCalloutVariant.neutral.label` vaut deja `nil`, reutilise directement) ;
/// - les 3 autres variantes : le glyphe SF fixe de la variante (`variant.symbol`, comme
///   `CalloutBlockView`) ET son libelle teinte (`variant.label`/`variant.labelColor`).
/// Le corps reste `text.primary` dans les deux cas (`RichTextBlockView` ne recoit aucune
/// teinte de variante).
struct CalloutBlockContentView: View {
    let block: Block
    let editorController: EditorController

    private var variant: SlateCalloutVariant {
        CalloutVariantResolver.resolve(block.attributes.calloutVariant)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm + Spacing.xs) {
            iconArea
            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                if let label = variant.label {
                    Text(label)
                        .slateFont(SlateFont.bodyEmphasis)
                        .foregroundStyle(variant.labelColor)
                }
                RichTextBlockView(block: block, editorController: editorController)
            }
            Spacer(minLength: 0)
            variantMenu
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            variant.background,
            in: RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium, style: .continuous)
                .strokeBorder(variant.border, lineWidth: SlateGeometry.strokeHairline)
        )
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
    }

    /// Icone : champ libre pour `.neutral` (voir la documentation de tete de fichier),
    /// glyphe fixe teinte pour les 3 autres variantes -- comme `CalloutBlockView`.
    @ViewBuilder
    private var iconArea: some View {
        if variant == .neutral {
            iconField
        } else {
            Image(systemName: variant.symbol)
                .slateIconFont(SlateGeometry.calloutIconSize, weight: .regular, relativeTo: .body)
                .foregroundStyle(variant.labelColor)
                .frame(width: SlateGeometry.calloutIconSize * 1.6, height: SlateGeometry.calloutIconSize * 1.6)
                // Le libelle de variante porte deja le sens, meme regle que CalloutBlockView.
                .accessibilityHidden(true)
        }
    }

    /// Champ de saisie libre (un glyphe/emoji), en lieu et place du symbole SF fixe --
    /// voir la documentation de tete de fichier. `\.prefix(2)` : borne a un seul
    /// "caractere visuel" au sens le plus courant (un emoji peut occuper 2 unites
    /// `Character` avec un modificateur de ton de peau/variation) sans imposer de
    /// dependance a une bibliotheque de segmentation graphemique tierce.
    private var iconField: some View {
        TextField("", text: iconBinding)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: SlateGeometry.calloutIconSize))
            .frame(width: SlateGeometry.calloutIconSize * 1.6, height: SlateGeometry.calloutIconSize * 1.6)
            .accessibilityLabel(EditorStrings.calloutIconAccessibilityLabel)
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: { block.attributes.calloutIcon ?? "\u{1F4CC}" },
            set: { newValue in
                let trimmed = String(newValue.prefix(2))
                editorController.setCalloutIcon(trimmed.isEmpty ? nil : trimmed, in: block)
            }
        )
    }

    /// Selecteur de variante REELLEMENT fonctionnel (persiste dans
    /// `BlockAttributes.calloutVariant` via `EditorController.setCalloutVariant(_:in:)`) :
    /// un `Menu` plutot qu'un `Picker` inline -- l'encadre n'a pas de zone de chrome
    /// dediee (contrairement au bloc code et sa `CodeBlockToolbar`), ce bouton discret
    /// reste la seule affordance necessaire pour changer de variante sans alourdir
    /// visuellement chaque callout.
    private var variantMenu: some View {
        Menu {
            ForEach(SlateCalloutVariant.allCases) { candidate in
                Button {
                    editorController.setCalloutVariant(
                        candidate == .neutral ? nil : candidate.rawValue, in: block
                    )
                } label: {
                    if candidate == variant {
                        Label(EditorStrings.calloutVariantMenuLabel(candidate.rawValue), systemImage: "checkmark")
                    } else {
                        Text(EditorStrings.calloutVariantMenuLabel(candidate.rawValue))
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .slateIconFont(SlateGeometry.sidebarIconSize, relativeTo: .caption)
                .foregroundStyle(SlateColor.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(EditorStrings.calloutVariantMenuAccessibilityLabel)
    }
}
