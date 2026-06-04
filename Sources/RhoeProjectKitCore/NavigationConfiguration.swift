import Foundation

/// Supported navigation modes.
public enum NavigationMode: String, Sendable, Equatable {
    case auto
    case explicit
    case summary
    case sidebar
    case tree
}

/// Navigation configuration for the project.
public struct NavigationConfiguration: Sendable, Equatable {
    public let mode: NavigationMode
    public let sidebar: SidebarConfiguration?

    public init(
        mode: NavigationMode = .auto,
        sidebar: SidebarConfiguration? = nil
    ) {
        self.mode = mode
        self.sidebar = sidebar
    }
}

/// Sidebar-specific navigation configuration.
public struct SidebarConfiguration: Sendable, Equatable {
    public let style: String
    public let collapsible: Bool
    public let maxDepth: Int

    public init(style: String = "tree", collapsible: Bool = true, maxDepth: Int = 3) {
        self.style = style
        self.collapsible = collapsible
        self.maxDepth = maxDepth
    }
}

/// Per-target navigation override.
public struct TargetNavigationOverride: Sendable, Equatable {
    public let mode: NavigationMode?
    public let summaryFile: String?

    public init(mode: NavigationMode? = nil, summaryFile: String? = nil) {
        self.mode = mode
        self.summaryFile = summaryFile
    }
}
