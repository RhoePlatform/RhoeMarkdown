import Foundation
import RhoeMarkdownModel

/// Determines whether an element with given attributes should be visible
/// in a specific projection domain.
///
/// The projection visibility system uses `visible=` and `hidden=` attribute
/// keys to control which rendering targets include each element.
///
/// - `visible=screen,print` → show only in screen and print
/// - `hidden=llm,summary` → hide from LLM and summary
/// - `assistive-only` → hidden from all visual, visible to assistive only
///
/// When no projection attributes are specified, elements are visible by default.
public struct ProjectionVisibility: Sendable {

    /// Canonical projection domain names
    public enum Domain: String, Sendable, CaseIterable {
        case print
        case screen
        case viewer
        case site
        case presenter
        case audience
        case llm
        case summary
        case assistive
    }

    /// Check whether an element should be visible in the given domain.
    ///
    /// Returns `true` if the element should be rendered, `false` if it should be skipped.
    public static func isVisible(
        attributes: RhoeMarkdownKit.Attributes,
        in domain: Domain
    ) -> Bool {
        let kv = attributes.keyValues

        // Check for assistive-only flag
        if kv["assistive-only"] == "true" {
            return domain == .assistive
        }

        // Check explicit visible= list
        if let visibleStr = kv["visible"], !visibleStr.isEmpty {
            let visibleDomains = visibleStr.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            return visibleDomains.contains(domain.rawValue)
        }

        // Check explicit hidden= list
        if let hiddenStr = kv["hidden"], !hiddenStr.isEmpty {
            let hiddenDomains = hiddenStr.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            if hiddenDomains.contains(domain.rawValue) {
                return false
            }
        }

        // Check shorthand projection= presets
        if let projection = kv["projection"] {
            switch projection.lowercased() {
            case "print-only": return domain == .print
            case "screen-only": return domain == .screen
            case "presenter-only": return domain == .presenter
            case "audience-only": return domain == .audience
            case "llm-only": return domain == .llm
            case "site-only": return domain == .site
            default: break
            }
        }

        // Default: visible in most domains
        return true
    }

    /// Map output format names to projection domains
    public static func domainForWriter(_ writerName: String) -> Domain {
        switch writerName.lowercased() {
        case "html", "htm": return .screen
        case "latex", "tex", "typst", "pdf": return .print
        case "docx": return .print
        case "epub": return .screen
        case "swiftui": return .viewer
        default: return .screen
        }
    }
}
