import SwiftUI

/// Couleurs des blocs media (image, fichier joint) : design/tokens.md §16 quater,
/// artboards A/B/C de `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9).
///
/// "Aucun [token] n'introduit de couleur nouvelle : tous derivent de §3 et §5" (artboard
/// A) : chaque propriete ci-dessous est un ALIAS nomme d'un token existant, sauf la
/// couleur de cause d'erreur (`attachmentErrorCauseText`), seule valeur reellement
/// nouvelle du lot (mesuree par l'artboard D).
public extension SlateColor {
    /// `media.dropzone.bg`. Fond de la zone de depot vide au repos = `surface.secondary`.
    static let mediaDropzoneBackground = surfaceSecondary

    /// `media.dropzone.border`. Tirete au repos = `border.strong`.
    static let mediaDropzoneBorder = borderStrong

    /// `media.dropzone.active.bg`. Fond pendant un survol de depot = `accent.subtle`.
    static let mediaDropzoneActiveBackground = accentSubtle

    /// Tirete pendant un survol de depot = `accent.default` (artboard A : "tirete 2 pt en
    /// accent.default").
    static let mediaDropzoneActiveBorder = accentDefault

    /// Libelle + icone de la zone de depot pendant un survol ("Deposer <fichier>").
    /// Artboard A (clair, `#05509E`) et artboard C (sombre, `#6CB6FF`) : exactement la
    /// couleur de libelle de la variante `info` des callouts (design/tokens.md §16 bis) --
    /// alias, pas une nouvelle teinte.
    static let mediaDropzoneActiveLabel = SlateCalloutVariant.info.labelColor

    /// `media.handle.fill`. Poignee de redimensionnement d'image = `accent.default`.
    static let mediaHandleFill = accentDefault

    /// Lisere de la poignee, en `bg.editor` (design/tokens.md §16 quater : "lisere 1,5 pt
    /// en bg.editor") -- alias, pour que la poignee reste lisible sur l'image qu'elle
    /// chevauche.
    static let mediaHandleBorder = bgEditor

    /// Fond de pastille d'icone d'un type de fichier SANS teinte dediee (audio, archive,
    /// generique...). Design/tokens.md §16 quater, `attachment.icon.bg` : "teinte .subtle
    /// du type, sinon `state.hover`" -- alias.
    static let attachmentIconBackgroundFallback = stateHover

    /// Glyphe dessine dans une pastille SANS teinte dediee. Artboard B : glyphe a 50 % /
    /// 55 % d'opacite, soit `text.secondary` -- alias.
    static let attachmentIconGlyphFallback = textSecondary

    /// Ligne de cause d'un fichier introuvable ("Fichier introuvable - non synchronise
    /// depuis cet appareil"). Artboard B (sombre) : `rgba(255,255,255,0.55)`, soit
    /// `text.secondary` -- alias (le manque n'est pas une erreur, juste un etat neutre).
    static let attachmentMissingCauseText = textSecondary

    /// Bordure tiretee d'un fichier introuvable. Artboard B (sombre) :
    /// `rgba(255,255,255,0.28)`, soit exactement `border.strong` -- alias.
    static let attachmentMissingBorder = borderStrong

    /// Ligne de cause d'un echec d'import ("Echec de l'import - fichier superieur a
    /// 2 Go"). SEULE couleur reellement nouvelle de `MediaColors.swift` (design/tokens.md
    /// §16 quater, artboard D : "Ligne d'erreur `#FF8A82` sur `bg.editor` sombre :
    /// 6,42:1"). En clair, l'artboard ne donne pas de valeur directe (l'etat n'est
    /// illustre qu'en sombre) : on reutilise `#B3261E`, la teinte de la pastille PDF deja
    /// mesuree par l'artboard D a 6,01:1 sur son propre fond translucide -- tres proche du
    /// blanc pur de `bg.editor` clair, donc un contraste tout aussi eleve (verifie par
    /// `MediaAttachmentContrastTests`). Provisoire tant que Cyril n'a pas fourni la valeur
    /// clair explicite.
    static let attachmentErrorCauseText = slateAdaptiveColor(
        light: SlateRGB(hex: "#B3261E") ?? .black,
        dark: SlateRGB(hex: "#FF8A82") ?? .black
    )

    /// Fond de la pastille d'icone d'un fichier en echec d'import. Artboard B (sombre) :
    /// `rgba(255,69,58,0.18)` -- exactement `semantic.error` (`#FF453A`) a 18 % d'opacite,
    /// meme construction que la pastille PDF (voir `SlateAttachmentFileType`). Alias vers
    /// celle-ci plutot qu'une nouvelle paire de RGB.
    static let attachmentErrorIconBackground = SlateAttachmentFileType.pdf.backgroundColor

    /// Glyphe de la pastille d'icone d'un fichier en echec d'import = `attachmentErrorCauseText`
    /// (meme famille rouge, alias).
    static let attachmentErrorIconGlyph = attachmentErrorCauseText

    /// Fond des puces flottantes (badge de palier, bouton menu) posees SUR L'IMAGE
    /// elle-meme (artboard A, sombre : `rgba(28,28,30,0.9)`). Constante NON adaptative
    /// clair/sombre a dessein : ces puces flottent sur une photo, dont la luminosite est
    /// independante du theme de l'app -- le meme scrim sombre reste le plus fiable dans
    /// les deux cas (l'artboard clair ne l'illustre pas separement).
    static let mediaOverlayChipBackground = Color.black.opacity(0.55)
}
