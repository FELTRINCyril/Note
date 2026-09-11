import SwiftUI

/// Familles de fichiers avec une pastille d'icone TEINTEE, artboard B de
/// `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9). Seuls le PDF et le tableur ont
/// une teinte dediee mesuree par l'artboard D ; tout autre type (audio, archive, image
/// non affichee comme cadre...) reste `.generic`, dont la pastille retombe sur
/// `attachmentIconBackgroundFallback` / `attachmentIconGlyphFallback` (design/tokens.md
/// §16 quater, `attachment.icon.bg` : "teinte .subtle du type, sinon `state.hover`").
///
/// "Le type est toujours ecrit en clair a cote [des metadonnees] : la pastille coloree
/// n'est jamais la seule indication" (artboard B) -- `AttachmentRowView` ecrit le type en
/// toutes lettres dans ses metadonnees, cette enum ne pilote QUE la pastille.
///
/// Les composantes RGB brutes sont exposees separement des `Color` adaptatives (meme
/// motif que `SlateCalloutVariant`/`SlateSyntaxToken`) : mesurables par `WCAGContrast`
/// sans dependre du rendu SwiftUI.
public enum SlateAttachmentFileType: String, CaseIterable, Identifiable, Sendable {
    case pdf
    case spreadsheet
    case generic

    public var id: String { rawValue }

    /// Monogramme affiche dans la pastille (`nil` pour `.generic`, qui affiche un glyphe
    /// SF Symbol fourni par l'appelant a la place -- `AttachmentRowView` choisit le
    /// symbole selon le type reel du fichier, `SlateUI` ne connait pas ces types metier).
    public var monogram: String? {
        switch self {
        case .pdf: "PDF"
        case .spreadsheet: "XLS"
        case .generic: nil
        }
    }

    /// `attachment.icon.bg`, composante translucide claire. Artboard B : `rgba(255,59,48,
    /// 0.12)` pour le PDF (= `semantic.error` a 12 %), `rgba(52,199,89,0.12)` pour le
    /// tableur (= `semantic.success` a 12 %). `nil` pour `.generic`, qui retombe sur
    /// `attachmentIconBackgroundFallback` (`state.hover`, pas une teinte translucide).
    var backgroundLightRGB: SlateRGB? {
        switch self {
        case .pdf: SlateRGB(red: 1, green: 59.0 / 255, blue: 48.0 / 255, alpha: 0.12)
        case .spreadsheet: SlateRGB(red: 52.0 / 255, green: 199.0 / 255, blue: 89.0 / 255, alpha: 0.12)
        case .generic: nil
        }
    }

    /// `attachment.icon.bg`, composante translucide sombre. Artboard B ne donne
    /// directement que le PDF (`rgba(255,69,58,0.18)` = `semantic.error` sombre a 18 %) ;
    /// le tableur sombre n'est pas illustre -- meme construction appliquee a
    /// `semantic.success` sombre (`#30D158`), par coherence avec le PDF. Provisoire tant
    /// que Cyril n'a pas fourni l'artboard tableur sombre.
    var backgroundDarkRGB: SlateRGB? {
        switch self {
        case .pdf: SlateRGB(red: 1, green: 69.0 / 255, blue: 58.0 / 255, alpha: 0.18)
        case .spreadsheet: SlateRGB(red: 48.0 / 255, green: 209.0 / 255, blue: 88.0 / 255, alpha: 0.18)
        case .generic: nil
        }
    }

    /// Couleur du monogramme, clair. Artboard D : "Pastille PDF `#B3261E` ... 6,01:1.
    /// Pastille XLS `#1E7A34` ... 4,96:1".
    var labelLightRGB: SlateRGB {
        switch self {
        case .pdf: SlateRGB(hex: "#B3261E") ?? .black
        case .spreadsheet: SlateRGB(hex: "#1E7A34") ?? .black
        case .generic: SlateRGB(red: 0, green: 0, blue: 0, alpha: SlateTextOpacity.secondaryLight)
        }
    }

    /// Couleur du monogramme, sombre. Pas d'artboard PDF/tableur sombre direct : reprend
    /// respectivement `attachmentErrorCauseText` (sombre, deja mesure a 6,42:1) et
    /// `semantic.success` sombre (`#30D158`, meme choix que les callouts), par coherence
    /// avec la construction du fond. Provisoire, voir `backgroundDarkRGB`.
    var labelDarkRGB: SlateRGB {
        switch self {
        case .pdf: SlateRGB(hex: "#FF8A82") ?? .white
        case .spreadsheet: SlateRGB(hex: "#30D158") ?? .white
        case .generic: SlateRGB(red: 1, green: 1, blue: 1, alpha: SlateTextOpacity.secondaryDark)
        }
    }

    /// Fond adaptatif de la pastille. Retombe sur `attachmentIconBackgroundFallback`
    /// (`state.hover`) pour `.generic`.
    public var backgroundColor: Color {
        guard let light = backgroundLightRGB, let dark = backgroundDarkRGB else {
            return SlateColor.attachmentIconBackgroundFallback
        }
        return slateAdaptiveColor(light: light, dark: dark)
    }

    /// Couleur adaptative du monogramme / glyphe. Retombe sur
    /// `attachmentIconGlyphFallback` (`text.secondary`) pour `.generic`.
    public var labelColor: Color {
        guard self != .generic else { return SlateColor.attachmentIconGlyphFallback }
        return slateAdaptiveColor(light: labelLightRGB, dark: labelDarkRGB)
    }
}
