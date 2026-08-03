import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Tests de Phase 4 (arbitrage 2 de Cyril) : le champ `Folder.colorIndex` et son API
/// typee `Folder.colorToken`, la gestion des index hors bornes, et la mutation
/// exposee par `SidebarNavigation.setColor(_:for:)`.
@MainActor
struct FolderColorTests {

    // MARK: - `colorToken` : lecture/ecriture typee

    @Test
    func colorTokenIsNilByDefault() {
        let folder = Folder(name: "Sans couleur")
        #expect(folder.colorIndex == nil)
        #expect(folder.colorToken == nil)
    }

    @Test
    func settingColorTokenWritesTheMatchingRawValue() {
        let folder = Folder(name: "Violet")
        folder.colorToken = .purple

        #expect(folder.colorIndex == FolderColorToken.purple.rawValue)
        #expect(folder.colorToken == .purple)
    }

    @Test
    func clearingColorTokenWithNilResetsColorIndex() {
        let folder = Folder(name: "Rouge", colorIndex: FolderColorToken.red.rawValue)
        #expect(folder.colorToken == .red)

        folder.colorToken = nil

        #expect(folder.colorIndex == nil)
        #expect(folder.colorToken == nil)
    }

    // MARK: - Bornes de la palette (8 entrees, `design/tokens.md` §7/§8)

    @Test
    func paletteHasEightEntriesMatchingDesignTokens() {
        #expect(FolderColorToken.allCases.count == 8)
        #expect(FolderColorToken.allCases.map(\.rawValue) == Array(0...7))
    }

    @Test
    func outOfBoundsColorIndexResolvesToNilRatherThanCrashingOrGuessing() {
        // Simule un index ecrit par une version future de l'app (palette elargie) puis
        // relu par la version courante - scenario reel avec CloudKit. `colorToken` doit
        // se replier sur `nil`, exactement comme "aucun choix utilisateur", pas planter
        // ni retomber sur un cas arbitraire de la palette.
        let folder = Folder(name: "Futuriste", colorIndex: 99)
        #expect(folder.colorToken == nil)

        let negative = Folder(name: "Negatif", colorIndex: -1)
        #expect(negative.colorToken == nil)
    }

    // MARK: - `SidebarNavigation.setColor` : mutation persistee, verifiee par fetch reel

    @Test
    func setColorPersistsAndIsReadableAfterRefetch() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        let folder = Folder(name: "Roadmap", space: space)
        for item in [workspace, space, folder] as [any PersistentModel] { context.insert(item) }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        try navigation.setColor(.green, for: folder)

        let freshContext = ModelContext(container)
        let refetched = try #require(
            try freshContext.fetch(FetchDescriptor<Folder>()).first { $0.name == "Roadmap" }
        )
        #expect(refetched.colorToken == .green)
        #expect(refetched.colorIndex == FolderColorToken.green.rawValue)

        try navigation.setColor(nil, for: refetched)
        #expect(refetched.colorToken == nil)
    }
}
