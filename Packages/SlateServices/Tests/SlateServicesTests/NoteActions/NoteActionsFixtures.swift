import Foundation
import SlateModel
import SwiftData

/// Fixtures et helpers partages par les tests de Phase 11
/// (`docs/11_organisation_notes.md`), dans le meme esprit que `ImageFixtures.swift`
/// pour `AttachmentServiceTests` : un seul endroit pour construire le graphe de blocs
/// riche utilise par plusieurs suites de tests (duplication, corbeille).
@MainActor
enum NoteActionsFixtures {
    /// Locale figee pour que les assertions sur le suffixe de titre ne dependent pas
    /// de la locale de la machine qui execute les tests (meme raison que
    /// `AttachmentService.formattedFileSize(_:locale:)`).
    static let frenchLocale = Locale(identifier: "fr_FR")

    /// Construit une note avec un graphe de blocs riche : paragraphe simple, une
    /// colonne (columnList -> column -> paragraphe), un tableau (table -> tableRow ->
    /// tableCell), et un bloc image avec piece jointe. Sert de fixture commune aux
    /// tests de duplication profonde et de corbeille.
    static func makeRichNote(in context: ModelContext) -> Note {
        let note = Note(title: "Note source")
        context.insert(note)

        let paragraph = Block(order: 0, type: .paragraph, text: RichText(plainText: "Paragraphe"), note: note)
        context.insert(paragraph)

        let columnList = Block(order: 1, type: .columnList, note: note)
        context.insert(columnList)
        let column = Block(order: 0, type: .column, note: note, parent: columnList)
        context.insert(column)
        let columnParagraph = Block(
            order: 0,
            type: .paragraph,
            text: RichText(plainText: "Dans la colonne"),
            note: note,
            parent: column
        )
        context.insert(columnParagraph)
        column.children = [columnParagraph]
        columnList.children = [column]

        let table = Block(order: 2, type: .table, note: note)
        context.insert(table)
        let tableRow = Block(order: 0, type: .tableRow, note: note, parent: table)
        context.insert(tableRow)
        let tableCell = Block(
            order: 0,
            type: .tableCell,
            text: RichText(plainText: "Cellule"),
            note: note,
            parent: tableRow
        )
        context.insert(tableCell)
        tableRow.children = [tableCell]
        table.children = [tableRow]

        let imageBlock = Block(order: 3, type: .image, note: note)
        context.insert(imageBlock)
        let attachment = SlateModel.Attachment(
            filename: "photo.jpg",
            uti: "public.jpeg",
            data: Data([0xFF, 0xD8, 0xFF]),
            width: 800,
            height: 600,
            block: imageBlock
        )
        context.insert(attachment)
        imageBlock.attachment = attachment

        note.blocks = [paragraph, columnList, table, imageBlock]
        note.refreshDerivedText()
        try? context.save()
        return note
    }

    /// Tous les ids (`Block`) presents dans l'arbre `blocks`, recursivement.
    static func allBlockIDs(of note: Note) -> Set<UUID> {
        var ids: Set<UUID> = []
        func visit(_ blocks: [Block]) {
            for block in blocks {
                ids.insert(block.id)
                visit(block.children ?? [])
            }
        }
        visit(note.blocks ?? [])
        return ids
    }

    /// Parcours en profondeur trie par `order` a chaque niveau (voir la documentation
    /// de `Block.order` : SwiftData ne garantit aucun ordre d'insertion sur une
    /// relation to-many, seul `order` fait foi).
    static func allBlocks(of note: Note) -> [Block] {
        var result: [Block] = []
        func visit(_ blocks: [Block]) {
            for block in blocks.sorted(by: { $0.order < $1.order }) {
                result.append(block)
                visit(block.children ?? [])
            }
        }
        visit(note.blocks ?? [])
        return result
    }

    static func daysBefore(_ days: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
    }
}
