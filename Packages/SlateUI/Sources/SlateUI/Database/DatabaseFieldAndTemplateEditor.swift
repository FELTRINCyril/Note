import SwiftUI

/// Editeur de champ (menu de types + options d'un champ Selection) et editeur de
/// template de fiche (design/tokens.md §18, artboard D). Composants de PRESENTATION
/// purs.

/// Ligne bordee generique (nom du champ, type courant...) : fond `surface.primary`,
/// bordure `border.default`, rayon `radius.s` (artboard D : "hauteur 28, bordure 1 pt").
public struct DatabaseBorderedRow<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            content
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 28)
        .background(SlateColor.surfacePrimary)
        .overlay(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall).strokeBorder(SlateColor.borderDefault))
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
    }
}

/// Ligne du menu "Type de champ" : titre + detail secondaire optionnel (artboard D :
/// "Nombre - entier, decimal, %, devise"), etat selectionne = aplat `accent.default` +
/// texte `text.onAccent` (comme un item de menu macOS).
public struct DatabaseFieldTypeRow: View {
    private let title: String
    private let detail: String?
    private let isSelected: Bool
    private let action: () -> Void

    public init(title: String, detail: String? = nil, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.detail = detail
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                if let detail {
                    Text(detail)
                        .foregroundStyle(isSelected ? foreground.opacity(0.8) : SlateColor.textSecondary)
                }
                Spacer(minLength: Spacing.xs)
            }
            .slateFont(SlateFont.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, Spacing.sm)
            .frame(height: 26)
            .background(isSelected ? SlateColor.accentDefault : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var foreground: Color { isSelected ? SlateColor.textOnAccent : SlateColor.textPrimary }
}

/// Ligne d'une option d'un champ Selection : grip de reordonnancement + apercu de la
/// pastille + bouton de suppression (artboard D).
public struct DatabaseFieldOptionRow: View {
    private let title: String
    private let style: SlateDatabasePillStyle
    private let onRemove: () -> Void

    public init(title: String, style: SlateDatabasePillStyle, onRemove: @escaping () -> Void = {}) {
        self.title = title
        self.style = style
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "line.3.horizontal")
                .slateIconFont(11, relativeTo: .caption)
                .foregroundStyle(SlateColor.textTertiary)
            DatabasePillView(title, style: style, isCompact: true)
            Spacer(minLength: Spacing.xs)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .slateIconFont(11, weight: .semibold, relativeTo: .caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SlateColor.textSecondary)
            .accessibilityLabel(SlateUIStrings.databaseRemoveOptionLabel)
        }
    }
}

/// Ligne "+ Ajouter une option" (artboard D).
public struct DatabaseAddOptionRow: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus").slateIconFont(11, weight: .semibold, relativeTo: .caption)
                Text(SlateUIStrings.databaseAddOptionLabel)
            }
        }
        .buttonStyle(.plain)
        .slateFont(SlateFont.label)
        .foregroundStyle(SlateColor.textSecondary)
        .padding(.leading, SlateGeometry.databaseStatusBulletSize * 2.5)
    }
}

// MARK: - Boutons pleins/bordes (panneaux D)

/// Bouton plein, accent par defaut (ex: "Definir par defaut").
public struct DatabasePrimaryButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
        }
        .buttonStyle(.plain)
        .background(SlateColor.accentDefault)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
    }
}

/// Bouton borde, neutre (ex: "Modifier").
public struct DatabaseSecondaryButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall).strokeBorder(SlateColor.borderDefault))
    }
}

/// Ligne propriete/valeur du template de fiche (artboard D : "Statut - [pastille]",
/// "Avancement - 0 %").
public struct DatabaseTemplatePropertyRow<Value: View>: View {
    private let label: String
    private let value: Value

    public init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textSecondary)
                .frame(width: 80, alignment: .leading)
            value
        }
    }
}

#Preview("DatabaseFieldAndTemplateEditor - clair") {
    DatabaseFieldEditorGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseFieldAndTemplateEditor - sombre") {
    DatabaseFieldEditorGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseFieldEditorGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DatabaseBorderedRow { Text("Statut").slateFont(SlateFont.label) }
            DatabaseFieldOptionRow(
                title: "A faire",
                style: SlateDatabasePillStyle(accent: nil, bullet: .hollowCircle)
            )
            DatabaseFieldOptionRow(title: "En cours", style: SlateDatabasePillStyle(accent: .blue, bullet: .square))
            DatabaseAddOptionRow(action: {})
            DatabaseFieldTypeRow(title: "Texte")
            DatabaseFieldTypeRow(title: "Nombre", detail: "entier, decimal, %, devise")
            DatabaseFieldTypeRow(title: "Selection unique", isSelected: true)
            HStack(spacing: Spacing.sm) {
                DatabaseSecondaryButton("Modifier", action: {})
                DatabasePrimaryButton("Definir par defaut", action: {})
            }
            DatabaseTemplatePropertyRow("Avancement") {
                Text("0 %").slateFont(SlateFont.caption).foregroundStyle(SlateColor.textPrimary)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 300)
        .background(SlateColor.surfacePrimary)
    }
}
