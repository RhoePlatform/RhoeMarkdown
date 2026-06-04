import Foundation

/// Protocol for accumulating diagnostics across pipeline stages.
///
/// Pipeline passes can report diagnostics (warnings, errors, info) through
/// this protocol. The pipeline collects all diagnostics and returns them
/// alongside the processed document.
public protocol DiagnosticCollector: Sendable {
    /// Add a diagnostic to the collection.
    mutating func add(_ diagnostic: RhoeMarkdownKit.Diagnostic)

    /// Add multiple diagnostics.
    mutating func add(contentsOf diagnostics: [RhoeMarkdownKit.Diagnostic])

    /// All collected diagnostics.
    var diagnostics: [RhoeMarkdownKit.Diagnostic] { get }
}

/// Default diagnostic collector that accumulates into an array.
public struct ArrayDiagnosticCollector: DiagnosticCollector, Sendable, Equatable {
    public private(set) var diagnostics: [RhoeMarkdownKit.Diagnostic] = []

    public init() {}

    public mutating func add(_ diagnostic: RhoeMarkdownKit.Diagnostic) {
        diagnostics.append(diagnostic)
    }

    public mutating func add(contentsOf newDiagnostics: [RhoeMarkdownKit.Diagnostic]) {
        diagnostics.append(contentsOf: newDiagnostics)
    }
}

// MARK: - Convenience Diagnostic Factories

extension RhoeMarkdownKit.Diagnostic {
    /// Create an info diagnostic.
    public static func info(_ message: String, line: Int? = nil, column: Int? = nil) -> Self {
        Self(severity: .info, message: message, line: line, column: column)
    }

    /// Create a warning diagnostic.
    public static func warning(_ message: String, line: Int? = nil, column: Int? = nil) -> Self {
        Self(severity: .warning, message: message, line: line, column: column)
    }

    /// Create an error diagnostic.
    public static func error(_ message: String, line: Int? = nil, column: Int? = nil) -> Self {
        Self(severity: .error, message: message, line: line, column: column)
    }
}
