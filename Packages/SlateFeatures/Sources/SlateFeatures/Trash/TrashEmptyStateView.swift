import SwiftUI
import SlateUI

/// Etat vide de `TrashView` (design P3, artboard B, variante sombre "Corbeille vide") :
/// `ContentUnavailableView`, meme motif que `NoteListEmptyStateView`.
struct TrashEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "trash.empty.title", bundle: .module), systemImage: "trash")
        } description: {
            Text(String(localized: "trash.empty.description", bundle: .module))
        }
    }
}

#Preview("TrashEmptyStateView") {
    TrashEmptyStateView()
        .frame(width: 400, height: 400)
        .background(SlateColor.bgList)
}

#Preview("TrashEmptyStateView - sombre") {
    TrashEmptyStateView()
        .frame(width: 400, height: 400)
        .background(SlateColor.bgList)
        .preferredColorScheme(.dark)
}
