import SwiftUI

/// Etat pur de bascule des colonnes de `MainWindowView` (spec E1, section "collapse -
/// 3 etats de colonnes" de `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html`).
///
/// ## Tension avec la spec visuelle, signalee explicitement
///
/// La maquette ne dessine que 3 etats discrets : par defaut (`.all`), sidebar masquee
/// (Cmd+1), mode focus (Cmd+Ctrl+F). Ces 3 etats se representent exactement avec
/// `NavigationSplitViewVisibility` (`.all` / `.doubleColumn` / `.detailOnly`), qui ne
/// peut masquer que les colonnes de tete (sidebar, puis sidebar+liste) : SwiftUI
/// n'expose aucun cas "masquer seulement la colonne liste en gardant la sidebar".
///
/// Le texte fonctionnel de cette phase demande en plus "Bascule liste sur Cmd+2",
/// independante de la sidebar. Comme ce 4e etat (sidebar visible, liste masquee)
/// n'existe pas dans l'enum SwiftUI, ce type le represente lui-meme avec deux
/// booleens independants (`isSidebarVisible`, `isListVisible`) plutot que de forcer
/// Cmd+2 a emprunter un des 3 etats de la maquette (ce qui masquerait aussi la
/// sidebar, contrairement a l'intention de la commande). `nativeVisibility` derive la
/// valeur a donner a `NavigationSplitView(columnVisibility:)` a partir de ces
/// booleens ; `isListColumnCollapsed` indique, quand `nativeVisibility == .all`, s'il
/// faut en plus reduire la largeur de la colonne liste a zero (`MainWindowView`
/// applique alors une largeur de colonne nulle plutot que le token
/// `NavigationLayout.listWidth`, animee comme le reste).
///
/// Le mode focus (Cmd+Ctrl+F) reste l'etat "autoritaire" de la maquette : il masque
/// sidebar ET liste via le mecanisme natif (`.detailOnly`), pas via la largeur nulle,
/// et il memorise l'etat de sidebar/liste pour le restaurer a la sortie du mode focus.
public struct ColumnLayoutState: Equatable, Sendable {
    public private(set) var isSidebarVisible: Bool
    public private(set) var isListVisible: Bool
    public private(set) var isFocusMode: Bool

    /// Etat de sidebar/liste memorise avant l'entree en mode focus, pour le restaurer
    /// exactement a la sortie plutot que de retomber systematiquement sur `.all`.
    private var preFocusSidebarVisible: Bool
    private var preFocusListVisible: Bool

    public init(isSidebarVisible: Bool = true, isListVisible: Bool = true, isFocusMode: Bool = false) {
        self.isSidebarVisible = isSidebarVisible
        self.isListVisible = isListVisible
        self.isFocusMode = isFocusMode
        self.preFocusSidebarVisible = isSidebarVisible
        self.preFocusListVisible = isListVisible
    }

    /// Etat par defaut : les 3 colonnes visibles (`.all` de la spec).
    public static let all = ColumnLayoutState()

    /// Cmd+1 : bascule la visibilite de la sidebar. Sans effet direct en mode focus
    /// (la sidebar en sort d'abord) pour eviter un etat incoherent (sidebar "visible"
    /// alors que le mode focus l'impose masquee).
    public mutating func toggleSidebar() {
        if isFocusMode {
            exitFocusMode()
            return
        }
        isSidebarVisible.toggle()
    }

    /// Cmd+2 : bascule la visibilite de la colonne liste, independamment de la
    /// sidebar. Meme regle qu'au-dessus en mode focus.
    public mutating func toggleList() {
        if isFocusMode {
            exitFocusMode()
            return
        }
        isListVisible.toggle()
    }

    /// Cmd+Ctrl+F : bascule le mode focus (sidebar + liste masquees, toolbar
    /// conservee - la toolbar n'est pas pilotee par cet etat, elle reste toujours
    /// affichee par `MainWindowView`).
    public mutating func toggleFocusMode() {
        if isFocusMode {
            exitFocusMode()
        } else {
            preFocusSidebarVisible = isSidebarVisible
            preFocusListVisible = isListVisible
            isFocusMode = true
        }
    }

    /// Force explicitement la visibilite de la sidebar, sans passer par la logique de
    /// bascule de `toggleSidebar()`. Reserve a la traduction inverse d'un changement
    /// externe de `NavigationSplitViewVisibility` (voir `MainWindowView.columnVisibilityBinding`) :
    /// contrairement a `toggleSidebar()`, n'a aucun effet sur le mode focus.
    public mutating func setSidebarVisible(_ visible: Bool) {
        isSidebarVisible = visible
    }

    private mutating func exitFocusMode() {
        isFocusMode = false
        isSidebarVisible = preFocusSidebarVisible
        isListVisible = preFocusListVisible
    }

    /// Valeur a donner au binding natif `NavigationSplitView(columnVisibility:)`.
    /// Ne represente que le masquage progressif depuis la tete (sidebar, puis
    /// sidebar+liste) : la liste seule masquee (sidebar visible) est geree a part par
    /// `isListColumnCollapsed`, pas par cette valeur.
    public var nativeVisibility: NavigationSplitViewVisibility {
        if isFocusMode {
            return .detailOnly
        }
        return isSidebarVisible ? .all : .doubleColumn
    }

    /// `true` si la colonne liste doit etre reduite a une largeur nulle en plus du
    /// binding natif (cas "liste masquee via Cmd+2" qui n'a pas d'equivalent dans
    /// `NavigationSplitViewVisibility` sauf quand le mode focus masque deja tout via
    /// `.detailOnly` - dans ce cas la reduction de largeur est sans effet visible mais
    /// reste coherente avec l'etat logique).
    public var isListColumnCollapsed: Bool {
        !isListVisible
    }
}
