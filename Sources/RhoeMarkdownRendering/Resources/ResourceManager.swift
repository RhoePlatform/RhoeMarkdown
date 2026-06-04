#if !os(WASI)
//
//  ResourceManager.swift
//  RhoeMarkdownKit
//
//  Comprehensive resource management for icons and emojis
//

import Foundation
import RhoeMarkdownModel

/// Central resource manager for icons, emojis, and other assets
public final class ResourceManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = ResourceManager()
    
    /// Error handling configuration
    public var errorConfiguration = ResourceErrorConfiguration.default
    
    private init() {
        loadResourceMappings()
    }
    
    // MARK: - Resource Caching

    #if !os(WASI)
    private let cache = NSCache<NSString, NSString>()
    private let resourceQueue = DispatchQueue(label: "com.rhoemarkdownkit.resources", qos: .userInitiated)
    #endif

    // MARK: - Bundle Access

    #if !os(WASI)
    private var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: ResourceManager.self)
        #endif
    }
    #endif
    
    // MARK: - Icon Loading
    
    /// Load an icon SVG from resources with error handling
    public func loadIconSafe(set: IconSet, name: String) -> ResourceResult<String> {
        // Check cache first
        let cacheKey = "\(set.rawValue).\(name)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return .success(cached as String)
        }
        
        // Check if icon exists
        guard iconExists(set: set, name: name) else {
            let error = ResourceError.iconNotFound(set: set, name: name)
            ResourceErrorLogger.log(error)
            
            // Suggest similar icons
            let suggestions = ResourceErrorRecovery.suggestSimilarIcons(
                for: name,
                in: set,
                using: self
            )
            ResourceErrorLogger.logMissingResource(
                type: "icon",
                name: "\(set.rawValue).\(name)",
                suggestions: suggestions
            )
            
            return .failure(error)
        }
        
        // Load from bundle
        guard let svgContent = loadIconFromBundle(set: set, name: name) else {
            return .failure(.svgParsingError("Failed to load SVG from bundle"))
        }
        
        // Cache the result
        cache.setObject(svgContent as NSString, forKey: cacheKey)
        return .success(svgContent)
    }
    
    /// Load an icon SVG from resources (legacy method)
    public func loadIcon(set: IconSet, name: String) -> String? {
        let cacheKey = "\(set.rawValue).\(name)" as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached as String
        }
        
        // Load from bundle
        guard let svgContent = loadIconFromBundle(set: set, name: name) else {
            return nil
        }
        
        // Cache the result
        cache.setObject(svgContent as NSString, forKey: cacheKey)
        return svgContent
    }
    
    private func loadIconFromBundle(set: IconSet, name: String) -> String? {
        let path = iconPath(for: set, name: name)
        
        guard let url = resourceBundle.url(forResource: path, withExtension: "svg"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        return content
    }
    
    private func iconPath(for set: IconSet, name: String) -> String {
        switch set {
        case .lucide:
            return "Icons/Lucide/\(name)"
        case .fluent:
            return "Icons/Fluent/\(name)"
        case .feather:
            return "Icons/Feather/\(name)"
        case .heroicons:
            return "Icons/Heroicons/Outline/\(name)"
        case .heroiconsSolid:
            return "Icons/Heroicons/Solid/\(name)"
        }
    }
    
    // MARK: - Icon Discovery
    
    private var iconRegistries: [IconSet: Set<String>] = [:]
    
    /// Get all available icon names for a given set
    public func availableIcons(for set: IconSet) -> Set<String> {
        if let cached = iconRegistries[set] {
            return cached
        }
        
        let icons = discoverIcons(for: set)
        iconRegistries[set] = icons
        return icons
    }
    
    private func discoverIcons(for set: IconSet) -> Set<String> {
        let directory = iconDirectory(for: set)
        
        guard let resourcePath = resourceBundle.path(forResource: directory, ofType: nil),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) else {
            return []
        }
        
        return Set(contents.compactMap { filename in
            guard filename.hasSuffix(".svg") else { return nil }
            return String(filename.dropSuffix(4)) // Remove .svg extension
        })
    }
    
    private func iconDirectory(for set: IconSet) -> String {
        switch set {
        case .lucide: return "Icons/Lucide"
        case .fluent: return "Icons/Fluent"
        case .feather: return "Icons/Feather"
        case .heroicons: return "Icons/Heroicons/Outline"
        case .heroiconsSolid: return "Icons/Heroicons/Solid"
        }
    }
    
    // MARK: - Emoji Management
    
    private var emojiMappings: [String: EmojiMetadata] = [:]
    private var emojiCategories: [EmojiCategory: [String]] = [:]
    
    /// Get emoji character with error handling
    public func getEmojiSafe(for name: String) -> ResourceResult<String> {
        if let emoji = emojiMappings[name]?.character {
            return .success(emoji)
        }
        
        let error = ResourceError.emojiNotFound(name: name)
        ResourceErrorLogger.log(error)
        
        // Suggest similar emojis
        let suggestions = ResourceErrorRecovery.suggestSimilarEmojis(
            for: name,
            using: self
        )
        ResourceErrorLogger.logMissingResource(
            type: "emoji",
            name: name,
            suggestions: suggestions
        )
        
        return .failure(error)
    }
    
    /// Get emoji character for name (legacy method)
    public func getEmoji(for name: String) -> String? {
        return emojiMappings[name]?.character
    }
    
    /// Get emoji metadata
    public func getEmojiMetadata(for name: String) -> EmojiMetadata? {
        return emojiMappings[name]
    }
    
    /// Get all emojis in a category
    public func getEmojis(in category: EmojiCategory) -> [String] {
        return emojiCategories[category] ?? []
    }
    
    /// Search emojis by name or keywords
    public func searchEmojis(query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        
        return emojiMappings.keys.filter { name in
            let metadata = emojiMappings[name]!
            return name.lowercased().contains(lowercaseQuery) ||
                   metadata.keywords.contains { $0.lowercased().contains(lowercaseQuery) }
        }.sorted()
    }
    
    // MARK: - Resource Loading
    
    private func loadResourceMappings() {
        loadEmojiMappings()
        preloadIconRegistries()
    }
    
    private func loadEmojiMappings() {
        // Load comprehensive emoji mappings from JSON
        guard let url = resourceBundle.url(forResource: "Emojis/EmojiMappings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mappings = try? JSONDecoder().decode([String: EmojiMetadata].self, from: data) else {
            // Fallback to basic mappings if resource not found
            loadBasicEmojiMappings()
            return
        }
        
        emojiMappings = mappings
        buildEmojiCategories()
    }
    
    private func loadBasicEmojiMappings() {
        // Keep our current basic mappings as fallback
        emojiMappings = [
            "smile": EmojiMetadata(character: "😊", category: .smileysAndEmotion, keywords: ["happy", "joy", "pleased"]),
            "laugh": EmojiMetadata(character: "😂", category: .smileysAndEmotion, keywords: ["funny", "lol", "tears"]),
            "rocket": EmojiMetadata(character: "🚀", category: .travelAndPlaces, keywords: ["space", "launch", "fast"]),
            "fire": EmojiMetadata(character: "🔥", category: .objects, keywords: ["hot", "trending", "flame"]),
            "heart": EmojiMetadata(character: "❤️", category: .smileysAndEmotion, keywords: ["love", "like", "romance"]),
            // Add more basic emojis...
        ]
        buildEmojiCategories()
    }
    
    private func buildEmojiCategories() {
        emojiCategories.removeAll()
        
        for (name, metadata) in emojiMappings {
            if emojiCategories[metadata.category] == nil {
                emojiCategories[metadata.category] = []
            }
            emojiCategories[metadata.category]?.append(name)
        }
        
        // Sort each category
        for category in emojiCategories.keys {
            emojiCategories[category]?.sort()
        }
    }
    
    private func preloadIconRegistries() {
        // Preload icon registries on background queue
        resourceQueue.async { [weak self] in
            for iconSet in IconSet.allCases {
                _ = self?.availableIcons(for: iconSet)
            }
        }
    }
    
    // MARK: - Validation
    
    /// Check if an icon exists
    public func iconExists(set: IconSet, name: String) -> Bool {
        return availableIcons(for: set).contains(name)
    }
    
    /// Check if an emoji exists
    public func emojiExists(name: String) -> Bool {
        return emojiMappings.keys.contains(name)
    }
    
    // MARK: - Fallback Handling
    
    /// Load icon with fallback strategy
    public func loadIconWithFallback(set: IconSet, name: String) -> String {
        let result = loadIconSafe(set: set, name: name)
        
        switch result {
        case .success(let svg):
            return svg
        case .failure(let error):
            switch errorConfiguration.iconFallbackStrategy {
            case .useDefault:
                if errorConfiguration.logErrors {
                    ResourceErrorLogger.log(error)
                }
                return FallbackResources.defaultIconSVG
            case .useEmpty:
                return FallbackResources.emptyIconSVG
            case .throwError:
                // In production, still return default to avoid crashes
                if errorConfiguration.developmentMode {
                    fatalError(error.localizedDescription)
                }
                return FallbackResources.defaultIconSVG
            case .useAlternative(let alternativeName):
                // Try to load alternative
                if let alternative = loadIcon(set: set, name: alternativeName) {
                    return alternative
                }
                return FallbackResources.defaultIconSVG
            }
        }
    }
    
    /// Get emoji with fallback strategy
    public func getEmojiWithFallback(for name: String) -> String {
        let result = getEmojiSafe(for: name)
        
        switch result {
        case .success(let emoji):
            return emoji
        case .failure(let error):
            switch errorConfiguration.emojiFallbackStrategy {
            case .useDefault:
                if errorConfiguration.logErrors {
                    ResourceErrorLogger.log(error)
                }
                return FallbackResources.defaultEmoji
            case .useEmpty:
                return FallbackResources.emptyEmoji
            case .throwError:
                // In production, still return default to avoid crashes
                if errorConfiguration.developmentMode {
                    fatalError(error.localizedDescription)
                }
                return FallbackResources.defaultEmoji
            case .useAlternative(let alternativeName):
                // Try to load alternative
                if let alternative = getEmoji(for: alternativeName) {
                    return alternative
                }
                return FallbackResources.defaultEmoji
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get resource statistics
    public func getStatistics() -> ResourceStatistics {
        let iconCounts = IconSet.allCases.reduce(into: [IconSet: Int]()) { result, set in
            result[set] = availableIcons(for: set).count
        }
        
        let emojiCounts = EmojiCategory.allCases.reduce(into: [EmojiCategory: Int]()) { result, category in
            result[category] = emojiCategories[category]?.count ?? 0
        }
        
        return ResourceStatistics(
            iconCounts: iconCounts,
            emojiCounts: emojiCounts,
            totalIcons: iconCounts.values.reduce(0, +),
            totalEmojis: emojiMappings.count,
            cacheSize: cache.countLimit
        )
    }
}

// MARK: - Supporting Types

/// Emoji metadata structure
public struct EmojiMetadata: Codable, Sendable {
    public let character: String
    public let category: EmojiCategory
    public let keywords: [String]
    public let unicodeVersion: String?
    public let skinToneBase: String?
    
    public init(
        character: String,
        category: EmojiCategory,
        keywords: [String],
        unicodeVersion: String? = nil,
        skinToneBase: String? = nil
    ) {
        self.character = character
        self.category = category
        self.keywords = keywords
        self.unicodeVersion = unicodeVersion
        self.skinToneBase = skinToneBase
    }
}

/// Comprehensive emoji categories based on Unicode standards
public enum EmojiCategory: String, CaseIterable, Codable, Sendable {
    case smileysAndEmotion = "Smileys & Emotion"
    case peopleAndBody = "People & Body"
    case animalsAndNature = "Animals & Nature"
    case foodAndDrink = "Food & Drink"
    case travelAndPlaces = "Travel & Places"
    case activities = "Activities"
    case objects = "Objects"
    case symbols = "Symbols"
    case flags = "Flags"
    case skinTones = "Skin Tones"
    case component = "Component"
}

/// Resource statistics
public struct ResourceStatistics: Sendable {
    public let iconCounts: [IconSet: Int]
    public let emojiCounts: [EmojiCategory: Int]
    public let totalIcons: Int
    public let totalEmojis: Int
    public let cacheSize: Int
}

// MARK: - String Extensions

private extension String {
    func dropSuffix(_ count: Int) -> String {
        guard count < self.count else { return "" }
        return String(self.dropLast(count))
    }
}

#endif // !os(WASI)
