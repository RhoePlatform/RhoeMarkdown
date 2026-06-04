# Project API Reference

API documentation for project configuration, collection scanning, multi-target building, and navigation generation.

## Overview

The project API provides programmatic access to RhoeProject's multi-document orchestration layer. These types implement the configuration loading, document discovery, compilation, and output assembly stages of the project build pipeline.

The project API is defined in the `RhoeProjectKit` target. All types are `Sendable` and `Equatable`, following the codebase conventions for public types.

## ProjectConfiguration and ProjectConfigurationLoader

### ProjectConfiguration

The root configuration type, decoded from `rhoe.project.yaml`:

```swift
public struct ProjectConfiguration: Sendable, Equatable {
    /// Schema version (currently 1).
    public let schemaVersion: Int

    /// Project identity and metadata.
    public let project: ProjectMetadata

    /// Directory path configuration.
    public let paths: PathConfiguration

    /// Site-level configuration for web targets.
    public let site: SiteConfiguration

    /// Named document collections.
    public let collections: [String: CollectionDefinition]

    /// Scoped default frontmatter values.
    public let defaults: [DefaultScope]

    /// Navigation generation configuration.
    public let navigation: NavigationConfiguration

    /// Named build targets.
    public let targets: [String: TargetDefinition]

    /// Named build profiles.
    public let profiles: [String: BuildProfile]

    public init(
        schemaVersion: Int = 1,
        project: ProjectMetadata = .init(),
        paths: PathConfiguration = .init(),
        site: SiteConfiguration = .init(),
        collections: [String: CollectionDefinition] = [:],
        defaults: [DefaultScope] = [],
        navigation: NavigationConfiguration = .init(),
        targets: [String: TargetDefinition] = [:],
        profiles: [String: BuildProfile] = [:]
    )
}
```

### ProjectMetadata

```swift
public struct ProjectMetadata: Sendable, Equatable {
    /// Project identifier (kebab-case, used in paths and URLs).
    public let id: String

    /// Human-readable project name.
    public let name: String

    /// Display title (defaults to name if not set).
    public let title: String?

    /// Project description.
    public let description: String?

    /// Primary language (ISO 639-1 code).
    public let language: String

    /// IANA timezone identifier.
    public let timezone: String?

    /// Project version string.
    public let version: String?

    public init(
        id: String = "untitled",
        name: String = "Untitled Project",
        title: String? = nil,
        description: String? = nil,
        language: String = "en",
        timezone: String? = nil,
        version: String? = nil
    )
}
```

### PathConfiguration

```swift
public struct PathConfiguration: Sendable, Equatable {
    /// Source root directory.
    public let source: String       // default: "."

    /// Data files directory.
    public let data: String         // default: "_data"

    /// Layout templates directory.
    public let layouts: String      // default: "_layouts"

    /// Include templates directory.
    public let includes: String     // default: "_includes"

    /// Static assets directory.
    public let assets: String       // default: "assets"

    /// Build output directory.
    public let output: String       // default: "_site"

    /// Build intermediates directory.
    public let build: String        // default: ".build"

    /// Cache directory.
    public let cache: String        // default: ".cache"

    public init(
        source: String = ".",
        data: String = "_data",
        layouts: String = "_layouts",
        includes: String = "_includes",
        assets: String = "assets",
        output: String = "_site",
        build: String = ".build",
        cache: String = ".cache"
    )
}
```

### ProjectConfigurationLoader

```swift
public struct ProjectConfigurationLoader: Sendable {
    public init()

    /// Load configuration from a YAML file URL.
    ///
    /// Reads the file, parses YAML using the built-in frontmatter parser,
    /// and decodes all sections into typed configuration structs.
    ///
    /// - Parameter url: The `rhoe.project.yaml` file URL.
    /// - Returns: The decoded project configuration.
    public func load(from url: URL) throws -> ProjectConfiguration

    /// Load configuration from a YAML string.
    ///
    /// Useful for testing or programmatic configuration generation.
    ///
    /// - Parameter yamlString: The YAML configuration string.
    /// - Returns: The decoded project configuration.
    public func load(from yamlString: String) throws -> ProjectConfiguration
}
```

## CollectionScanner and CollectionDocument

### CollectionScanner

```swift
public struct CollectionScanner: Sendable {
    public init()

    /// Scan a collection directory for markdown documents.
    ///
    /// Recursively enumerates the collection directory, finding all `.md` and
    /// `.markdown` files. Hidden files and directories are skipped.
    ///
    /// - Parameters:
    ///   - collectionPath: Relative path to the collection directory.
    ///   - collectionName: The collection name.
    ///   - projectRoot: The project root URL.
    /// - Returns: Discovered documents sorted by relative path.
    public func scan(
        collectionPath: String,
        collectionName: String,
        projectRoot: URL
    ) throws -> [DiscoveredDocument]
}

public struct DiscoveredDocument: Sendable, Equatable {
    /// Absolute URL to the document file.
    public let url: URL

    /// Path relative to the collection directory.
    public let relativePath: String

    /// The collection this document belongs to.
    public let collectionName: String
}
```

### CollectionDocument

```swift
public struct CollectionDocument: Sendable, Equatable, Identifiable {
    /// Unique document identifier derived from the relative path.
    public let id: String

    /// Absolute URL to the document file.
    public let url: URL

    /// Path relative to the collection directory.
    public let relativePath: String

    /// The collection this document belongs to.
    public let collectionName: String

    /// Extracted frontmatter values.
    public let frontmatter: [String: RhoeMarkdownKit.YAMLValue]

    // Convenience accessors for common frontmatter keys:

    /// Document title from frontmatter.
    public var title: String? { get }

    /// Document date from frontmatter.
    public var date: Date? { get }

    /// Sort weight from frontmatter.
    public var weight: Int? { get }

    /// Layout template name from frontmatter.
    public var layout: String? { get }

    /// URL slug override from frontmatter.
    public var slug: String? { get }

    /// Whether this is a draft document.
    public var draft: Bool { get }

    /// Tag list from frontmatter.
    public var tags: [String] { get }

    /// Create from a discovered document with extracted frontmatter.
    public init(
        from discovered: DiscoveredDocument,
        frontmatter: [String: RhoeMarkdownKit.YAMLValue]
    )
}
```

### CollectionDefinition

```swift
public struct CollectionDefinition: Sendable, Equatable {
    /// Relative path to the collection directory.
    public let path: String

    /// Whether documents in this collection generate output files.
    public let output: Bool

    /// Permalink pattern for generated URLs.
    public let permalink: String?

    /// Frontmatter key to sort documents by.
    public let sortBy: String?

    /// Whether to reverse the sort order.
    public let reverse: Bool

    /// Default frontmatter values for documents in this collection.
    public let defaults: [String: RhoeMarkdownKit.YAMLValue]

    /// Target roles this collection participates in.
    public let targetRoles: [String]

    public init(
        path: String,
        output: Bool = true,
        permalink: String? = nil,
        sortBy: String? = nil,
        reverse: Bool = false,
        defaults: [String: RhoeMarkdownKit.YAMLValue] = [:],
        targetRoles: [String] = []
    )
}
```

## ProjectBuilder and TargetBuilder

### ProjectBuilder

```swift
public struct ProjectBuilder: Sendable {
    public init()

    /// Build a single target.
    ///
    /// Compiles all documents in the target's collections, applies projection
    /// filtering, and writes output to the target's output directory.
    /// Documents are compiled in parallel using Swift concurrency.
    ///
    /// - Parameters:
    ///   - targetName: The target name from the configuration.
    ///   - graph: The project graph with all resolved documents.
    ///   - projectRoot: The project root URL.
    /// - Returns: Build result with metrics and diagnostics.
    public func build(
        target targetName: String,
        graph: ProjectGraph,
        projectRoot: URL
    ) async throws -> BuildResult

    /// Build all enabled targets.
    ///
    /// Iterates over all targets in the configuration, skipping disabled ones.
    ///
    /// - Parameters:
    ///   - graph: The project graph.
    ///   - projectRoot: The project root URL.
    /// - Returns: Array of build results, one per target.
    public func buildAll(
        graph: ProjectGraph,
        projectRoot: URL
    ) async throws -> [BuildResult]
}
```

### BuildResult

```swift
public struct BuildResult: Sendable {
    /// The target name.
    public let targetName: String

    /// The target type.
    public let targetType: TargetType

    /// Number of documents successfully compiled.
    public let documentsBuilt: Int

    /// The output directory URL.
    public let outputDirectory: URL

    /// Compilation diagnostics (info, warning, error).
    public let diagnostics: [ProjectDiagnostic]

    /// Build timing metrics.
    public let timing: BuildTiming
}

public struct BuildTiming: Sendable {
    /// Total wall-clock build duration in seconds.
    public let totalDuration: TimeInterval

    /// Time spent parsing documents.
    public let parseTime: TimeInterval

    /// Time spent rendering output.
    public let renderTime: TimeInterval

    public init(
        totalDuration: TimeInterval,
        parseTime: TimeInterval = 0,
        renderTime: TimeInterval = 0
    )
}

public struct ProjectDiagnostic: Sendable {
    public enum Level: Sendable {
        case info, warning, error
    }

    public let level: Level
    public let message: String
    public let documentId: String?
    public let targetName: String?

    public static func info(_ message: String) -> ProjectDiagnostic
    public static func warning(_ message: String) -> ProjectDiagnostic
    public static func error(_ message: String) -> ProjectDiagnostic
}
```

### TargetDefinition

```swift
public struct TargetDefinition: Sendable, Equatable {
    /// The target output type.
    public let type: TargetType

    /// Whether this target is enabled for building.
    public let enabled: Bool

    /// Custom output directory (overrides global paths.output).
    public let outputDir: String?

    /// Collection names included in this target.
    public let collections: [String]

    /// Output format override (e.g., "html", "pdf", "typst").
    public let outputFormat: String?

    /// Target-specific navigation overrides.
    public let navigation: TargetNavigationOverride?

    /// Document assembly rules (for book/report targets).
    public let assembly: AssemblyRules?

    /// Projection visibility label.
    public let visibility: String?
}

public enum TargetType: String, Sendable, Equatable, CaseIterable {
    case staticSite = "static_site"
    case docsSite = "docs_site"
    case wikiSite = "wiki_site"
    case book
    case report
    case brochure
    case deck
    case singleFileHTML = "single_file_html"
    case llmBundle = "llm_bundle"
}
```

## NavigationGenerator and NavigationTree

### NavigationGenerator

```swift
public struct NavigationGenerator: Sendable {
    public init()

    /// Generate a navigation tree for a target.
    ///
    /// The navigation mode determines how the tree is constructed:
    /// - `auto`: From filesystem hierarchy and frontmatter weights
    /// - `explicit`: From YAML configuration
    /// - `summary`: From SUMMARY.md file
    /// - `sidebar`: Collapsible sidebar with depth limit
    /// - `tree`: Full expandable tree
    ///
    /// - Parameters:
    ///   - mode: The navigation generation mode.
    ///   - documents: The documents to include in navigation.
    ///   - projectRoot: The project root URL.
    /// - Returns: The generated navigation tree.
    public func generate(
        mode: NavigationMode,
        documents: [CollectionDocument],
        projectRoot: URL
    ) -> NavigationTree
}

public enum NavigationMode: String, Sendable, Equatable {
    case auto
    case explicit
    case summary
    case sidebar
    case tree
}
```

### NavigationTree

```swift
public struct NavigationTree: Sendable, Equatable {
    /// Top-level navigation items.
    public let items: [NavigationItem]

    /// Create a tree with the given items.
    public init(items: [NavigationItem] = [])

    /// Total number of items including all nested children.
    public var totalCount: Int { get }
}

public struct NavigationItem: Sendable, Equatable {
    /// Display title.
    public let title: String

    /// URL for navigation (nil for section headers).
    public let url: String?

    /// Associated document ID (nil for section headers).
    public let documentId: String?

    /// Child navigation items (for nested sections).
    public let children: [NavigationItem]

    /// Sort weight (lower values appear first).
    public let weight: Int?

    /// Total count including self and all descendants.
    public var totalCount: Int { get }

    public init(
        title: String,
        url: String? = nil,
        documentId: String? = nil,
        children: [NavigationItem] = [],
        weight: Int? = nil
    )
}
```

### NavigationConfiguration

```swift
public struct NavigationConfiguration: Sendable, Equatable {
    /// The navigation generation mode.
    public let mode: NavigationMode

    /// Sidebar-specific configuration (used when mode is .sidebar).
    public let sidebar: SidebarConfiguration?

    public init(
        mode: NavigationMode = .auto,
        sidebar: SidebarConfiguration? = nil
    )
}

public struct SidebarConfiguration: Sendable, Equatable {
    /// Whether sidebar sections are collapsible.
    public let collapsible: Bool

    /// Maximum nesting depth for navigation items.
    public let maxDepth: Int

    /// Whether to show icons alongside navigation items.
    public let showIcons: Bool

    public init(
        collapsible: Bool = true,
        maxDepth: Int = 3,
        showIcons: Bool = false
    )
}
```

### ProjectGraph

```swift
public struct ProjectGraph: Sendable {
    /// The project configuration.
    public let configuration: ProjectConfiguration

    /// All documents across all collections.
    public let allDocuments: [CollectionDocument]

    /// Create a project graph by scanning all collections.
    ///
    /// - Parameters:
    ///   - configuration: The project configuration.
    ///   - projectRoot: The project root URL.
    public init(configuration: ProjectConfiguration, projectRoot: URL) throws

    /// Get documents for a specific target.
    ///
    /// Returns documents from collections listed in the target's configuration,
    /// filtered to exclude drafts and respecting collection sort order.
    ///
    /// - Parameter targetName: The target name.
    /// - Returns: Documents for the target, sorted per collection settings.
    public func documents(for targetName: String) -> [CollectionDocument]

    /// Get documents for a specific collection.
    ///
    /// - Parameter collectionName: The collection name.
    /// - Returns: Documents in the collection, sorted per settings.
    public func documents(inCollection collectionName: String) -> [CollectionDocument]
}
```

## See Also

- <doc:ProjectConfiguration>
- <doc:BuildingProjects>
- <doc:APIReference>
- <doc:GettingStarted>
