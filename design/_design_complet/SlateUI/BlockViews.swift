//  BlockViews.swift — SlateUI
//  Apparences de blocs de la planche P1. Aucune valeur en dur : tout vient de
//  Tokens.swift / EditorTokens.swift / BlockTokens.swift.

import SwiftUI

// MARK: - Focus clavier vs sélection (règle unique pour toute l'app)

/// Sélection = aplat sans contour. Focus clavier = anneau sans aplat.
/// Les deux peuvent coexister et restent distinguables.
public struct SlateBlockChrome: ViewModifier {
    let isSelected: Bool
    let isFocused: Bool
    @Environment(\.slateAccent) private var accent

    public init(isSelected: Bool, isFocused: Bool) {
        self.isSelected = isSelected
        self.isFocused = isFocused
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, SlateEditorMetrics.selectionBleed)
            .background(
                RoundedRectangle(cornerRadius: SlateRadius.s / 1.5, style: .continuous)
                    .fill(isSelected ? SlateEditorColors.blockSelected : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous)
                    // liseré 1 pt opaque : focusRing seul ne tient que 3,08:1
                    .strokeBorder(isFocused ? accent.color : .clear, lineWidth: SlateStroke.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SlateRadius.s, style: .continuous)
                    .inset(by: -SlateStroke.focusRingOffset)
                    .strokeBorder(isFocused ? accent.focusRing : .clear,
                                  lineWidth: SlateStroke.focusRingWidth)
            )
            .padding(.horizontal, -SlateEditorMetrics.selectionBleed)
    }
}

public extension View {
    func slateBlockChrome(selected: Bool = false, focused: Bool = false) -> some View {
        modifier(SlateBlockChrome(isSelected: selected, isFocused: focused))
    }
}

// MARK: - Callout

public struct CalloutBlockView<Content: View>: View {
    let variant: SlateCalloutVariant
    let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(_ variant: SlateCalloutVariant, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: SlateSpace.s + SlateSpace.xxs) {
            Image(systemName: variant.symbol)
                .font(.system(size: SlateMetrics.iconM, weight: .regular))
                .foregroundStyle(variant.labelColor)
                .accessibilityHidden(variant.label != nil)   // le libellé porte déjà le sens
            VStack(alignment: .leading, spacing: SlateSpace.xxs) {
                if let label = variant.label {
                    Text(label)
                        .slateFont(.bodyEmphasis)
                        .foregroundStyle(variant.labelColor)
                }
                content
                    .slateFont(.callout)
                    .foregroundStyle(SlateColors.textPrimary)   // le corps ne se teinte jamais
            }
        }
        .padding(SlateSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(variant.background, in: RoundedRectangle(cornerRadius: SlateRadius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SlateRadius.m, style: .continuous)
                .strokeBorder(variant.border, lineWidth: SlateStroke.hairline)
        )
        .padding(.vertical, SlateBlockMetrics.decoratedSpacing)
    }
}

// MARK: - Citation

public struct QuoteBlockView<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        HStack(alignment: .top, spacing: SlateSpace.m) {
            RoundedRectangle(cornerRadius: SlateBlockMetrics.quoteBarWidth / 2)
                .fill(SlateEditorColors.quoteBar)
                .frame(width: SlateBlockMetrics.quoteBarWidth)
            content
                .slateFont(.quote)
                .foregroundStyle(SlateEditorColors.quoteText)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, SlateBlockMetrics.decoratedSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Citation")
    }
}

// MARK: - Bloc de code

public struct CodeBlockView: View {
    public let source: [(SlateSyntaxToken, String)]
    @State public var language: String
    @State private var isHovering = false
    @State private var didCopy = false
    @FocusState private var isFocused: Bool
    @Environment(\.slateAccent) private var accent

    public init(language: String = "swift", source: [(SlateSyntaxToken, String)]) {
        self._language = State(initialValue: language)
        self.source = source
    }

    private var chromeVisible: Bool { isHovering || isFocused }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {   // jamais de retour à la ligne forcé
            code.padding(SlateSpace.m)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SlateEditorColors.codeBlockBg,
                    in: RoundedRectangle(cornerRadius: SlateRadius.m, style: .continuous))
        .overlay(alignment: .topTrailing) { toolbar.opacity(chromeVisible ? 1 : 0) }
        .animation(.easeInOut(duration: 0.12), value: chromeVisible)
        .onHover { isHovering = $0 }
        .focusable()
        .focused($isFocused)
        .padding(.vertical, SlateBlockMetrics.decoratedSpacing)
    }

    private var code: some View {
        source.reduce(Text("")) { acc, part in
            acc + Text(part.1).foregroundColor(part.0.color)
        }
        .slateFont(.mono)
        .textSelection(.enabled)
    }

    private var toolbar: some View {
        HStack(spacing: SlateSpace.xs) {
            Picker("Langage", selection: $language) {
                ForEach(["swift", "javascript", "python", "json", "text"], id: \.self) {
                    Text($0.capitalized).tag($0)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            Button {
                copy()
            } label: {
                Label(didCopy ? "Copié" : "Copier",
                      systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .slateFont(.label)
                    // vert seulement en appui du mot : le succès n'est pas porté par la couleur
                    .foregroundStyle(didCopy ? SlateColors.success : SlateColors.textPrimary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("c", modifiers: [.control, .option])   // atteignable sans survol
        }
        .padding(SlateSpace.s)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source.map(\.1).joined(), forType: .string)
        didCopy = true
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: "Code copié"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { didCopy = false }
    }
}

// MARK: - Listes

public enum SlateListMarker {
    case bullet(level: Int)
    case ordered(index: Int, level: Int)

    var text: String {
        switch self {
        case .bullet(let l): ["•", "▸", "▪"][min(l, 2)]
        case .ordered(let i, let l):
            switch min(l, 2) {
            case 0: "\(i)."
            case 1: "\(Character(UnicodeScalar(96 + min(i, 26))!))."
            default: Self.roman(i) + "."
            }
        }
    }
    var level: Int { switch self { case .bullet(let l): l; case .ordered(_, let l): l } }

    private static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var n = n, out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }
}

public struct ListItemView<Content: View>: View {
    let marker: SlateListMarker
    let content: Content
    public init(_ marker: SlateListMarker, @ViewBuilder content: () -> Content) {
        self.marker = marker
        self.content = content()
    }
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SlateSpace.s) {
            Text(marker.text)
                .slateFont(.body)
                .slateTabularNumbers()          // la colonne ne bouge pas de 9 à 10
                .foregroundStyle(SlateColors.textSecondary)
                .frame(width: SlateBlockMetrics.markerWidth,
                       alignment: isOrdered ? .trailing : .center)
                .accessibilityHidden(true)
            content.slateFont(.body).foregroundStyle(SlateColors.textPrimary)
        }
        .padding(.leading, CGFloat(marker.level) * SlateBlockMetrics.listIndent)
        .padding(.vertical, SlateEditorMetrics.blockSpacing / 2)
    }
    private var isOrdered: Bool { if case .ordered = marker { true } else { false } }
}

public struct ChecklistItemView<Content: View>: View {
    @Binding var isDone: Bool
    let level: Int
    let content: Content
    @FocusState private var isFocused: Bool
    @Environment(\.slateAccent) private var accent

    public init(isDone: Binding<Bool>, level: Int = 0, @ViewBuilder content: () -> Content) {
        self._isDone = isDone
        self.level = level
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SlateSpace.s) {
            Button { isDone.toggle() } label: {
                RoundedRectangle(cornerRadius: SlateRadius.s / 1.5, style: .continuous)
                    .fill(isDone ? accent.color : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: SlateRadius.s / 1.5, style: .continuous)
                            .strokeBorder(isDone ? .clear : SlateEditorColors.todoCheckboxBorder,
                                          lineWidth: SlateStroke.regular)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(SlateColors.textOnAccent)
                            .opacity(isDone ? 1 : 0)
                    )
                    .frame(width: SlateMetrics.checkboxSize, height: SlateMetrics.checkboxSize)
                    .frame(width: SlateBlockMetrics.checkboxHitSize,
                           height: SlateBlockMetrics.checkboxHitSize)   // cible élargie
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .focusRingIfNeeded(isFocused)
            .accessibilityLabel("Tâche")
            .accessibilityValue(isDone ? "effectuée" : "à faire")

            content
                .slateFont(.body)
                .strikethrough(isDone)                                   // pas que la couleur
                .foregroundStyle(isDone ? SlateColors.textTertiary : SlateColors.textPrimary)
        }
        .padding(.leading, CGFloat(level) * SlateBlockMetrics.listIndent)
        .padding(.vertical, SlateEditorMetrics.blockSpacing / 2)
    }
}

private extension View {
    @ViewBuilder func focusRingIfNeeded(_ focused: Bool) -> some View {
        if focused { self.slateBlockChrome(selected: false, focused: true) } else { self }
    }
}

// MARK: - Divider

public struct DividerBlockView: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(SlateEditorColors.divider)
            .frame(height: SlateStroke.hairline)
            .frame(height: SlateBlockMetrics.dividerHitHeight)   // cible de sélection
            .contentShape(Rectangle())
            .accessibilityLabel("Séparateur")
    }
}

// MARK: - Colonnes

public struct ColumnsBlockView<Content: View>: View {
    @Binding var fractions: [CGFloat]     // mémorisées en fractions, pas en points
    let content: (Int) -> Content
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(fractions: Binding<[CGFloat]>, @ViewBuilder content: @escaping (Int) -> Content) {
        self._fractions = fractions
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            let stacked = geo.size.width < SlateBlockMetrics.columnStackThreshold
                || typeSize >= .accessibility1
            if stacked {
                VStack(alignment: .leading, spacing: SlateSpace.l) {
                    ForEach(fractions.indices, id: \.self) { i in
                        content(i)
                        if i < fractions.count - 1 { DividerBlockView() }
                    }
                }
            } else {
                HStack(spacing: SlateBlockMetrics.columnGap) {
                    ForEach(fractions.indices, id: \.self) { i in
                        content(i).frame(width: width(for: i, in: geo.size.width))
                        if i < fractions.count - 1 { ColumnResizer(index: i, fractions: $fractions) }
                    }
                }
            }
        }
    }

    private func width(for i: Int, in total: CGFloat) -> CGFloat {
        let gaps = SlateBlockMetrics.columnGap * CGFloat(fractions.count - 1)
        return max(SlateBlockMetrics.columnMinWidth, (total - gaps) * fractions[i])
    }
}

private struct ColumnResizer: View {
    let index: Int
    @Binding var fractions: [CGFloat]
    @State private var isActive = false
    @Environment(\.slateAccent) private var accent

    var body: some View {
        RoundedRectangle(cornerRadius: SlateBlockMetrics.columnResizerWidth / 2)
            .fill(isActive ? accent.color : SlateColors.separator)
            .frame(width: isActive ? SlateBlockMetrics.columnResizerWidth : SlateStroke.hairline)
            .frame(width: SlateSpace.s)          // zone de saisie plus large que le trait
            .contentShape(Rectangle())
            .onHover { isActive = $0; if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(DragGesture().onChanged { _ in isActive = true }
                                  .onEnded { _ in isActive = false })
            .accessibilityLabel("Largeur des colonnes \(index + 1) et \(index + 2)")
            .accessibilityAdjustableAction { _ in }   // ajustable au clavier
    }
}
