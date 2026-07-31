import SwiftUI
import SlateModel
import SlateUI

/// Ligne d'un dossier dans l'arbre de la sidebar, recursive (s'auto-appelle pour ses
/// sous-dossiers), conformement a `docs/03_sidebar_navigation.md` ("Vue FolderRow qui
/// s'auto-appelle pour les subfolders").
///
/// `allFolders` est transmis explicitement a travers la recursion plutot que
/// re-interroge a chaque niveau : `SidebarView` porte l'unique `@Query` sur `Folder`
/// (spec : "alimentee par @Query sur Space/Folder"), et chaque `FolderRow` filtre ce
/// meme tableau en memoire pour trouver ses propres enfants. Un seul point de verite
/// reactif, pas une requete SwiftData par ligne visible.
///
/// ## Compteur / menu : meme emplacement, jamais les deux a la fois
///
/// La spec E2 (catalogue d'etats) montre que le compteur de notes et le menu `...`
/// occupent le meme emplacement en fin de ligne : le menu REMPLACE le compteur au
/// survol ou sur selection, il ne s'ajoute pas a cote. `SidebarRow` ne remonte pas son
/// etat de survol interne a l'appelant (il pilote seulement son propre fond) : cette
/// vue suit donc son PROPRE survol (`isRowHovering`), independant de celui de
/// `SidebarRow`, uniquement pour decider quoi placer dans `trailing`.
struct FolderRow: View {
    let entry: SidebarFolderEntry
    let allFolders: [Folder]
    @FocusState.Binding var focusedFolderID: Folder.ID?

    let onRequestNewSubfolder: (Folder) -> Void
    let onRequestRename: (Folder) -> Void
    let onRequestChangeIcon: (Folder) -> Void
    let onRequestDelete: (Folder) -> Void

    @Environment(\.appState) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.slateIsOnAccentFill) private var isOnAccentFill
    @State private var isRowHovering = false

    private var folder: Folder { entry.folder }

    private var subfolders: [Folder] {
        allFolders
            .filter { $0.parent?.id == folder.id }
            .sorted(by: Folder.sidebarOrder)
    }

    private var isSelected: Bool {
        appState.selectedFolder?.id == folder.id
    }

    private var isFocused: Bool {
        focusedFolderID == folder.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if folder.isExpanded {
                ForEach(subfolders) { child in
                    FolderRow(
                        entry: SidebarFolderEntry(folder: child, indentLevel: entry.indentLevel + 1),
                        allFolders: allFolders,
                        focusedFolderID: $focusedFolderID,
                        onRequestNewSubfolder: onRequestNewSubfolder,
                        onRequestRename: onRequestRename,
                        onRequestChangeIcon: onRequestChangeIcon,
                        onRequestDelete: onRequestDelete
                    )
                }
            }
        }
    }

    private var row: some View {
        SidebarRow(
            title: folder.name,
            indentLevel: entry.indentLevel,
            isSelected: isSelected,
            isFocused: isFocused,
            leading: { leadingContent },
            trailing: { trailingContent }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedFolder = folder
            focusedFolderID = folder.id
        }
        .onHover { isRowHovering = $0 }
        .focusable()
        .focused($focusedFolderID, equals: folder.id)
        .contextMenu { menuContent }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(FolderExpansionAccessibilityAction(
            hasChildren: !subfolders.isEmpty,
            isExpanded: folder.isExpanded,
            toggle: toggleExpansion
        ))
    }

    @ViewBuilder
    private var leadingContent: some View {
        HStack(spacing: Spacing.xs) {
            if subfolders.isEmpty {
                Color.clear
                    .frame(width: SlateGeometry.sidebarChevronHitArea, height: SlateGeometry.sidebarChevronHitArea)
            } else {
                DisclosureChevron(isExpanded: folder.isExpanded) {
                    toggleExpansion()
                }
            }
            Image(systemName: folder.iconName)
                .slateIconFont(SlateGeometry.sidebarIconSize, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.foreground(folderTintColor, onAccentFill: isOnAccentFill))
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if isRowHovering || isSelected {
            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis")
                    .slateIconFont(SlateGeometry.sidebarMenuGlyphSize, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(SlateColor.foreground(SlateColor.textTertiary, onAccentFill: isOnAccentFill))
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel(String(localized: "sidebar.folder.moreActions", bundle: .module))
        } else {
            SidebarCounter(count: folder.noteCount, accessibilityLabel: folderNoteCountAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        Button {
            onRequestNewSubfolder(folder)
        } label: {
            Label(
                String(localized: "sidebar.folder.menu.newSubfolder", bundle: .module),
                systemImage: "folder.badge.plus"
            )
        }
        Button {
            onRequestRename(folder)
        } label: {
            Label(String(localized: "sidebar.folder.menu.rename", bundle: .module), systemImage: "pencil")
        }
        Button {
            onRequestChangeIcon(folder)
        } label: {
            Label(String(localized: "sidebar.folder.menu.changeIcon", bundle: .module), systemImage: "paintpalette")
        }
        Divider()
        Button(role: .destructive) {
            onRequestDelete(folder)
        } label: {
            Label(String(localized: "sidebar.folder.menu.delete", bundle: .module), systemImage: "trash")
        }
    }

    /// Teinte de l'icone hors selection. `Folder` (contrat `SlateModel` de cette
    /// phase) n'expose que `iconName`, aucune propriete de couleur persistee : la
    /// spec visuelle E2 montre pourtant une couleur par dossier. Faute de champ
    /// modele pour la stocker, cette teinte est deduite deterministement de l'`id`
    /// du dossier (purement presentationnelle, non configurable, non persistee) pour
    /// obtenir malgre tout une variete visuelle proche de la maquette. Voir le
    /// rapport de phase : ajouter un vrai champ de couleur a `Folder` est une decision
    /// pour `data-modeler`, hors perimetre de cette tache.
    private var folderTintColor: Color {
        let palette = SlateFolderColor.allCases
        let index = abs(folder.id.hashValue) % palette.count
        return palette[index].color
    }

    private func toggleExpansion() {
        folder.isExpanded.toggle()
        try? modelContext.save()
    }

    private var accessibilityLabelText: String {
        var components = [folder.name]
        if !subfolders.isEmpty {
            components.append(
                folder.isExpanded
                    ? String(localized: "sidebar.folder.accessibility.expanded", bundle: .module)
                    : String(localized: "sidebar.folder.accessibility.collapsed", bundle: .module)
            )
        }
        components.append(folderNoteCountAccessibilityLabel)
        return components.joined(separator: ", ")
    }

    private var folderNoteCountAccessibilityLabel: String {
        let count = folder.noteCount
        switch count {
        case 0:
            return String(localized: "sidebar.folder.accessibility.notesCount.zero", bundle: .module)
        case 1:
            return String(localized: "sidebar.folder.accessibility.notesCount.one", bundle: .module)
        default:
            let template = String(localized: "sidebar.folder.accessibility.notesCount.many", bundle: .module)
            return String(format: template, count)
        }
    }
}

/// Ajoute l'action VoiceOver "Deplier"/"Replier" uniquement si le dossier a des
/// sous-dossiers (spec Accessibilite : "action Deplier/Replier"). Isole dans un
/// `ViewModifier` pour eviter un `if/else` dupliquant l'arbre de vues dans `FolderRow`.
private struct FolderExpansionAccessibilityAction: ViewModifier {
    let hasChildren: Bool
    let isExpanded: Bool
    let toggle: () -> Void

    func body(content: Content) -> some View {
        if hasChildren {
            content.accessibilityAction(
                named: Text(
                    isExpanded
                        ? String(localized: "sidebar.folder.accessibility.collapseAction", bundle: .module)
                        : String(localized: "sidebar.folder.accessibility.expandAction", bundle: .module)
                )
            ) {
                toggle()
            }
        } else {
            content
        }
    }
}
