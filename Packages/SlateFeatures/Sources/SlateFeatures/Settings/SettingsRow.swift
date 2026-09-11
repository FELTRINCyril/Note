import SwiftUI
import SlateUI

/// Une ligne de la grammaire "un reglage = une ligne" imposee par le design P4
/// (artboard A) : libelle aligne a droite sur une colonne fixe, controle a droite,
/// explication en style `caption` sous le controle. C'est la grammaire des Reglages
/// Systeme macOS -- s'en ecarter donnerait une fenetre qui ne ressemble pas a un Mac.
///
/// Largeur de colonne (180 pt) et largeur de fenetre (620 pt, voir `SettingsWindowView`)
/// sont des mesures de LAYOUT propres a cet ecran, pas des valeurs de la palette
/// `Spacing`/`SlateGeometry` -- meme convention que `LockSettingsTabView.frame(width:
/// 460)`, deja dans la base de code.
struct SettingsRow<Control: View>: View {
    /// `nil` pour une ligne dont le libelle a deja ete pose par la ligne precedente
    /// (ex: options groupees sous un seul "Options :", design P4 artboard A).
    let label: String?
    var caption: String?
    @ViewBuilder let control: () -> Control

    static var labelColumnWidth: CGFloat { 180 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text(label ?? "")
                    .frame(width: Self.labelColumnWidth, alignment: .trailing)
                    .slateFont(SlateFont.label)
                    .foregroundStyle(SlateColor.textPrimary)
                    .accessibilityHidden(label == nil)
                control()
                Spacer(minLength: 0)
            }
            if let caption {
                Text(caption)
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textSecondary)
                    .padding(.leading, Self.labelColumnWidth + Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("SettingsRow") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        SettingsRow(
            label: String(localized: "settings.appearance.theme.label", bundle: .module),
            caption: String(localized: "settings.appearance.theme.caption", bundle: .module)
        ) {
            Text("Systeme")
        }
        SettingsRow(label: nil) {
            Toggle("Option groupee", isOn: .constant(true))
        }
    }
    .padding(Spacing.lg)
    .frame(width: 620)
}
