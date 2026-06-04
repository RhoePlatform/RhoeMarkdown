import Foundation

/// Build profile for different environments (development, production, CI).
public struct BuildProfile: Sendable, Equatable {
    public let validation: ValidationPolicy?
    public let execution: ExecutionPolicy?
    public let security: SecurityPolicy?

    public init(
        validation: ValidationPolicy? = nil,
        execution: ExecutionPolicy? = nil,
        security: SecurityPolicy? = nil
    ) {
        self.validation = validation
        self.execution = execution
        self.security = security
    }
}

/// Validation strictness policy.
public struct ValidationPolicy: Sendable, Equatable {
    public let strict: Bool
    public let brokenLinks: DiagnosticLevel

    public init(strict: Bool = false, brokenLinks: DiagnosticLevel = .warn) {
        self.strict = strict
        self.brokenLinks = brokenLinks
    }
}

/// Diagnostic severity level.
public enum DiagnosticLevel: String, Sendable, Equatable {
    case warn, error, ignore
}

/// Code cell execution policy.
public struct ExecutionPolicy: Sendable, Equatable {
    public let codeCells: CodeCellPolicy

    public init(codeCells: CodeCellPolicy = .skip) {
        self.codeCells = codeCells
    }
}

/// Code cell execution mode.
public enum CodeCellPolicy: String, Sendable, Equatable {
    case execute
    case useCached = "use-cached"
    case skip
}

/// Security policy for external resources.
public struct SecurityPolicy: Sendable, Equatable {
    public let externalData: ExternalDataPolicy

    public init(externalData: ExternalDataPolicy = .deny) {
        self.externalData = externalData
    }
}

/// External data access policy.
public enum ExternalDataPolicy: String, Sendable, Equatable {
    case allow, deny
}
