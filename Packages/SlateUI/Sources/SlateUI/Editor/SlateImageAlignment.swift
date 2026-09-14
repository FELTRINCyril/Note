import SwiftUI

/// Paliers d'alignement/largeur d'un bloc image, artboard A de
/// `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9) : "Trois largeurs, pas un
/// curseur libre. Colonne (720 pt), debord (960 pt) et pleine largeur : les poignees se
/// calent sur ces paliers".
///
/// Gauche/Centre/Droite ne changent QUE la position dans la colonne (720 pt, largeur
/// inchangee) ; Debord et Pleine largeur sont des PALIERS DE LARGEUR (voir
/// `SlateGeometry.mediaOverflowWidth`). Les cinq valeurs cohabitent dans la meme barre
/// (`MediaAlignmentBar`), comme sur l'artboard.
public enum SlateImageAlignment: String, CaseIterable, Identifiable, Sendable {
    case left
    case center
    case right
    case overflow
    case fullWidth

    public var id: String { rawValue }

    /// Libelle affiche dans `MediaAlignmentBar` (artboard A).
    public var label: String {
        SlateUIStrings.imageAlignmentLabel(self)
    }

    /// Libelle annonce au clavier lors d'un changement de palier (artboard A : "Au
    /// clavier : Opt+Left / Opt+Right passent d'un palier au suivant et annoncent
    /// 'largeur colonne, 720 points'"). `SlateEditor` est responsable de le poster via
    /// `NSAccessibility`/`AccessibilityNotification` -- ce token ne fait que porter le
    /// texte attendu.
    public var accessibilityAnnouncement: String {
        SlateUIStrings.imageAlignmentAnnouncement(self)
    }

    /// Badge de palier affiche sur le cadre d'image selectionnee (artboard A, sombre :
    /// "720 pt - colonne"). Gauche/Centre/Droite partagent le meme palier de largeur
    /// (720 pt) : seule la position dans la colonne change entre eux.
    public var widthBadgeText: String {
        SlateUIStrings.imageAlignmentWidthBadge(self)
    }
}
