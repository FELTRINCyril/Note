import SwiftUI
import SlateUI

/// Contenu de l'onglet "Apparence" des reglages (design P4, artboard A).
///
/// Theme/accent/police/taille de texte sont portes par `ThemeManager` (`SlateUI`,
/// Phase 13, livre par l'agent des tokens en parallele de cette vue) : ils sont donc
/// REELLEMENT appliques partout dans l'app des qu'on les change ici (recoloration de
/// `accent.*`, `.preferredColorScheme` branche dans `App/SlateApp.swift`, police et
/// taille lues par `SlateFont`). Les trois options de bas de page ("Afficher la
/// couverture", "Reduire la transparence", "Augmenter le contraste") sont DESORMAIS
/// PORTEES PAR `ThemeManager` elles aussi (branchement reel de la Phase 13 "suite") :
/// `NoteHeaderView` (`SlateEditor`), `SidebarMaterialBackground` et
/// `SlateColor.separator`/`.borderDefault`/`.borderStrong` (`SlateUI`) les lisent
/// reellement. L'ancien `AppearanceSettingsStore`, qui les stockait sans consommateur,
/// a ete supprime.
///
/// Les libelles de theme, d'accent et de police viennent directement des `displayName`
/// de `ThemeManager.Appearance`/`SlateAccentColor`/`ThemeManager.BodyFontChoice`.
/// Cette vue en recomposait autrefois des copies localisees, parce que ceux de
/// `SlateUI` etaient figes en francais ; `SlateUI` a desormais son propre catalogue,
/// donc la duplication a ete supprimee : une seule source par libelle.
struct AppearanceSettingsTabView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var themeManager = themeManager

        VStack(alignment: .leading, spacing: Spacing.lg) {
            SettingsRow(
                label: String(localized: "settings.appearance.theme.label", bundle: .module),
                caption: String(localized: "settings.appearance.theme.caption", bundle: .module)
            ) {
                Picker(
                    String(localized: "settings.appearance.theme.label", bundle: .module),
                    selection: $themeManager.appearance
                ) {
                    ForEach(ThemeManager.Appearance.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }

            SettingsRow(
                label: String(localized: "settings.appearance.accent.label", bundle: .module),
                caption: String(localized: "settings.appearance.accent.caption", bundle: .module)
            ) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(SlateAccentColor.allCases) { color in
                            AccentSwatchButton(
                                color: color,
                                name: color.displayName,
                                isSelected: themeManager.accent == color
                            ) {
                                themeManager.accent = color
                            }
                        }
                    }
                }
            }

            SettingsRow(label: String(localized: "settings.appearance.font.label", bundle: .module)) {
                Picker(
                    String(localized: "settings.appearance.font.label", bundle: .module),
                    selection: $themeManager.bodyFont
                ) {
                    ForEach(ThemeManager.BodyFontChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }

            SettingsRow(
                label: String(localized: "settings.appearance.textSize.label", bundle: .module),
                caption: String(localized: "settings.appearance.textSize.caption", bundle: .module)
            ) {
                HStack(spacing: Spacing.sm) {
                    Text("A")
                        .slateFont(SlateFont.caption)
                        .foregroundStyle(SlateColor.textSecondary)
                        .accessibilityHidden(true)
                    Slider(value: $themeManager.textSizeMultiplier, in: ThemeManager.textSizeMultiplierRange)
                        .frame(width: 140)
                        .accessibilityLabel(String(localized: "settings.appearance.textSize.label", bundle: .module))
                    Text("A")
                        .slateFont(SlateFont.h4)
                        .foregroundStyle(SlateColor.textSecondary)
                        .accessibilityHidden(true)
                }
            }

            SettingsRow(label: String(localized: "settings.appearance.options.label", bundle: .module)) {
                Toggle(
                    String(localized: "settings.appearance.options.showCover", bundle: .module),
                    isOn: $themeManager.showsNoteCover
                )
                .toggleStyle(.checkbox)
            }
            SettingsRow(label: nil) {
                Toggle(
                    String(localized: "settings.appearance.options.reduceSidebarTransparency", bundle: .module),
                    isOn: $themeManager.reducesSidebarTransparency
                )
                .toggleStyle(.checkbox)
            }
            SettingsRow(
                label: nil,
                caption: String(localized: "settings.appearance.options.caption", bundle: .module)
            ) {
                Toggle(
                    String(localized: "settings.appearance.options.increaseSeparatorContrast", bundle: .module),
                    isOn: $themeManager.increasesSeparatorContrast
                )
                .toggleStyle(.checkbox)
            }
        }
        .padding(Spacing.lg)
    }
}
