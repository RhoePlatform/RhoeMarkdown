import Foundation

/// Supported output target types for multi-target publication.
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

/// Definition of an output target within a project.
public struct TargetDefinition: Sendable, Equatable {
    public let type: TargetType
    public let enabled: Bool
    public let outputDir: String?
    public let collections: [String]
    public let outputFormat: String?
    public let navigation: TargetNavigationOverride?
    public let assembly: AssemblyRules?
    public let visibility: String?

    public init(
        type: TargetType,
        enabled: Bool = true,
        outputDir: String? = nil,
        collections: [String] = [],
        outputFormat: String? = nil,
        navigation: TargetNavigationOverride? = nil,
        assembly: AssemblyRules? = nil,
        visibility: String? = nil
    ) {
        self.type = type
        self.enabled = enabled
        self.outputDir = outputDir
        self.collections = collections
        self.outputFormat = outputFormat
        self.navigation = navigation
        self.assembly = assembly
        self.visibility = visibility
    }
}

/// Rules for assembling multi-document output (books, reports).
public struct AssemblyRules: Sendable, Equatable {
    public let order: String?
    public let frontMatter: [String]
    public let backMatter: [String]
    public let chapterBreak: Bool
    public let continuous: Bool

    public init(
        order: String? = nil,
        frontMatter: [String] = [],
        backMatter: [String] = [],
        chapterBreak: Bool = true,
        continuous: Bool = false
    ) {
        self.order = order
        self.frontMatter = frontMatter
        self.backMatter = backMatter
        self.chapterBreak = chapterBreak
        self.continuous = continuous
    }
}
