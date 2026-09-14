import SwiftUI

/// Etat "3 chargement" du parcours d'un bloc image, artboard A de
/// `Slate P2 - Medias & pieces jointes.dc.html` (Phase 9).
///
/// "La barre est doublee par le texte, la progression n'est pas portee par la seule
/// couleur" (artboard A) : le pourcentage en chiffres tabulaires est TOUJOURS affiche a
/// cote de la barre, jamais seulement dessine dedans.
public struct MediaUploadProgressView: View {
    private let fileName: String
    private let fileSizeText: String
    /// 0...1. La vue clampe elle-meme : l'appelant peut passer une valeur brute non
    /// bornee sans crasher le rendu.
    private let progress: Double
    private let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    public init(
        fileName: String,
        fileSizeText: String,
        progress: Double,
        onCancel: @escaping () -> Void = {}
    ) {
        self.fileName = fileName
        self.fileSizeText = fileSizeText
        self.progress = min(max(progress, 0), 1)
        self.onCancel = onCancel
    }

    private var percentText: String {
        "\(Int((progress * 100).rounded()))\u{a0}%"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .slateIconFont(16, weight: .semibold)
                    .foregroundStyle(SlateColor.textSecondary)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.9).repeatForever(autoreverses: false),
                        value: isSpinning
                    )
                    .onAppear { isSpinning = true }
                    .accessibilityHidden(true)

                Text(fileName)
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: Spacing.sm)

                Text("\(fileSizeText) \u{b7} \(percentText)")
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textSecondary)

                Button(SlateUIStrings.mediaUploadCancel, action: onCancel)
                    .buttonStyle(.plain)
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.accentDefault)
            }

            progressBar
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: SlateGeometry.mediaDropzoneHeight)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium).fill(SlateColor.mediaDropzoneBackground))
        // La barre EST redondante avec le texte (artboard A) : elle reste donc
        // decorative pour VoiceOver, qui lit deja le pourcentage via le texte ci-dessus.
        .accessibilityElement(children: .combine)
        .accessibilityValue(percentText)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(SlateColor.statePressed)
                Capsule()
                    .fill(SlateColor.accentDefault)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: SlateGeometry.mediaUploadProgressBarHeight)
        .animation(
            SlateMotion.animation(duration: SlateMotion.durationBase, reduceMotion: reduceMotion),
            value: progress
        )
    }
}

#Preview("MediaUploadProgressView - clair") {
    MediaUploadProgressView(fileName: "schema-blocs.png", fileSizeText: "1,8 Mo", progress: 0.64)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("MediaUploadProgressView - sombre") {
    MediaUploadProgressView(fileName: "schema-blocs.png", fileSizeText: "1,8 Mo", progress: 0.64)
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}
