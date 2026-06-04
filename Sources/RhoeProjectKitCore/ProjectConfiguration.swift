import Foundation
import RhoeMarkdownModel

/// Root configuration for a RhoeProject, loaded from `rhoe.project.yaml`.
public struct ProjectConfiguration: Sendable, Equatable {
    public let schemaVersion: Int
    public let project: ProjectMetadata
    public let paths: PathConfiguration
    public let site: SiteConfiguration
    public let collections: [String: CollectionDefinition]
    public let defaults: [DefaultScope]
    public let navigation: NavigationConfiguration
    public let targets: [String: TargetDefinition]
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
    ) {
        self.schemaVersion = schemaVersion
        self.project = project
        self.paths = paths
        self.site = site
        self.collections = collections
        self.defaults = defaults
        self.navigation = navigation
        self.targets = targets
        self.profiles = profiles
    }
}

/// Project metadata (the `project:` block).
public struct ProjectMetadata: Sendable, Equatable {
    public let id: String
    public let name: String
    public let title: String?
    public let description: String?
    public let language: String
    public let timezone: String?
    public let version: String?

    public init(
        id: String = "untitled",
        name: String = "Untitled Project",
        title: String? = nil,
        description: String? = nil,
        language: String = "en",
        timezone: String? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.description = description
        self.language = language
        self.timezone = timezone
        self.version = version
    }
}

/// Directory path configuration (the `paths:` block).
public struct PathConfiguration: Sendable, Equatable {
    public let source: String
    public let data: String
    public let layouts: String
    public let includes: String
    public let assets: String
    public let output: String
    public let build: String
    public let cache: String

    public init(
        source: String = ".",
        data: String = "_data",
        layouts: String = "_layouts",
        includes: String = "_includes",
        assets: String = "assets",
        output: String = "_site",
        build: String = ".build",
        cache: String = ".cache"
    ) {
        self.source = source
        self.data = data
        self.layouts = layouts
        self.includes = includes
        self.assets = assets
        self.output = output
        self.build = build
        self.cache = cache
    }
}

/// Site-level configuration (the `site:` block).
public struct SiteConfiguration: Sendable, Equatable {
    public let url: String?
    public let title: String?
    public let subtitle: String?
    public let author: AuthorInfo?
    public let logo: String?
    public let favicon: String?
    public let locale: String?

    public init(
        url: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        author: AuthorInfo? = nil,
        logo: String? = nil,
        favicon: String? = nil,
        locale: String? = nil
    ) {
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.logo = logo
        self.favicon = favicon
        self.locale = locale
    }
}

/// Author information.
public struct AuthorInfo: Sendable, Equatable {
    public let name: String
    public let url: String?
    public let email: String?

    public init(name: String, url: String? = nil, email: String? = nil) {
        self.name = name
        self.url = url
        self.email = email
    }
}
