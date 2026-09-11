import SlateModel
import SlateUI
import SwiftUI

/// Tableau (`BlockType.table`), Phase 8, artboard H. Rend TOUTE la grille (lignes,
/// cellules) lui-meme -- `BlockTreeView` ne recurse pas dans les enfants d'un `table`
/// (voir sa documentation) : les `tableRow`/`tableCell` ne sont jamais des blocs de
/// premier niveau du point de vue du rendu, cette vue EST leur seul point d'entree
/// visuel.
///
/// ## Edition en texte simple (docs/08 : "texte simple d'abord suffit")
/// Chaque cellule est un `TextField` lie a `Block.text.plainText`, PAS un
/// `RichTextBlockView` : le texte riche en cellule est explicitement remis a plus tard
/// par la spec. `commit(_:for:)` reconstruit un `RichText(plainText:)` complet a chaque
/// frappe -- acceptable UNIQUEMENT parce qu'aucun attribut inline n'existe encore a
/// preserver dans une cellule vide/texte simple (contrairement a `RichTextBlockView.
/// Coordinator.textDidChange`, qui doit lui composer un `AttributedString` complet).
///
/// ## Navigation clavier (docs/08 : "Tab cellule suivante, Option+Tab insere une colonne,
/// fleches pour naviguer")
/// Deleguee a `TableNavigation` (pure, testable sans SwiftUI) : cette vue se contente de
/// lire les modificateurs de la touche et de deplacer `@FocusState`.
struct TableBlockContentView: View {
    let block: Block
    let editorController: EditorController

    @FocusState private var focusedCellID: UUID?
    /// Largeur de colonne au tout DEBUT du glisser courant (voir `columnResizeHandle(for:)`) :
    /// `DragGesture.translation` est TOUJOURS relatif au point de depart du geste, jamais
    /// incremental -- lire `columnWidth` en direct a chaque tick (deja mute par le tick
    /// precedent) additionnerait la translation ENTIERE a une base qui la contient deja,
    /// une croissance qui s'emballe. Capturee au premier tick de chaque geste, effacee a
    /// la fin.
    @State private var columnResizeStartWidth: Double?

    private var rows: [Block] { block.tableRows }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows, id: \.id) { row in
                    rowView(row)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .strokeBorder(SlateColor.tableBorder, lineWidth: SlateGeometry.strokeHairline)
            )
            addRowButton
        }
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
    }

    // MARK: - Lignes / cellules

    private func rowView(_ row: Block) -> some View {
        let cells = row.tableCells
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                cellView(cell, row: row, isHeader: row.attributes.isHeaderRow, isLastColumn: index == cells.count - 1)
            }
        }
        .background(row.attributes.isHeaderRow ? Color.clear : rowStripeBackground(row))
    }

    /// Lignes alternees (docs/08, artboard H : "lignes alternees") sur les lignes de
    /// CORPS uniquement -- la ligne d'en-tete garde `table.header.bg`
    /// (`TableHeaderCell`), jamais l'alternance.
    private func rowStripeBackground(_ row: Block) -> Color {
        let bodyRows = rows.filter { !$0.attributes.isHeaderRow }
        guard let index = bodyRows.firstIndex(where: { $0.id == row.id }) else { return .clear }
        return index.isMultiple(of: 2) ? .clear : SlateColor.tableRowStripe
    }

    @ViewBuilder
    private func cellView(_ cell: Block, row: Block, isHeader: Bool, isLastColumn: Bool) -> some View {
        if isHeader {
            TableHeaderCell(showsTrailingBorder: !isLastColumn) {
                cellField(cell)
            }
            .overlay(alignment: .trailing) { columnResizeHandle(for: cell) }
            .contextMenu { contextMenuContent(for: cell, row: row) }
        } else {
            cellField(cell)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: cell.attributes.columnWidth.map { CGFloat($0) })
                .overlay(alignment: .trailing) {
                    if !isLastColumn {
                        Rectangle().fill(SlateColor.tableBorder).frame(width: SlateGeometry.strokeHairline)
                    }
                }
                .contextMenu { contextMenuContent(for: cell, row: row) }
        }
    }

    private func cellField(_ cell: Block) -> some View {
        TextField("", text: textBinding(for: cell))
            .textFieldStyle(.plain)
            .focused($focusedCellID, equals: cell.id)
            .onKeyPress(keys: [.tab]) { press in
                // Option+Tab (docs/08 : "Option+Tab insere une colonne") a priorite sur
                // la navigation simple/Maj+Tab.
                if press.modifiers.contains(.option) {
                    editorController.insertTableColumn(in: block, at: cell.order + 1)
                    return .handled
                }
                return handleTab(from: cell, backward: press.modifiers.contains(.shift))
            }
            .onKeyPress(.upArrow) { moveFocus(to: TableNavigation.cell(above: cell)) }
            .onKeyPress(.downArrow) { moveFocus(to: TableNavigation.cell(below: cell)) }
    }

    // MARK: - Texte de cellule (voir la documentation de tete de fichier)

    private func textBinding(for cell: Block) -> Binding<String> {
        Binding(
            get: { cell.text?.plainText ?? "" },
            set: { editorController.setTableCellText($0, in: cell) }
        )
    }

    // MARK: - Navigation clavier

    private func handleTab(from cell: Block, backward: Bool) -> KeyPress.Result {
        let next = backward ? TableNavigation.previousCell(before: cell) : TableNavigation.nextCell(after: cell)
        return moveFocus(to: next)
    }

    @discardableResult
    private func moveFocus(to target: Block?) -> KeyPress.Result {
        guard let target else { return .ignored }
        focusedCellID = target.id
        return .handled
    }

    // MARK: - Menu contextuel (ajout/suppression de ligne/colonne)

    @ViewBuilder
    private func contextMenuContent(for cell: Block, row: Block) -> some View {
        Button(EditorStrings.tableInsertRowAboveTitle) { editorController.insertTableRow(in: block, at: row.order) }
        Button(EditorStrings.tableInsertRowBelowTitle) { editorController.insertTableRow(in: block, at: row.order + 1) }
        Button(EditorStrings.tableDeleteRowTitle) { editorController.removeTableRow(block, at: row.order) }
        Divider()
        Button(EditorStrings.tableInsertColumnLeftTitle) {
            editorController.insertTableColumn(in: block, at: cell.order)
        }
        Button(EditorStrings.tableInsertColumnRightTitle) {
            editorController.insertTableColumn(in: block, at: cell.order + 1)
        }
        Button(EditorStrings.tableDeleteColumnTitle) { editorController.removeTableColumn(block, at: cell.order) }
    }

    // MARK: - Ajout de ligne (bouton visible, complement du menu contextuel)

    private var addRowButton: some View {
        Button {
            editorController.insertTableRow(in: block)
        } label: {
            Label(EditorStrings.tableAddRowAccessibilityLabel, systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(EditorStrings.tableAddRowAccessibilityLabel)
    }

    // MARK: - Redimensionnement de colonne (artboard H)

    /// Glisser sur le bord droit d'une cellule d'EN-TETE : ajuste `columnWidth` pour
    /// toute la colonne (`Block.setTableColumnWidth`, applique aux memes cellules dans
    /// TOUTES les lignes). Mis a jour a CHAQUE tick du glisser (pas seulement en fin de
    /// geste) pour un retour visuel immediat -- un glisser de colonne est un geste court
    /// et rare, la sauvegarde repetee qui en resulte reste negligeable (voir le rapport
    /// de livraison pour cet arbitrage assume).
    private func columnResizeHandle(for headerCell: Block) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        let base = columnResizeStartWidth
                            ?? headerCell.attributes.columnWidth
                            ?? Self.defaultColumnWidth
                        columnResizeStartWidth = base
                        let newWidth = max(Self.minimumColumnWidth, base + value.translation.width)
                        editorController.setTableColumnWidth(newWidth, forColumnAt: headerCell.order, in: block)
                    }
                    .onEnded { _ in columnResizeStartWidth = nil }
            )
    }

    private static let defaultColumnWidth: Double = 160
    private static let minimumColumnWidth: Double = 60
}
