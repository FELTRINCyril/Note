import SlateModel
import SlateUI
import SwiftUI

/// Une cellule de la barre de calculs (17.3) : `DatabaseCalculationCell` + popover de
/// choix de l'agregat au clic (`onTap`, jamais un `Menu` imbricant un `Button` -
/// `DatabaseCalculationCell` est deja un `Button`, un second geste de tap a l'interieur
/// d'un `Menu` serait ambigu).
struct DatabaseCalculationBarCell: View {
    let result: DatabaseCalculationResult
    let calculation: SlateDatabaseColumnCalculation
    let onSelect: (SlateDatabaseColumnCalculation) -> Void

    @State private var isPickerPresented = false

    var body: some View {
        DatabaseCalculationCell(
            resultText: DatabaseCellFormatting.text(for: result, calculation: calculation),
            isEmphasized: calculation != .none,
            onTap: { isPickerPresented = true }
        )
        .popover(isPresented: $isPickerPresented) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(SlateDatabaseColumnCalculation.allCases) { option in
                    Button {
                        onSelect(option)
                        isPickerPresented = false
                    } label: {
                        DatabaseFieldTypeRow(title: option.displayName, isSelected: option == calculation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm)
            .frame(minWidth: 180)
        }
    }
}
