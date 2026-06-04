import Foundation

/// Validates a loaded project configuration for consistency and completeness.
public struct ProjectConfigurationValidator: Sendable {

    public init() {}

    /// Validate the configuration and return diagnostics.
    public func validate(_ config: ProjectConfiguration) -> [ProjectDiagnostic] {
        var diagnostics: [ProjectDiagnostic] = []

        // Schema version
        if config.schemaVersion != 1 {
            diagnostics.append(.error("Unsupported schema version: \(config.schemaVersion). Expected 1.", path: "rhoe_project"))
        }

        // Must have at least one target
        if config.targets.isEmpty {
            diagnostics.append(.warning("No targets defined. Add at least one target to build.", path: "targets"))
        }

        // Validate targets reference defined collections
        for (targetName, target) in config.targets {
            for colName in target.collections {
                if config.collections[colName] == nil {
                    diagnostics.append(.error(
                        "Target '\(targetName)' references undefined collection '\(colName)'.",
                        path: "targets.\(targetName).collections"
                    ))
                }
            }

            if !target.enabled {
                diagnostics.append(.info(
                    "Target '\(targetName)' is disabled.",
                    path: "targets.\(targetName).enabled"
                ))
            }
        }

        // Check collection paths for duplicates
        var seenPaths: [String: String] = [:]
        for (name, col) in config.collections {
            if let existingName = seenPaths[col.path] {
                diagnostics.append(.warning(
                    "Collections '\(existingName)' and '\(name)' share the same path '\(col.path)'.",
                    path: "collections.\(name).path"
                ))
            }
            seenPaths[col.path] = name
        }

        // Validate collection target_roles reference defined targets
        let targetNames = Set(config.targets.keys)
        for (colName, col) in config.collections {
            for role in col.targetRoles {
                if !targetNames.contains(role) {
                    diagnostics.append(.info(
                        "Collection '\(colName)' references target role '\(role)' which is not defined as a target.",
                        path: "collections.\(colName).target_roles"
                    ))
                }
            }
        }

        // Validate profiles
        for (profileName, _) in config.profiles {
            diagnostics.append(.info(
                "Build profile '\(profileName)' registered.",
                path: "profiles.\(profileName)"
            ))
        }

        return diagnostics
    }
}

/// A diagnostic message from project configuration processing.
public struct ProjectDiagnostic: Sendable, Equatable {
    public enum Severity: String, Sendable, Equatable {
        case info, warning, error
    }

    public let severity: Severity
    public let message: String
    public let path: String?

    public init(severity: Severity, message: String, path: String? = nil) {
        self.severity = severity
        self.message = message
        self.path = path
    }

    public static func info(_ message: String, path: String? = nil) -> ProjectDiagnostic {
        .init(severity: .info, message: message, path: path)
    }

    public static func warning(_ message: String, path: String? = nil) -> ProjectDiagnostic {
        .init(severity: .warning, message: message, path: path)
    }

    public static func error(_ message: String, path: String? = nil) -> ProjectDiagnostic {
        .init(severity: .error, message: message, path: path)
    }
}
