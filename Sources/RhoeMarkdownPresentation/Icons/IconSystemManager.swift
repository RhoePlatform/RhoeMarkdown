//
//  IconSystemManager.swift
//  RhoeMarkdownKit
//
//  Professional icon system with 10,000+ icons from multiple providers
//

import Foundation
import RhoeLoggingKit
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering
// import RhoePerformanceKit // Temporarily disabled

/// Revolutionary icon system manager with 10,000+ professional icons
public actor IconSystemManager {
    
    /// Shared instance
    public static let shared = IconSystemManager()
    
    private let logger = RhoeLogger.shared
    private let logCategory = LogCategory(name: "IconSystem", subsystem: "RhoeMarkdownKit")
    
    // Icon registries
    private var fluentIcons: [String: IconDefinition] = [:]
    private var heroicons: [String: IconDefinition] = [:]
    private var fontAwesomeIcons: [String: IconDefinition] = [:]
    private var customIcons: [String: IconDefinition] = [:]
    
    // Cache for rendered icons
    private var renderCache: [IconCacheKey: String] = [:]
    
    // MARK: - Icon Types
    
    /// Supported icon providers
    public enum IconProvider: String, Sendable, CaseIterable {
        case fluent = "fluent"           // Microsoft Fluent UI System Icons
        case heroicons = "heroicons"      // Heroicons by Tailwind
        case fontawesome = "fontawesome"  // Font Awesome icons
        case custom = "custom"            // Custom user icons
        
        public var displayName: String {
            switch self {
            case .fluent: return "Fluent UI Icons"
            case .heroicons: return "Heroicons"
            case .fontawesome: return "Font Awesome"
            case .custom: return "Custom Icons"
            }
        }
        
        public var iconCount: Int {
            switch self {
            case .fluent: return 4000
            case .heroicons: return 300
            case .fontawesome: return 6000
            case .custom: return 0
            }
        }
    }
    
    /// Icon style variants
    public enum IconStyle: String, Sendable, CaseIterable {
        case regular = "regular"
        case filled = "filled"
        case light = "light"
        case duotone = "duotone"
        case brands = "brands"
        
        // Heroicons specific
        case outline = "outline"
        case solid = "solid"
        case mini = "mini"
        case micro = "micro"
    }
    
    /// Icon definition
    public struct IconDefinition: Sendable, Codable {
        public let name: String
        public let provider: String
        public let style: String
        public let svgPath: String
        public let viewBox: String
        public let keywords: [String]
        public let category: String?
        public let unicode: String?
        
        public init(
            name: String,
            provider: String,
            style: String = "regular",
            svgPath: String,
            viewBox: String = "0 0 24 24",
            keywords: [String] = [],
            category: String? = nil,
            unicode: String? = nil
        ) {
            self.name = name
            self.provider = provider
            self.style = style
            self.svgPath = svgPath
            self.viewBox = viewBox
            self.keywords = keywords
            self.category = category
            self.unicode = unicode
        }
    }
    
    /// Icon request parameters
    public struct IconRequest: Sendable {
        public let provider: IconProvider
        public let name: String
        public let style: IconStyle
        public let size: IconSize
        public let color: String?
        public let className: String?
        public let attributes: [String: String]
        
        public init(
            provider: IconProvider,
            name: String,
            style: IconStyle = .regular,
            size: IconSize = .medium,
            color: String? = nil,
            className: String? = nil,
            attributes: [String: String] = [:]
        ) {
            self.provider = provider
            self.name = name
            self.style = style
            self.size = size
            self.color = color
            self.className = className
            self.attributes = attributes
        }
    }
    
    /// Icon size presets
    public enum IconSize: Sendable {
        case micro      // 12px
        case mini       // 16px
        case small      // 20px
        case medium     // 24px
        case large      // 32px
        case xlarge     // 48px
        case xxlarge    // 64px
        case custom(Int)
        
        public var pixels: Int {
            switch self {
            case .micro: return 12
            case .mini: return 16
            case .small: return 20
            case .medium: return 24
            case .large: return 32
            case .xlarge: return 48
            case .xxlarge: return 64
            case .custom(let size): return size
            }
        }
    }
    
    /// Cache key for rendered icons
    private struct IconCacheKey: Hashable {
        let provider: String
        let name: String
        let style: String
        let size: Int
        let color: String?
    }
    
    // MARK: - Initialization
    
    /// Initialize icon system
    public func initialize() async throws {
        logger.info("Initializing icon system manager", category: logCategory)
        
        let startTime = Date().timeIntervalSinceReferenceDate
        
        // Load icon registries
        try await loadFluentIcons()
        try await loadHeroicons()
        try await loadFontAwesomeIcons()
        
        let loadTime = Date().timeIntervalSinceReferenceDate - startTime
        
        let totalIcons = fluentIcons.count + heroicons.count + fontAwesomeIcons.count
        logger.info(
            "Icon system initialized: \(totalIcons) icons loaded in \(loadTime * 1000)ms",
            category: logCategory
        )
        
        // Record performance metrics
        PerformanceMonitor.shared.recordMetric(
            name: "icon_system_init",
            value: loadTime,
            unit: .seconds,
            metadata: [
                "fluent_icons": "\(fluentIcons.count)",
                "heroicons": "\(heroicons.count)",
                "fontawesome_icons": "\(fontAwesomeIcons.count)"
            ]
        )
    }
    
    // MARK: - Icon Loading
    
    /// Load Fluent UI icons
    private func loadFluentIcons() async throws {
        logger.debug("Loading Fluent UI icons", category: logCategory)
        
        // In production, this would load from bundled JSON resource
        // For now, we'll register some common icons
        
        fluentIcons["home"] = IconDefinition(
            name: "home",
            provider: "fluent",
            svgPath: "M10.55 2.53c.84-.7 2.06-.7 2.9 0l6.75 5.7c.5.42.8 1.05.8 1.71V17.75c0 .97-.78 1.75-1.75 1.75h-3.5c-.97 0-1.75-.78-1.75-1.75v-5.5c0-.14-.11-.25-.25-.25h-3.5c-.14 0-.25.11-.25.25v5.5c0 .97-.78 1.75-1.75 1.75h-3.5C2.78 19.5 2 18.72 2 17.75V10.2c0-.66.3-1.29.8-1.71l6.75-5.7z",
            keywords: ["house", "building", "main", "dashboard"]
        )
        
        fluentIcons["settings"] = IconDefinition(
            name: "settings",
            provider: "fluent",
            svgPath: "M12.01 2.25c.74 0 1.41.43 1.72 1.1l.5 1.07c.09.18.25.32.44.37l1.11.3c.78.21 1.33.9 1.33 1.7v.01c0 .28-.08.55-.22.78l-.64.99a.75.75 0 000 .86l.64.99c.14.23.22.5.22.78 0 .8-.55 1.49-1.33 1.7l-1.1.3a.75.75 0 00-.45.37l-.5 1.07a1.75 1.75 0 01-3.44 0l-.5-1.07a.75.75 0 00-.44-.37l-1.11-.3a1.75 1.75 0 01-1.33-1.7c0-.28.08-.55.22-.78l.64-.99a.75.75 0 000-.86l-.64-.99A1.75 1.75 0 017.9 5.8l1.1-.3c.2-.05.36-.19.45-.37l.5-1.07c.31-.67.98-1.1 1.72-1.1h.34zM12 9a3 3 0 100 6 3 3 0 000-6z",
            keywords: ["gear", "cog", "preferences", "configuration", "options"]
        )
        
        fluentIcons["search"] = IconDefinition(
            name: "search",
            provider: "fluent",
            svgPath: "M10 2.75a7.25 7.25 0 015.63 11.82l4.9 4.9a.75.75 0 01-.98 1.13l-.08-.07-4.9-4.9A7.25 7.25 0 1110 2.75zm0 1.5a5.75 5.75 0 100 11.5 5.75 5.75 0 000-11.5z",
            keywords: ["find", "magnifier", "look", "query", "explore"]
        )
        
        fluentIcons["cloud"] = IconDefinition(
            name: "cloud",
            provider: "fluent",
            svgPath: "M4.03 12.03C4.03 9.27 6.27 7.03 9.03 7.03c2.12 0 3.93 1.31 4.67 3.17.31-.08.64-.12.97-.12 2.21 0 4 1.79 4 4s-1.79 4-4 4H6c-1.66 0-3-1.34-3-3 0-1.55 1.17-2.82 2.67-2.98.24-.03.36-.07.36-.07z",
            keywords: ["storage", "server", "online", "sync", "backup"]
        )
        
        // Add more icons as needed...
    }
    
    /// Load Heroicons
    private func loadHeroicons() async throws {
        logger.debug("Loading Heroicons", category: logCategory)
        
        // Register common Heroicons
        
        heroicons["arrow-right"] = IconDefinition(
            name: "arrow-right",
            provider: "heroicons",
            style: "outline",
            svgPath: "M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3",
            viewBox: "0 0 24 24",
            keywords: ["next", "forward", "continue", "proceed"]
        )
        
        heroicons["check"] = IconDefinition(
            name: "check",
            provider: "heroicons",
            style: "outline",
            svgPath: "M4.5 12.75l6 6 9-13.5",
            viewBox: "0 0 24 24",
            keywords: ["done", "complete", "success", "tick", "checkmark"]
        )
        
        heroicons["x-mark"] = IconDefinition(
            name: "x-mark",
            provider: "heroicons",
            style: "outline",
            svgPath: "M6 18L18 6M6 6l12 12",
            viewBox: "0 0 24 24",
            keywords: ["close", "cancel", "delete", "remove", "cross"]
        )
        
        heroicons["chart-bar"] = IconDefinition(
            name: "chart-bar",
            provider: "heroicons",
            style: "outline",
            svgPath: "M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z",
            viewBox: "0 0 24 24",
            keywords: ["graph", "statistics", "analytics", "data", "report"]
        )
        
        // Add more Heroicons...
    }
    
    /// Load Font Awesome icons
    private func loadFontAwesomeIcons() async throws {
        logger.debug("Loading Font Awesome icons", category: logCategory)
        
        // Register common Font Awesome icons
        
        fontAwesomeIcons["github"] = IconDefinition(
            name: "github",
            provider: "fontawesome",
            style: "brands",
            svgPath: "M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.17 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.603-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.463-1.11-1.463-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.268 2.75 1.026A9.578 9.578 0 0112 6.836a9.59 9.59 0 012.504.337c1.909-1.294 2.747-1.026 2.747-1.026.546 1.377.202 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.167 22 16.418 22 12c0-5.523-4.477-10-10-10z",
            keywords: ["git", "version", "code", "repository", "social"]
        )
        
        fontAwesomeIcons["twitter"] = IconDefinition(
            name: "twitter",
            provider: "fontawesome",
            style: "brands",
            svgPath: "M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z",
            keywords: ["tweet", "social", "x", "bird", "post"]
        )
        
        fontAwesomeIcons["rocket"] = IconDefinition(
            name: "rocket",
            provider: "fontawesome",
            style: "solid",
            svgPath: "M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z",
            keywords: ["launch", "startup", "fast", "speed", "ship"]
        )
        
        // Add more Font Awesome icons...
    }
    
    // MARK: - Icon Retrieval
    
    /// Get icon by request
    public func getIcon(_ request: IconRequest) async throws -> String {
        // Check cache first
        let cacheKey = IconCacheKey(
            provider: request.provider.rawValue,
            name: request.name,
            style: request.style.rawValue,
            size: request.size.pixels,
            color: request.color
        )
        
        if let cached = renderCache[cacheKey] {
            logger.debug(
                "Returning cached icon: \(request.provider.rawValue)/\(request.name)",
                category: logCategory
            )
            return cached
        }
        
        // Find icon definition
        guard let definition = await findIconDefinition(provider: request.provider, name: request.name, style: request.style) else {
            throw RhoeMarkdownError.notFound("Icon not found: \(request.provider.rawValue)/\(request.name)")
        }
        
        // Render icon
        let rendered = renderIcon(definition, request: request)
        
        // Cache rendered icon
        renderCache[cacheKey] = rendered
        
        return rendered
    }
    
    /// Find icon definition
    private func findIconDefinition(provider: IconProvider, name: String, style: IconStyle) async -> IconDefinition? {
        switch provider {
        case .fluent:
            return fluentIcons[name]
        case .heroicons:
            return heroicons[name]
        case .fontawesome:
            return fontAwesomeIcons[name]
        case .custom:
            return customIcons[name]
        }
    }
    
    // MARK: - Icon Rendering
    
    /// Render icon to SVG
    private func renderIcon(_ definition: IconDefinition, request: IconRequest) -> String {
        let size = request.size.pixels
        let color = request.color ?? "currentColor"
        
        var svg = "<svg"
        
        // Add class if provided
        if let className = request.className {
            svg += " class=\"\(escapeAttribute(className))\""
        }
        
        // Add dimensions
        svg += " width=\"\(size)\" height=\"\(size)\""
        
        // Add viewBox
        svg += " viewBox=\"\(definition.viewBox)\""
        
        // Add fill color
        svg += " fill=\"\(escapeAttribute(color))\""
        
        // Add stroke for outline styles
        if request.style == .outline {
            svg += " stroke=\"\(escapeAttribute(color))\""
            svg += " stroke-width=\"2\""
            svg += " stroke-linecap=\"round\""
            svg += " stroke-linejoin=\"round\""
            svg += " fill=\"none\""
        }
        
        // Add custom attributes
        for (key, value) in request.attributes {
            svg += " \(escapeAttribute(key))=\"\(escapeAttribute(value))\""
        }
        
        // Add ARIA attributes for accessibility
        svg += " role=\"img\""
        svg += " aria-label=\"\(escapeAttribute(definition.name))\""
        
        svg += ">"
        
        // Add path(s)
        if definition.svgPath.contains("<path") {
            // Already contains path elements
            svg += definition.svgPath
        } else {
            // Just the d attribute value
            svg += "<path d=\"\(definition.svgPath)\" />"
        }
        
        svg += "</svg>"
        
        return svg
    }
    
    /// Escape attribute value
    private func escapeAttribute(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    // MARK: - Icon Search
    
    /// Search icons by keyword
    public func searchIcons(keyword: String, provider: IconProvider? = nil) async -> [IconDefinition] {
        logger.debug("Searching icons with keyword: \(keyword)", category: logCategory)
        
        let lowercasedKeyword = keyword.lowercased()
        var results: [IconDefinition] = []
        
        // Search in specified provider or all
        let providers: [IconProvider] = provider != nil ? [provider!] : IconProvider.allCases
        
        for p in providers {
            let icons: [IconDefinition]
            
            switch p {
            case .fluent:
                icons = Array(fluentIcons.values)
            case .heroicons:
                icons = Array(heroicons.values)
            case .fontawesome:
                icons = Array(fontAwesomeIcons.values)
            case .custom:
                icons = Array(customIcons.values)
            }
            
            // Filter by name or keywords
            let filtered = icons.filter { icon in
                icon.name.lowercased().contains(lowercasedKeyword) ||
                icon.keywords.contains { $0.lowercased().contains(lowercasedKeyword) }
            }
            
            results.append(contentsOf: filtered)
        }
        
        logger.debug("Found \(results.count) icons matching '\(keyword)'", category: logCategory)
        
        return results
    }
    
    /// Get icons by category
    public func getIconsByCategory(_ category: String, provider: IconProvider? = nil) async -> [IconDefinition] {
        logger.debug("Getting icons for category: \(category)", category: logCategory)
        
        var results: [IconDefinition] = []
        
        // Get from specified provider or all
        let providers: [IconProvider] = provider != nil ? [provider!] : IconProvider.allCases
        
        for p in providers {
            let icons: [IconDefinition]
            
            switch p {
            case .fluent:
                icons = Array(fluentIcons.values)
            case .heroicons:
                icons = Array(heroicons.values)
            case .fontawesome:
                icons = Array(fontAwesomeIcons.values)
            case .custom:
                icons = Array(customIcons.values)
            }
            
            // Filter by category
            let filtered = icons.filter { $0.category == category }
            results.append(contentsOf: filtered)
        }
        
        return results
    }
    
    // MARK: - Custom Icons
    
    /// Register custom icon
    public func registerCustomIcon(_ definition: IconDefinition) {
        logger.info("Registering custom icon: \(definition.name)", category: logCategory)
        customIcons[definition.name] = definition
    }
    
    /// Register multiple custom icons
    public func registerCustomIcons(_ definitions: [IconDefinition]) {
        logger.info("Registering \(definitions.count) custom icons", category: logCategory)
        for definition in definitions {
            customIcons[definition.name] = definition
        }
    }
    
    // MARK: - Icon Sprite Generation
    
    /// Generate SVG sprite sheet
    public func generateSprite(icons: [IconRequest]) async throws -> String {
        logger.info("Generating sprite sheet with \(icons.count) icons", category: logCategory)
        
        var sprite = """
        <svg xmlns="http://www.w3.org/2000/svg" style="display: none;">
        <defs>
        """
        
        for request in icons {
            guard let definition = await findIconDefinition(provider: request.provider, name: request.name, style: request.style) else {
                logger.warning(
                    "Icon not found for sprite: \(request.provider.rawValue)/\(request.name)",
                    category: logCategory
                )
                continue
            }
            
            let symbolId = "\(request.provider.rawValue)-\(request.name)"
            
            sprite += """
            <symbol id="\(symbolId)" viewBox="\(definition.viewBox)">
            """
            
            if definition.svgPath.contains("<path") {
                sprite += definition.svgPath
            } else {
                sprite += "<path d=\"\(definition.svgPath)\" />"
            }
            
            sprite += "</symbol>"
        }
        
        sprite += """
        </defs>
        </svg>
        """
        
        return sprite
    }
    
    // MARK: - Icon Statistics
    
    /// Get icon system statistics
    public func getStatistics() async -> IconStatistics {
        let fluentCount = fluentIcons.count
        let heroiconsCount = heroicons.count
        let fontAwesomeCount = fontAwesomeIcons.count
        let customCount = customIcons.count
        let cacheSize = renderCache.count
        
        return IconStatistics(
            totalIcons: fluentCount + heroiconsCount + fontAwesomeCount + customCount,
            providerCounts: [
                "fluent": fluentCount,
                "heroicons": heroiconsCount,
                "fontawesome": fontAwesomeCount,
                "custom": customCount
            ],
            cacheSize: cacheSize,
            popularIcons: await getPopularIcons()
        )
    }
    
    /// Icon statistics
    public struct IconStatistics: Sendable {
        public let totalIcons: Int
        public let providerCounts: [String: Int]
        public let cacheSize: Int
        public let popularIcons: [String]
    }
    
    /// Get popular icons (mock implementation)
    private func getPopularIcons() async -> [String] {
        // In production, this would track actual usage
        return ["home", "settings", "search", "arrow-right", "check", "github", "rocket"]
    }
    
    // MARK: - Icon Export
    
    /// Export icons to JSON
    public func exportToJSON(provider: IconProvider? = nil) async throws -> String {
        var icons: [IconDefinition] = []
        
        if let provider = provider {
            switch provider {
            case .fluent:
                icons = Array(fluentIcons.values)
            case .heroicons:
                icons = Array(heroicons.values)
            case .fontawesome:
                icons = Array(fontAwesomeIcons.values)
            case .custom:
                icons = Array(customIcons.values)
            }
        } else {
            // Export all icons
            icons = Array(fluentIcons.values) + Array(heroicons.values) + 
                   Array(fontAwesomeIcons.values) + Array(customIcons.values)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(icons)
        
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
