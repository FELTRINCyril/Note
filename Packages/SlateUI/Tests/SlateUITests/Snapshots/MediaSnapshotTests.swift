import Testing
import SwiftUI
@testable import SlateUI

/// Verification visuelle des medias et pieces jointes (Phase 9, artboards A/B/C de
/// `Slate P2 - Medias & pieces jointes.dc.html`) : zone de depot, progression d'import,
/// cadre d'image avec sa barre d'alignement, ligne de piece jointe dans ses 3 etats --
/// clair ET sombre.
@MainActor
@Suite("Verification visuelle - medias et pieces jointes (Phase 9)")
struct MediaSnapshotTests {
    @Test("Zone de depot - repos et survol de depot, clair et sombre")
    func dropzone() throws {
        for scheme in ColorScheme.allCases {
            for isTargeted in [false, true] {
                let suffix = isTargeted ? "targeted" : "idle"
                let view = MediaDropzoneView(
                    isTargeted: isTargeted,
                    draggedFileName: isTargeted ? "schema-blocs.png" : nil
                )
                .padding()
                .frame(width: 480)
                .background(SlateColor.bgEditor)
                .environment(\.colorScheme, scheme)

                try SnapshotRenderer.render(view, named: "media_dropzone_\(suffix)_\(scheme.snapshotSuffix)")
            }
        }
    }

    @Test("Progression d'import, clair et sombre")
    func uploadProgress() throws {
        for scheme in ColorScheme.allCases {
            let view = MediaUploadProgressView(fileName: "schema-blocs.png", fileSizeText: "1,8 Mo", progress: 0.64)
                .padding()
                .frame(width: 480)
                .background(SlateColor.bgEditor)
                .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(view, named: "media_upload_progress_\(scheme.snapshotSuffix)")
        }
    }

    @Test("Cadre d'image selectionne (barre d'alignement) et affiche, clair et sombre")
    func imageFrame() throws {
        for scheme in ColorScheme.allCases {
            for isSelected in [true, false] {
                let suffix = isSelected ? "selected" : "displayed"
                let view = ImageFramePreview(isSelected: isSelected)
                    .padding()
                    .frame(width: 480)
                    .background(SlateColor.bgEditor)
                    .environment(\.colorScheme, scheme)

                try SnapshotRenderer.render(view, named: "media_image_frame_\(suffix)_\(scheme.snapshotSuffix)")
            }
        }
    }

    @Test("Ligne de piece jointe - normal, echec, manquant, clair et sombre")
    func attachmentRow() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                AttachmentRowGallery().environment(\.colorScheme, scheme),
                named: "media_attachment_row_\(scheme.snapshotSuffix)"
            )
        }
    }
}

private struct ImageFramePreview: View {
    let isSelected: Bool
    @State private var alignment: SlateImageAlignment = .center
    @State private var caption = "Architecture des blocs, revision de septembre."

    var body: some View {
        ImageFrameView(
            dimensionsText: "schema-blocs.png . 1 640 x 984",
            alignment: alignment,
            isSelected: isSelected,
            caption: $caption,
            onSelectAlignment: { alignment = $0 },
            content: {
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .fill(SlateColor.surfaceTertiary)
                    .frame(height: 220)
            }
        )
    }
}

private struct AttachmentRowGallery: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            AttachmentRowView(
                fileType: .pdf,
                fileName: "Specifications techniques v4.pdf",
                metadata: "PDF . 2,4 Mo . 12 pages"
            ) {
                Group {
                    Button("Renommer") {}
                    Button("Revele dans le Finder") {}
                    Button("Supprimer le bloc") {}
                }
            }

            AttachmentRowView(
                fileType: .generic,
                fileName: "montage-final.mov",
                metadata: "",
                status: .failedImport(cause: "Echec de l'import - fichier superieur a 2 Go")
            )

            AttachmentRowView(
                fileType: .pdf,
                fileName: "notes-terrain.pdf",
                metadata: "",
                status: .missing(reason: "Fichier introuvable - non synchronise depuis cet appareil")
            )
        }
        .padding()
        .frame(width: 500)
        .background(SlateColor.bgEditor)
    }
}
