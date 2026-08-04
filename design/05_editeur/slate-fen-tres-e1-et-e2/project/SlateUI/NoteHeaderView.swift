//  NoteHeaderView.swift — SlateUI
//  En-tête de note (E4) : couverture optionnelle, icône/emoji optionnel, titre, sous-titre, méta.
//  Le formatage inline et les blocs spéciaux ne sont pas ici (E6 / E7).

import SwiftUI

public struct SlateNoteHeader {
    public var title: String = ""
    public var subtitle: String = ""
    public var icon: String? = nil            // emoji ou nom de symbole
    public var coverImageName: String? = nil  // image de couverture (asset / fichier)
    public var metaLine: String = ""          // « Modifiée aujourd'hui à 14:22 · 428 mots »
    public init(title: String = "", subtitle: String = "", icon: String? = nil,
                coverImageName: String? = nil, metaLine: String = "") {
        self.title = title; self.subtitle = subtitle; self.icon = icon
        self.coverImageName = coverImageName; self.metaLine = metaLine
    }
}

public struct NoteHeaderView: View {
    @Binding var header: SlateNoteHeader
    /// Champ actuellement en édition (le titre porte alors son caret).
    var focusedField: Field? = nil
    public enum Field { case title, subtitle }

    @Environment(\.slateAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveringHeader = false
    @State private var hoveringCover = false

    public init(header: Binding<SlateNoteHeader>, focusedField: Field? = nil) {
        self._header = header; self.focusedField = focusedField
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if header.coverImageName != nil { cover }

            EditorContentColumn {
                VStack(alignment: .leading, spacing: 0) {
                    if let icon = header.icon {
                        Text(icon)
                            .font(.system(size: SlateEditorMetrics.iconSize * 0.72))
                            .frame(width: SlateEditorMetrics.iconSize,
                                   height: SlateEditorMetrics.iconSize, alignment: .leading)
                            .padding(.leading, SlateEditorMetrics.gutter)
                            .padding(.top, header.coverImageName == nil
                                     ? SlateSpace.s : -SlateEditorMetrics.iconOverlap)
                            .padding(.bottom, SlateSpace.s)
                            .accessibilityLabel("Icône de la note")
                    }

                    // Actions d'en-tête : révélées au survol, comme le chrome de bloc.
                    headerActions
                        .padding(.leading, SlateEditorMetrics.gutter)
                        .padding(.bottom, SlateSpace.s)

                    // Titre — `title.note` 28 Bold. Placeholder « Sans titre ».
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        ZStack(alignment: .leading) {
                            if header.title.isEmpty {
                                Text("Sans titre")
                                    .slateFont(.titleNote)
                                    .foregroundStyle(SlateColors.textPlaceholder)
                            }
                            TextField("", text: $header.title, axis: .vertical)
                                .textFieldStyle(.plain)
                                .slateFont(.titleNote)
                                .foregroundStyle(SlateColors.textPrimary)
                        }
                        if focusedField == .title, header.title.isEmpty {
                            BlockCaret(lineHeight: 28 * 1.15)
                        }
                    }
                    .padding(.leading, SlateEditorMetrics.gutter)

                    // Sous-titre — `subtitle` 17 Regular, `text.secondary`.
                    // Masqué s'il est vide et que l'en-tête n'est pas survolé.
                    if !header.subtitle.isEmpty || hoveringHeader || focusedField == .subtitle {
                        ZStack(alignment: .leading) {
                            if header.subtitle.isEmpty {
                                Text("Ajouter un sous-titre")
                                    .slateFont(.subtitle)
                                    .foregroundStyle(SlateColors.textPlaceholder)
                            }
                            TextField("", text: $header.subtitle, axis: .vertical)
                                .textFieldStyle(.plain)
                                .slateFont(.subtitle)
                                .foregroundStyle(SlateColors.textSecondary)
                        }
                        .padding(.top, SlateSpace.s)
                        .padding(.leading, SlateEditorMetrics.gutter)
                        .transition(.opacity)
                    }

                    Text(header.metaLine)
                        .slateFont(.caption)
                        .foregroundStyle(SlateColors.textTertiary)
                        .padding(.top, SlateSpace.m)
                        .padding(.leading, SlateEditorMetrics.gutter)
                }
                .padding(.top, header.coverImageName == nil ? SlateEditorMetrics.contentTopPadding : 0)
                .padding(.bottom, SlateEditorMetrics.headerToBodySpacing)
            }
        }
        .onHover { h in
            withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                hoveringHeader = h
            }
        }
    }

    // MARK: Couverture

    private var cover: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(header.coverImageName ?? "")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: SlateEditorMetrics.coverHeight)
                .clipped()

            if hoveringCover {
                HStack(spacing: SlateSpace.xs) {
                    coverAction("Repositionner", "arrow.up.and.down")
                    coverAction("Changer", "photo")
                    coverAction("Supprimer", "trash")
                }
                .padding(SlateSpace.m)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .onHover { h in
            withAnimation(SlateMotion.standard(SlateMotion.fast, reduceMotion: reduceMotion)) {
                hoveringCover = h
            }
        }
        .accessibilityLabel("Image de couverture")
    }

    private func coverAction(_ label: String, _ symbol: String) -> some View {
        Button { } label: {
            HStack(spacing: SlateSpace.xs) {
                Image(systemName: symbol).font(.system(size: SlateMetrics.iconS - 2))
                Text(label).slateFont(.label)
            }
            .padding(.horizontal, SlateSpace.s)
            .frame(height: SlateMetrics.controlS)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SlateRadius.s))
            .overlay(RoundedRectangle(cornerRadius: SlateRadius.s)
                .strokeBorder(SlateColors.borderDefault, lineWidth: SlateStroke.hairline))
        }
        .buttonStyle(.plain)
        .foregroundStyle(SlateColors.textPrimary)
    }

    // MARK: Actions « Ajouter une icône / une couverture »

    @ViewBuilder private var headerActions: some View {
        HStack(spacing: SlateSpace.m) {
            if header.icon == nil {
                textAction("Ajouter une icône", "face.smiling") { header.icon = "🗂" }
            }
            if header.coverImageName == nil {
                textAction("Ajouter une couverture", "photo") { header.coverImageName = "cover" }
            }
        }
        .opacity(hoveringHeader ? 1 : 0)
        .allowsHitTesting(hoveringHeader)
        .frame(height: SlateMetrics.controlS, alignment: .leading)
    }

    private func textAction(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SlateSpace.xs) {
                Image(systemName: symbol).font(.system(size: SlateMetrics.iconS - 2))
                Text(label).slateFont(.label)
            }
            .foregroundStyle(SlateColors.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
