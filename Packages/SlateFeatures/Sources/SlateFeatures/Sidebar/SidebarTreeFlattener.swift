import SlateModel

/// Une entree "aplatie" de l'arbre de dossiers, portant son niveau d'indentation et
/// le dossier qu'elle represente.
///
/// Type dedie plutot qu'un simple tuple : nomme a l'appel (`entry.folder`,
/// `entry.indentLevel`), et sert de granularite stable pour la navigation clavier
/// (`SidebarView` en tire l'ordre de deplacement haut/bas).
public struct SidebarFolderEntry: Equatable {
    public let folder: Folder
    public let indentLevel: Int

    public init(folder: Folder, indentLevel: Int) {
        self.folder = folder
        self.indentLevel = indentLevel
    }
}

extension SidebarFolderEntry: Identifiable {
    public var id: Folder.ID { folder.id }
}

/// Aplatit l'arbre de dossiers (recursif) en une liste ordonnee, en respectant l'etat
/// plie/deplie de chaque dossier (`Folder.isExpanded`) : les enfants d'un dossier
/// replie ne sont pas inclus.
///
/// Fonction pure (aucun acces `ModelContext`) : elle prend en entree des tableaux deja
/// resolus (par ex. issus de `SidebarNavigation.rootFolders(in:)` /
/// `SidebarNavigation.subfolders(of:)`, deja tries), ce qui la rend testable sans
/// dependance a SwiftUI ni a un `@MainActor` (voir `SidebarTreeFlattenerTests`).
///
/// Sert deux besoins :
/// - l'affichage recursif de `FolderRow` (le niveau d'indentation determine le
///   `indentLevel` passe a `SidebarRow`) ;
/// - la navigation clavier haut/bas de `SidebarView` (l'ordre de cette liste est
///   exactement l'ordre visuel des lignes visibles a l'ecran).
public enum SidebarTreeFlattener {
    public static func flatten(
        rootFolders: [Folder],
        subfoldersProvider: (Folder) -> [Folder]
    ) -> [SidebarFolderEntry] {
        var result: [SidebarFolderEntry] = []
        appendFolders(rootFolders, level: 0, subfoldersProvider: subfoldersProvider, into: &result)
        return result
    }

    private static func appendFolders(
        _ folders: [Folder],
        level: Int,
        subfoldersProvider: (Folder) -> [Folder],
        into result: inout [SidebarFolderEntry]
    ) {
        for folder in folders {
            result.append(SidebarFolderEntry(folder: folder, indentLevel: level))
            if folder.isExpanded {
                appendFolders(
                    subfoldersProvider(folder),
                    level: level + 1,
                    subfoldersProvider: subfoldersProvider,
                    into: &result
                )
            }
        }
    }
}
