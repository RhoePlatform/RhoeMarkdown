//
//  EmojiManager.swift
//  RhoeMarkdownKit
//
//  Emoji management system for rendering emojis as shapes
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Manages emoji rendering and SVG generation
public struct EmojiManager: Sendable {
    
    // MARK: - Emoji Mapping
    
    /// Common emoji name mappings
    private static let emojiMap: [String: String] = [
        // Faces
        "smile": "😊",
        "laugh": "😂",
        "wink": "😉",
        "love": "😍",
        "cool": "😎",
        "think": "🤔",
        "sad": "😢",
        "angry": "😠",
        
        // Hands & Gestures
        "thumbs-up": "👍",
        "thumbs-down": "👎",
        "clap": "👏",
        "wave": "👋",
        "ok": "👌",
        "peace": "✌️",
        "muscle": "💪",
        "pray": "🙏",
        
        // Objects & Symbols
        "rocket": "🚀",
        "fire": "🔥",
        "star": "⭐",
        "heart": "❤️",
        "sparkles": "✨",
        "lightning": "⚡",
        "warning": "⚠️",
        "check": "✅",
        "cross": "❌",
        "bulb": "💡",
        "key": "🔑",
        "lock": "🔒",
        "unlock": "🔓",
        "gift": "🎁",
        "trophy": "🏆",
        "medal": "🥇",
        
        // Nature
        "sun": "☀️",
        "moon": "🌙",
        "star2": "🌟",
        "cloud": "☁️",
        "rain": "🌧️",
        "rainbow": "🌈",
        "tree": "🌳",
        "flower": "🌸",
        "earth": "🌍",
        
        // Tech & Work
        "computer": "💻",
        "phone": "📱",
        "email": "📧",
        "folder": "📁",
        "chart": "📈",
        "calendar": "📅",
        "clock": "🕐",
        "search": "🔍",
        "tools": "🛠️",
        "gear": "⚙️",
        
        // Transport
        "car": "🚗",
        "bus": "🚌",
        "train": "🚂",
        "plane": "✈️",
        "ship": "🚢",
        "bike": "🚲",
        
        // Food & Drink
        "coffee": "☕",
        "pizza": "🍕",
        "cake": "🎂",
        "apple": "🍎",
        "beer": "🍺",
        "wine": "🍷",
        
        // Animals
        "dog": "🐕",
        "cat": "🐱",
        "unicorn": "🦄",
        "dragon": "🐉",
        "butterfly": "🦋",
        
        // Flags & Countries
        "flag-us": "🇺🇸",
        "flag-gb": "🇬🇧",
        "flag-eu": "🇪🇺",
        "flag-jp": "🇯🇵",
        "flag-cn": "🇨🇳",
        
        // Arrows
        "arrow-up": "⬆️",
        "arrow-down": "⬇️",
        "arrow-left": "⬅️",
        "arrow-right": "➡️",
        "arrow-up-right": "↗️",
        "arrow-down-left": "↙️",
        
        // Numbers
        "one": "1️⃣",
        "two": "2️⃣",
        "three": "3️⃣",
        "four": "4️⃣",
        "five": "5️⃣"
    ]
    
    // MARK: - Emoji Rendering
    
    /// Get SVG content for an emoji
    public static func getSVGContent(
        emojiName: String,
        size: ShapeSize,
        style: ShapeStyler.ShapeStyle,
        presentationAttributes: RhoeMarkdownKit.Attributes?
    ) -> String? {
        // Get the emoji character
        let emoji = getEmoji(for: emojiName)
        
        // Create SVG with centered emoji text
        return generateEmojiSVG(
            emoji: emoji,
            size: size,
            style: style
        )
    }
    
    /// Get emoji character from name
    private static func getEmoji(for name: String) -> String {
        // First check our mapping
        if let mapped = emojiMap[name.lowercased()] {
            return mapped
        }
        
        // Try direct emoji (if someone passes "🚀" as the name)
        if name.count <= 3 && name.unicodeScalars.allSatisfy({ $0.properties.isEmoji }) {
            return name
        }
        
        // Check for skin tone modifiers
        if name.contains("-") {
            let components = name.split(separator: "-")
            if components.count == 2,
               let base = emojiMap[String(components[0])],
               let tone = parseSkinTone(String(components[1])) {
                return base + tone
            }
        }
        
        // Default to question mark emoji
        return "❓"
    }
    
    /// Parse skin tone modifier
    private static func parseSkinTone(_ tone: String) -> String? {
        switch tone {
        case "light": return "🏻"
        case "medium-light": return "🏼"
        case "medium": return "🏽"
        case "medium-dark": return "🏾"
        case "dark": return "🏿"
        default: return nil
        }
    }
    
    /// Generate SVG for emoji
    private static func generateEmojiSVG(
        emoji: String,
        size: ShapeSize,
        style: ShapeStyler.ShapeStyle
    ) -> String {
        // Calculate font size to fit the emoji well within bounds
        let fontSize = min(size.width, size.height) * 0.8
        
        var svg = """
        <svg width="\(size.width)" height="\(size.height)" viewBox="0 0 \(size.width) \(size.height)" xmlns="http://www.w3.org/2000/svg">
        """
        
        // Add background if specified
        if let fill = style.fill {
            svg += """
            <rect width="\(size.width)" height="\(size.height)" fill="\(fill)" rx="\(style.cornerRadius ?? 0)"/>
            """
        }
        
        // Add shadow if specified
        if let shadow = style.shadow {
            let shadowId = "emoji-shadow-\(UUID().uuidString)"
            svg += ShapeStyler.generateShadowFilter(shadow, id: shadowId)
            svg += "<g filter=\"url(#\(shadowId))\">"
        }
        
        // Add the emoji as text element
        // Center it both horizontally and vertically
        let x = size.width / 2
        let y = size.height / 2
        
        svg += """
        <text x="\(x)" y="\(y)" 
              font-family="-apple-system, 'Segoe UI Emoji', 'Apple Color Emoji', 'Noto Color Emoji', sans-serif" 
              font-size="\(fontSize)" 
              text-anchor="middle" 
              dominant-baseline="central">
        """
        
        svg += emoji
        svg += "</text>"
        
        if style.shadow != nil {
            svg += "</g>"
        }
        
        svg += "</svg>"
        
        return svg
    }
    
    // MARK: - Emoji Categories
    
    /// Available emoji categories for browsing
    public enum EmojiCategory: String, CaseIterable {
        case faces = "Faces & Emotions"
        case hands = "Hands & Gestures"
        case objects = "Objects & Symbols"
        case nature = "Nature & Weather"
        case tech = "Technology & Work"
        case transport = "Transport"
        case food = "Food & Drink"
        case animals = "Animals"
        case flags = "Flags"
        case arrows = "Arrows"
        case numbers = "Numbers"
    }
    
    /// Get emojis for a specific category
    public static func emojis(for category: EmojiCategory) -> [(name: String, emoji: String)] {
        switch category {
        case .faces:
            return [
                ("smile", "😊"), ("laugh", "😂"), ("wink", "😉"),
                ("love", "😍"), ("cool", "😎"), ("think", "🤔"),
                ("sad", "😢"), ("angry", "😠")
            ]
        case .hands:
            return [
                ("thumbs-up", "👍"), ("thumbs-down", "👎"), ("clap", "👏"),
                ("wave", "👋"), ("ok", "👌"), ("peace", "✌️"),
                ("muscle", "💪"), ("pray", "🙏")
            ]
        case .objects:
            return [
                ("rocket", "🚀"), ("fire", "🔥"), ("star", "⭐"),
                ("heart", "❤️"), ("sparkles", "✨"), ("lightning", "⚡"),
                ("bulb", "💡"), ("trophy", "🏆")
            ]
        case .nature:
            return [
                ("sun", "☀️"), ("moon", "🌙"), ("cloud", "☁️"),
                ("rainbow", "🌈"), ("tree", "🌳"), ("flower", "🌸")
            ]
        case .tech:
            return [
                ("computer", "💻"), ("phone", "📱"), ("email", "📧"),
                ("chart", "📈"), ("search", "🔍"), ("gear", "⚙️")
            ]
        case .transport:
            return [
                ("car", "🚗"), ("bus", "🚌"), ("train", "🚂"),
                ("plane", "✈️"), ("ship", "🚢"), ("bike", "🚲")
            ]
        case .food:
            return [
                ("coffee", "☕"), ("pizza", "🍕"), ("cake", "🎂"),
                ("apple", "🍎"), ("beer", "🍺"), ("wine", "🍷")
            ]
        case .animals:
            return [
                ("dog", "🐕"), ("cat", "🐱"), ("unicorn", "🦄"),
                ("dragon", "🐉"), ("butterfly", "🦋")
            ]
        case .flags:
            return [
                ("flag-us", "🇺🇸"), ("flag-gb", "🇬🇧"), ("flag-eu", "🇪🇺"),
                ("flag-jp", "🇯🇵"), ("flag-cn", "🇨🇳")
            ]
        case .arrows:
            return [
                ("arrow-up", "⬆️"), ("arrow-down", "⬇️"),
                ("arrow-left", "⬅️"), ("arrow-right", "➡️")
            ]
        case .numbers:
            return [
                ("one", "1️⃣"), ("two", "2️⃣"), ("three", "3️⃣"),
                ("four", "4️⃣"), ("five", "5️⃣")
            ]
        }
    }
    
    /// Get all available emoji names
    public static var allEmojiNames: [String] {
        Array(emojiMap.keys).sorted()
    }
}

// MARK: - Helper Extensions

extension ShapeSize {
    /// Default size for emojis
    public static let emoji = ShapeSize(width: 64, height: 64)
}