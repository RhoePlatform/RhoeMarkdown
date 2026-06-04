//
//  ResourceError.swift
//  RhoeMarkdownKit
//
//  Comprehensive error handling for resource loading
//

import Foundation
import RhoeMarkdownModel

/// Errors that can occur during resource loading
public enum ResourceError: LocalizedError, Sendable {
    case iconNotFound(set: IconSet, name: String)
    case emojiNotFound(name: String)
    case invalidIconSet(String)
    case resourceBundleNotFound
    case svgParsingError(String)
    case cachingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .iconNotFound(let set, let name):
            return "Icon '\(name)' not found in \(set.displayName)"
        case .emojiNotFound(let name):
            return "Emoji '\(name)' not found"
        case .invalidIconSet(let setName):
            return "Invalid icon set: '\(setName)'"
        case .resourceBundleNotFound:
            return "Resource bundle not found"
        case .svgParsingError(let details):
            return "SVG parsing error: \(details)"
        case .cachingError(let details):
            return "Caching error: \(details)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .iconNotFound(let set, _):
            return "Check icon name spelling or use ResourceManager.availableIcons(for: .\(set.rawValue)) to see available icons"
        case .emojiNotFound:
            return "Check emoji name spelling or use ResourceManager.searchEmojis(query:) to find similar emojis"
        case .invalidIconSet:
            return "Valid icon sets are: lucide, heroicons, heroiconsSolid"
        case .resourceBundleNotFound:
            return "Ensure Package.swift includes resources and rebuild the package"
        case .svgParsingError:
            return "The SVG file may be corrupted or in an unsupported format"
        case .cachingError:
            return "Try clearing the cache or check available memory"
        }
    }
}

/// Result type for resource loading operations
public typealias ResourceResult<T> = Result<T, ResourceError>

/// Fallback strategies for missing resources
public enum ResourceFallbackStrategy: Sendable {
    case useDefault
    case useEmpty
    case throwError
    case useAlternative(String)
}

/// Configuration for resource error handling
public struct ResourceErrorConfiguration: Sendable {
    public let iconFallbackStrategy: ResourceFallbackStrategy
    public let emojiFallbackStrategy: ResourceFallbackStrategy
    public let logErrors: Bool
    public let developmentMode: Bool
    
    public init(
        iconFallbackStrategy: ResourceFallbackStrategy = .useDefault,
        emojiFallbackStrategy: ResourceFallbackStrategy = .useDefault,
        logErrors: Bool = true,
        developmentMode: Bool = false
    ) {
        self.iconFallbackStrategy = iconFallbackStrategy
        self.emojiFallbackStrategy = emojiFallbackStrategy
        self.logErrors = logErrors
        self.developmentMode = developmentMode
    }
    
    public static let `default` = ResourceErrorConfiguration()
    public static let development = ResourceErrorConfiguration(
        iconFallbackStrategy: .throwError,
        emojiFallbackStrategy: .throwError,
        logErrors: true,
        developmentMode: true
    )
    public static let production = ResourceErrorConfiguration(
        iconFallbackStrategy: .useDefault,
        emojiFallbackStrategy: .useDefault,
        logErrors: false,
        developmentMode: false
    )
}

/// Default fallback resources
public struct FallbackResources {
    /// Default icon SVG (simple placeholder)
    public static let defaultIconSVG = """
        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2" 
                  fill="none" stroke="currentColor" stroke-width="2"/>
            <line x1="8" y1="12" x2="16" y2="12" 
                  stroke="currentColor" stroke-width="2"/>
            <line x1="12" y1="8" x2="12" y2="16" 
                  stroke="currentColor" stroke-width="2"/>
        </svg>
        """
    
    /// Empty icon SVG (transparent)
    public static let emptyIconSVG = """
        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"></svg>
        """
    
    /// Default emoji character
    public static let defaultEmoji = "❓"
    
    /// Empty emoji (zero-width space)
    public static let emptyEmoji = "\u{200B}"
}

/// Error recovery helpers
public struct ResourceErrorRecovery {
    #if !os(WASI)
    /// Suggest similar icon names
    public static func suggestSimilarIcons(
        for name: String,
        in set: IconSet,
        using manager: ResourceManager
    ) -> [String] {
        let available = manager.availableIcons(for: set)
        return findSimilar(name: name, in: Array(available))
    }

    /// Suggest similar emoji names
    public static func suggestSimilarEmojis(
        for name: String,
        using manager: ResourceManager
    ) -> [String] {
        return manager.searchEmojis(query: name)
    }
    #endif
    
    /// Find similar names using basic string matching
    private static func findSimilar(name: String, in candidates: [String]) -> [String] {
        let lowercaseName = name.lowercased()
        
        // Exact prefix matches
        let prefixMatches = candidates.filter { 
            $0.lowercased().hasPrefix(lowercaseName) 
        }
        
        // Contains matches
        let containsMatches = candidates.filter { 
            $0.lowercased().contains(lowercaseName) && !prefixMatches.contains($0)
        }
        
        // Fuzzy matches (same first letter)
        let fuzzyMatches = candidates.filter {
            $0.lowercased().first == lowercaseName.first && 
            !prefixMatches.contains($0) && 
            !containsMatches.contains($0)
        }
        
        return Array((prefixMatches + containsMatches + fuzzyMatches).prefix(5))
    }
}

/// Logging utilities for resource errors
public struct ResourceErrorLogger {
    private static let subsystem = "com.rhoemarkdownkit.resources"
    
    public static func log(_ error: ResourceError, file: String = #file, line: Int = #line) {
        #if DEBUG
        print("⚠️ ResourceError at \(file):\(line) - \(error.localizedDescription)")
        if let suggestion = error.recoverySuggestion {
            print("   💡 Suggestion: \(suggestion)")
        }
        #endif
    }
    
    public static func logMissingResource(
        type: String,
        name: String,
        suggestions: [String] = []
    ) {
        #if DEBUG
        print("❌ Missing \(type): '\(name)'")
        if !suggestions.isEmpty {
            print("   💡 Did you mean: \(suggestions.joined(separator: ", "))?")
        }
        #endif
    }
}
