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
/// `ThemeManager.Appearance`/`SlateAccentColor`/`ThemeManager.BodyFontChoice`
/// exposent bien un `displayName`, mais en francais fige (`SlateUI` n'a pas de
/// catalogue de localisation, voir `SlateAccentColor.displayName`) : cette vue
/// recompose ses propres libelles localises FR/EN a partir des `rawValue`/cas plutot
/// que de les reutiliser, pour respecter l'exigence de localisation de
/// `SlateFeatures`.
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
                        Text(themeLabel(choice)).tag(choice)
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
                                name: accentName(color),
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
                    Text(String(localized: "settings.appearance.font.sans", bundle: .module))
                        .tag(ThemeManager.BodyFontChoice.sans)
                    Text(String(localized: "settings.appearance.font.serif", bundle: .module))
                        .tag(ThemeManager.BodyFontChoice.serif)
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

    private func themeLabel(_ choice: ThemeManager.Appearance) -> String {
        switch choice {
        case .system: String(localized: "settings.appearance.theme.system", bundle: .module)
        case .light: String(localized: "settings.appearance.theme.light", bundle: .module)
        case .dark: String(localized: "settings.appearance.theme.dark", bundle: .module)
        }
    }

    private func accentName(_ color: SlateAccentColor) -> String {
        switch color {
        case .blue: String(localized: "settings.appearance.accent.blue", bundle: .module)
        case .purple: String(localized: "settings.appearance.accent.violet", bundle: .module)
        case .pink: String(localized: "settings.appearance.accent.rose", bundle: .module)
        case .red: String(localized: "settings.appearance.accent.red", bundle: .module)
        case .orange: String(localized: "settings.appearance.accent.orange", bundle: .module)
        case .yellow: String(localized: "settings.appearance.accent.yellow", bundle: .module)
        case .green: String(localized: "settings.appearance.accent.green", bundle: .module)
        case .graphite: String(localized: "settings.appearance.accent.graphite", bundle: .module)
        }
    }
}

#Preview("AppearanceSettingsTabView") {
    AppearanceSettingsTabView()
        .environment(ThemeManager.shared)
        .frame(width: 620)
}

#Preview("AppearanceSettingsTabView - sombre") {
    AppearanceSettingsTabView()
        .environment(ThemeManager.shared)
        .frame(width: 620)
        .preferredColorScheme(.dark)
}
