import Foundation

extension RhoeMarkdownKit.Configuration {
    /// Create a configuration by modifying the default configuration.
    ///
    /// Example:
    /// ```swift
    /// let config = RhoeMarkdownKit.Configuration.build {
    ///     $0.enableTables = true
    ///     $0.enableCitations = true
    ///     $0.enableSmartPunctuation = false
    /// }
    /// ```
    public static func build(_ configure: (inout Builder) -> Void) -> Self {
        var builder = Builder()
        configure(&builder)
        return builder.build()
    }

    /// Mutable builder for Configuration.
    public struct Builder: Sendable {
        // Core extensions
        public var enableTables: Bool = true
        public var enableStrikethrough: Bool = true
        public var enableTaskLists: Bool = true
        public var enableAutolinks: Bool = true
        public var enableSmartPunctuation: Bool = false

        // Sprint 1: reserved types
        public var enableSuperscript: Bool = true
        public var enableSubscript: Bool = true
        public var enableHighlight: Bool = true
        public var enableFencedDivs: Bool = true

        // Sprint 2: extended inline
        public var enableInlineFootnotes: Bool = true
        public var enableCitations: Bool = true
        public var enableCrossReferences: Bool = true

        // Sprint 3: tables
        public var enableGridTables: Bool = true
        public var enableTableCaptions: Bool = true
        public var enableYAMLFrontmatter: Bool = true

        // Sprint 5: academic
        public var enableFancyLists: Bool = true
        public var enableLineBlocks: Bool = true
        public var enableRawInlines: Bool = true
        public var enableAbbreviations: Bool = true
        public var enableWikilinks: Bool = true

        // Sprint 4: core authoring
        public var enableAutoIdentifiers: Bool = true
        public var enableImplicitFigures: Bool = true
        public var enableImplicitHeaderReferences: Bool = true
        public var enableIntrawordUnderscores: Bool = true

        // RhoeMarkdown extensions
        public var enableVisualBlocks: Bool = true
        public var enableTransclusions: Bool = true
        public var enableAnnotations: Bool = true
        public var enableSchemaIslands: Bool = true
        public var enableComponents: Bool = true
        public var enablePhase1Preprocessing: Bool = true
        public var allowGeneratedSemanticTransforms: Bool = false
        public var enablePhase2Transforms: Bool = true
        public var enableCoreExpressions: Bool = true
        public var enableInputBindings: Bool = true

        public init() {}

        public func build() -> RhoeMarkdownKit.Configuration {
            RhoeMarkdownKit.Configuration(
                enableTables: enableTables,
                enableStrikethrough: enableStrikethrough,
                enableTaskLists: enableTaskLists,
                enableAutolinks: enableAutolinks,
                enableSmartPunctuation: enableSmartPunctuation,
                enableSuperscript: enableSuperscript,
                enableSubscript: enableSubscript,
                enableHighlight: enableHighlight,
                enableFencedDivs: enableFencedDivs,
                enableInlineFootnotes: enableInlineFootnotes,
                enableCitations: enableCitations,
                enableCrossReferences: enableCrossReferences,
                enableGridTables: enableGridTables,
                enableTableCaptions: enableTableCaptions,
                enableYAMLFrontmatter: enableYAMLFrontmatter,
                enableFancyLists: enableFancyLists,
                enableLineBlocks: enableLineBlocks,
                enableRawInlines: enableRawInlines,
                enableAbbreviations: enableAbbreviations,
                enableWikilinks: enableWikilinks,
                enableAutoIdentifiers: enableAutoIdentifiers,
                enableImplicitFigures: enableImplicitFigures,
                enableImplicitHeaderReferences: enableImplicitHeaderReferences,
                enableIntrawordUnderscores: enableIntrawordUnderscores,
                enableVisualBlocks: enableVisualBlocks,
                enableTransclusions: enableTransclusions,
                enableAnnotations: enableAnnotations,
                enableSchemaIslands: enableSchemaIslands,
                enableComponents: enableComponents,
                enablePhase1Preprocessing: enablePhase1Preprocessing,
                allowGeneratedSemanticTransforms: allowGeneratedSemanticTransforms,
                enablePhase2Transforms: enablePhase2Transforms,
                enableCoreExpressions: enableCoreExpressions,
                enableInputBindings: enableInputBindings
            )
        }
    }
}
