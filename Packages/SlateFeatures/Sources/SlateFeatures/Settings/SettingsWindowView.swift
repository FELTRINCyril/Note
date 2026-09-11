import SwiftUI
import SlateUI

/// Fenetre de reglages de Slate (Phase 13, design P4 artboard A).
///
/// "Fenetre de reglages macOS standard : barre d'onglets en haut, une vue par onglet,
/// largeur fixe 620 pt, hauteur adaptee au contenu. Pas de sidebar de reglages --
/// quatre onglets ne le justifient pas." Meme motif que `LockSettingsTabView.frame(
/// width: 460)`, deja dans la base de code : la largeur de fenetre est une mesure de
/// LAYOUT fixee par le design, pas une valeur `Spacing`/`SlateGeometry`.
///
/// Branchee dans `App/SlateApp.swift` via une scene `Settings { SettingsWindowView() }`
/// (Menu Slate > Reglages, Cmd+,) -- voir le rapport de livraison pour les autres
/// points d'entree.
public struct SettingsWindowView: View {
    private static let windowWidth: CGFloat = 620

    public init() {}

    public var body: some View {
        TabView {
            AppearanceSettingsTabView()
                .tabItem {
                    Label(String(localized: "settings.tab.appearance", bundle: .module), systemImage: "paintbrush")
                }

            LockSettingsTabView()
                .tabItem {
                    Label(String(localized: "settings.tab.lock", bundle: .module), systemImage: "lock")
                }

            AISettingsTabView()
                .tabItem {
                    Label(String(localized: "settings.tab.ai", bundle: .module), systemImage: "sparkles")
                }

            GeneralSettingsTabView()
                .tabItem {
                    Label(String(localized: "settings.tab.general", bundle: .module), systemImage: "gearshape")
                }
        }
        .environment(ThemeManager.shared)
        .frame(width: Self.windowWidth)
    }
}

#Preview("SettingsWindowView") {
    SettingsWindowView()
}

#Preview("SettingsWindowView - sombre") {
    SettingsWindowView()
        .preferredColorScheme(.dark)
}
