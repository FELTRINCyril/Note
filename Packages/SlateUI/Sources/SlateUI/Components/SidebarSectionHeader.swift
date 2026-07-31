import SwiftUI

/// En-tete de section de la barre laterale (ex: "FAVORIS", "ESPACES").
///
/// 11 pt Semibold, majuscules, tracking 0,4 (design/tokens.md §17, spec E2). Un bouton
/// d'action facultatif (ex: "+" pour "Espaces") peut etre ajoute a droite : il n'est
/// pas specifique aux dossiers, juste une action generique sur la section.
public struct SidebarSectionHeader: View {
    private let title: String
    private let action: SidebarSectionHeaderAction?

    public init(_ title: String, action: SidebarSectionHeaderAction? = nil) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
                .slateFont(SlateFont.sidebarSectionHeader)
                .textCase(.uppercase)
                .foregroundStyle(SlateColor.sidebarSectionHeaderText)
            Spacer(minLength: Spacing.sm)
            if let action {
                Button(action: action.perform) {
                    Image(systemName: action.systemImage)
                }
                .buttonStyle(.plain)
                .foregroundStyle(SlateColor.textTertiary)
                .accessibilityLabel(action.accessibilityLabel)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }
}

/// Action facultative d'un en-tete de section (ex: "+" pour ajouter un espace).
public struct SidebarSectionHeaderAction: Sendable {
    public let systemImage: String
    public let accessibilityLabel: String
    public let perform: @Sendable () -> Void

    public init(systemImage: String, accessibilityLabel: String, perform: @Sendable @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.perform = perform
    }
}

#Preview("SidebarSectionHeader") {
    VStack(alignment: .leading, spacing: 0) {
        SidebarSectionHeader("Favoris")
        SidebarSectionHeader(
            "Espaces",
            action: SidebarSectionHeaderAction(systemImage: "plus", accessibilityLabel: "Nouvel espace") {}
        )
    }
    .background(SlateColor.bgSidebarOpaque)
}

#Preview("SidebarSectionHeader - sombre") {
    VStack(alignment: .leading, spacing: 0) {
        SidebarSectionHeader("Favoris")
        SidebarSectionHeader(
            "Espaces",
            action: SidebarSectionHeaderAction(systemImage: "plus", accessibilityLabel: "Nouvel espace") {}
        )
    }
    .background(SlateColor.bgSidebarOpaque)
    .preferredColorScheme(.dark)
}
