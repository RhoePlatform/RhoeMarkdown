# Execution API Reference

API documentation for the expression engine, input field system, reactive evaluation, bridge protocol, and notebook management types.

## Overview

The execution API provides programmatic access to the computation layer of RhoeMarkdownKit. These types implement Phase 5 of the five-phase pipeline: expression evaluation, input field management, form transactions, reactive dependency tracking, bridge protocol encoding, and notebook package operations.

All types in the execution API are `Sendable` and `Equatable`, following the codebase conventions for public types.

## ExpressionEngine

The `ExpressionEngine` evaluates expression strings against an evaluation context, producing typed `ExprValue` results.

```swift
public struct ExpressionEngine: Sendable {
    /// Create an engine with the given evaluation context.
    public init(context: EvaluationContext)

    /// Evaluate an expression string.
    ///
    /// Returns the computed `ExprValue`. Never throws; errors are represented
    /// as `ExprValue.error(code, message, details)`.
    ///
    /// - Parameter expression: The expression string (without the `=` or `<<=` prefix).
    /// - Returns: The evaluated result.
    public func evaluate(_ expression: String) -> ExprValue

    /// Evaluate an expression with additional local bindings.
    ///
    /// Local bindings override context values for this evaluation only.
    ///
    /// - Parameters:
    ///   - expression: The expression string.
    ///   - bindings: Additional name-value pairs available during evaluation.
    /// - Returns: The evaluated result.
    public func evaluate(_ expression: String, bindings: [String: ExprValue]) -> ExprValue
}
```

### EvaluationContext

```swift
public struct EvaluationContext: Sendable {
    /// Cell values indexed by reference (e.g., "A1", "B2").
    public var cells: [String: ExprValue]

    /// Input field values (the `in.*` namespace).
    public var inputValues: [String: ExprValue]

    /// Document metadata (the `doc.*` namespace).
    public var documentMetadata: [String: ExprValue]

    /// Bridge output values (the `out.*` namespace).
    public var bridgeOutputs: [String: ExprValue]

    /// Local function definitions.
    public var localFunctions: [String: LocalFunctionDefinition]

    /// Create an empty context.
    public init()

    /// Create a context with the given values.
    public init(
        cells: [String: ExprValue] = [:],
        inputValues: [String: ExprValue] = [:],
        documentMetadata: [String: ExprValue] = [:],
        bridgeOutputs: [String: ExprValue] = [:],
        localFunctions: [String: LocalFunctionDefinition] = [:]
    )
}
```

### ExprValue

```swift
public enum ExprValue: Sendable, Equatable {
    case number(Double)
    case string(String)
    case bool(Bool)
    case null
    case array([ExprValue])
    case object([String: ExprValue])
    case date(DateComponents)
    case datetime(Date)
    case duration(TimeInterval)
    case missing
    case error(code: String, message: String, details: [String: String]?)

    /// Coerce this value to a number, applying standard coercion rules.
    public var asNumber: ExprValue { get }

    /// Coerce this value to a string, applying standard coercion rules.
    public var asString: ExprValue { get }

    /// Coerce this value to a boolean, applying standard coercion rules.
    public var asBool: ExprValue { get }

    /// Whether this value is truthy (non-zero, non-empty, non-null, non-missing).
    public var isTruthy: Bool { get }

    /// Whether this value is an error.
    public var isError: Bool { get }

    /// Whether this value is missing.
    public var isMissing: Bool { get }

    /// The display string for rendering in HTML or other output formats.
    /// Returns the spreadsheet-style error code for error values (e.g., "#DIV/0!").
    public var displayString: String { get }
}
```

### LocalFunctionDefinition

```swift
public struct LocalFunctionDefinition: Sendable, Equatable {
    /// Function name.
    public let name: String

    /// Parameter names.
    public let parameters: [String]

    /// Let bindings (name-expression pairs, evaluated in order).
    public let letBindings: [(name: String, expression: String)]

    /// The body expression (evaluated after all let bindings).
    public let body: String

    public init(
        name: String,
        parameters: [String],
        letBindings: [(name: String, expression: String)] = [],
        body: String
    )
}
```

## InputField and InputFieldRegistry

### InputField

```swift
public struct InputField: Sendable, Equatable {
    /// Unique field name (used as the `in.*` namespace key).
    public let name: String

    /// Field type (text, number, select, toggle, slider, date, textarea, radio, color).
    public let fieldType: InputFieldType

    /// Default value.
    public let defaultValue: ExprValue

    /// Human-readable label for display.
    public let label: String?

    /// Placeholder text.
    public let placeholder: String?

    /// Validation constraints.
    public let constraints: InputConstraints?

    public init(
        name: String,
        fieldType: InputFieldType,
        defaultValue: ExprValue = .null,
        label: String? = nil,
        placeholder: String? = nil,
        constraints: InputConstraints? = nil
    )
}

public enum InputFieldType: String, Sendable, Equatable, CaseIterable {
    case text
    case number
    case select
    case toggle
    case slider
    case date
    case textarea
    case radio
    case color
}

public struct InputConstraints: Sendable, Equatable {
    public let min: Double?
    public let max: Double?
    public let step: Double?
    public let maxLength: Int?
    public let pattern: String?
    public let options: [String]?
    public let multiple: Bool

    public init(
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil,
        options: [String]? = nil,
        multiple: Bool = false
    )
}
```

### InputFieldRegistry

```swift
public struct InputFieldRegistry: Sendable {
    /// All registered input fields.
    public var fields: [String: InputField] { get }

    /// Create an empty registry.
    public init()

    /// Register an input field.
    ///
    /// - Parameter field: The field to register.
    /// - Throws: If a field with the same name already exists.
    public mutating func register(_ field: InputField) throws

    /// Look up a field by name.
    ///
    /// - Parameter name: The field name.
    /// - Returns: The field definition, or nil if not registered.
    public func field(named name: String) -> InputField?

    /// All field names in registration order.
    public var fieldNames: [String] { get }
}
```

### InputValueStore

```swift
public struct InputValueStore: Sendable {
    /// Current values for all fields.
    public var values: [String: ExprValue] { get }

    /// Create a store with default values from the registry.
    public init(registry: InputFieldRegistry)

    /// Get the current value for a field.
    ///
    /// Returns the field's current value, its default value, or `.missing`
    /// if the field is not registered.
    ///
    /// - Parameter name: The field name.
    /// - Returns: The current value.
    public func value(for name: String) -> ExprValue

    /// Set a new value for a field.
    ///
    /// Validates the value against the field's constraints before accepting.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - name: The field name.
    /// - Returns: Whether the value was accepted (passes validation).
    @discardableResult
    public mutating func setValue(_ value: ExprValue, for name: String) -> Bool

    /// Reset a field to its default value.
    public mutating func resetToDefault(name: String)

    /// Reset all fields to their default values.
    public mutating func resetAll()
}
```

## FormContainer and FormTransactionManager

### FormContainer

```swift
public struct FormContainer: Sendable, Equatable {
    /// Unique container identifier.
    public let id: String

    /// Display title.
    public let title: String?

    /// Layout mode.
    public let layout: FormLayout

    /// Whether the container starts collapsed.
    public let collapsed: Bool

    /// Names of fields in this container.
    public let fieldNames: [String]

    public init(
        id: String,
        title: String? = nil,
        layout: FormLayout = .vertical,
        collapsed: Bool = false,
        fieldNames: [String] = []
    )
}

public enum FormLayout: String, Sendable, Equatable {
    case vertical
    case horizontal
    case grid
}
```

### FormTransactionManager

```swift
public struct FormTransactionManager: Sendable {
    /// Create a transaction manager for the given store.
    public init(store: InputValueStore)

    /// Begin a transaction for a form container.
    ///
    /// Changes within a transaction are batched and applied atomically.
    ///
    /// - Parameter containerId: The form container ID.
    public mutating func beginTransaction(for containerId: String)

    /// Record a field change within the current transaction.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - name: The field name.
    public mutating func setValue(_ value: ExprValue, for name: String)

    /// Commit the current transaction, applying all batched changes.
    ///
    /// Returns the set of field names that actually changed (for dependency propagation).
    ///
    /// - Returns: Names of fields whose values changed.
    @discardableResult
    public mutating func commit() -> Set<String>

    /// Rollback the current transaction, discarding all batched changes.
    public mutating func rollback()
}
```

## DependencyGraph and ReactiveEvaluator

### DependencyGraph

```swift
public struct DependencyGraph: Sendable {
    /// Create an empty dependency graph.
    public init()

    /// Add a computable node to the graph.
    ///
    /// - Parameters:
    ///   - id: Unique node identifier (cell reference, expression ID).
    ///   - dependencies: IDs of nodes this node depends on.
    public mutating func addNode(id: String, dependencies: [String])

    /// Validate that the graph has no cycles.
    ///
    /// - Throws: `CycleError` with the full cycle path if a cycle is detected.
    public func validateAcyclicity() throws

    /// Compute a topological ordering of all nodes.
    ///
    /// - Returns: Node IDs in topological order (dependencies before dependents).
    public func topologicalSort() -> [String]

    /// Find all nodes transitively dependent on the given source nodes.
    ///
    /// - Parameter changedNodes: The set of nodes whose values changed.
    /// - Returns: All transitively dependent node IDs, in topological order.
    public func dependents(of changedNodes: Set<String>) -> [String]

    /// Total number of nodes.
    public var nodeCount: Int { get }

    /// Total number of edges.
    public var edgeCount: Int { get }
}

public struct CycleError: Error, Sendable {
    /// The cycle path as an ordered list of node IDs.
    public let cyclePath: [String]
}
```

### ReactiveEvaluator

```swift
public struct ReactiveEvaluator: Sendable {
    /// Create a reactive evaluator with the given graph and engine.
    public init(
        graph: DependencyGraph,
        engine: ExpressionEngine,
        maxNodesPerCycle: Int = 1000
    )

    /// Propagate a set of value changes through the dependency graph.
    ///
    /// Recomputes all transitively dependent expressions in topological order.
    ///
    /// - Parameter changes: Map of changed node IDs to their new values.
    /// - Returns: Map of all recomputed node IDs to their new values.
    public mutating func propagate(changes: [String: ExprValue]) -> [String: ExprValue]

    /// Evaluate all nodes in the graph from scratch.
    ///
    /// Used for initial evaluation when no cached state exists.
    ///
    /// - Returns: Map of all node IDs to their computed values.
    public mutating func evaluateAll() -> [String: ExprValue]

    /// The number of nodes recomputed in the last propagation.
    public var lastPropagationCount: Int { get }
}
```

## BridgeValue and BridgeEncoder

### BridgeValue

```swift
public struct BridgeValue: Sendable, Equatable {
    /// The type tag.
    public let kind: BridgeValueKind

    /// The serialized value.
    public let value: ExprValue

    /// Optional provenance metadata.
    public let metadata: BridgeMetadata?

    public init(
        kind: BridgeValueKind,
        value: ExprValue,
        metadata: BridgeMetadata? = nil
    )
}

public enum BridgeValueKind: String, Sendable, Equatable, CaseIterable {
    case number
    case string
    case bool
    case null
    case array
    case object
    case dataframe
    case image
    case error
}

public struct BridgeMetadata: Sendable, Equatable {
    public let sourceCell: String?
    public let sourceKernel: String?
    public let timestamp: Date?
    public let shape: [Int]?
    public let mimeType: String?

    public init(
        sourceCell: String? = nil,
        sourceKernel: String? = nil,
        timestamp: Date? = nil,
        shape: [Int]? = nil,
        mimeType: String? = nil
    )
}
```

### BridgeEncoder

```swift
public struct BridgeEncoder: Sendable {
    public init()

    /// Encode an `ExprValue` to `$rhoe:kind` tagged JSON data.
    ///
    /// - Parameter value: The expression value to encode.
    /// - Returns: JSON data with `$rhoe:kind` tagged encoding.
    public func encode(_ value: ExprValue) throws -> Data

    /// Encode a `BridgeValue` with metadata to tagged JSON data.
    ///
    /// - Parameter bridgeValue: The bridge value to encode.
    /// - Returns: JSON data with `$rhoe:kind` tagged encoding and metadata.
    public func encode(_ bridgeValue: BridgeValue) throws -> Data
}

public struct BridgeDecoder: Sendable {
    public init()

    /// Decode `$rhoe:kind` tagged JSON data to an `ExprValue`.
    ///
    /// Plain JSON values (without `$rhoe:kind`) are decoded using type inference.
    ///
    /// - Parameter data: JSON data to decode.
    /// - Returns: The decoded expression value.
    public func decode(_ data: Data) throws -> ExprValue

    /// Decode `$rhoe:kind` tagged JSON data to a `BridgeValue` with metadata.
    ///
    /// - Parameter data: JSON data to decode.
    /// - Returns: The decoded bridge value.
    public func decodeBridgeValue(_ data: Data) throws -> BridgeValue
}
```

## NotebookPackage and NotebookManager

### NotebookPackage

```swift
public struct NotebookPackage: Sendable {
    /// The package directory URL.
    public let url: URL

    /// The manifest.
    public let manifest: NotebookManifest

    /// The primary document URL.
    public var documentURL: URL { get }

    /// The state directory URL.
    public var stateURL: URL { get }

    /// The artifacts directory URL.
    public var artifactsURL: URL { get }

    /// The cache directory URL.
    public var cacheURL: URL { get }

    /// Create a package reference from a directory URL.
    ///
    /// - Parameter url: The `.rhoenb` directory URL.
    /// - Throws: If the directory does not contain a valid manifest.
    public init(url: URL) throws
}

public struct NotebookManifest: Sendable, Equatable, Codable {
    public let rhoeNBVersion: String
    public let created: Date
    public let modified: Date
    public let document: String
    public let title: String?
    public let kernels: [String: KernelRequirement]
    public let executionPolicy: ExecutionPolicy
    public let statePolicy: StatePolicy

    public struct KernelRequirement: Sendable, Equatable, Codable {
        public let version: String?
        public let dependencies: String?
    }

    public struct ExecutionPolicy: Sendable, Equatable, Codable {
        public let maxTimeout: String?
        public let maxMemory: String?
        public let network: Bool
        public let filesystem: String?
    }

    public struct StatePolicy: Sendable, Equatable, Codable {
        public let persistence: String
        public let historyPolicy: String
    }
}
```

### NotebookManager

```swift
public struct NotebookManager: Sendable {
    public init()

    /// Create a new notebook package from a document.
    ///
    /// - Parameters:
    ///   - documentURL: The source document URL.
    ///   - outputURL: The output `.rhoenb` directory URL.
    ///   - title: Optional notebook title.
    /// - Returns: The created notebook package.
    public func create(
        from documentURL: URL,
        at outputURL: URL,
        title: String? = nil
    ) throws -> NotebookPackage

    /// Open an existing notebook package.
    ///
    /// - Parameter url: The `.rhoenb` directory URL.
    /// - Returns: The notebook package.
    public func open(at url: URL) throws -> NotebookPackage

    /// Validate a notebook package structure.
    ///
    /// Checks manifest integrity, kernel declarations, and state consistency.
    ///
    /// - Parameter package: The package to validate.
    /// - Returns: Array of validation diagnostics.
    public func validate(_ package: NotebookPackage) -> [NotebookDiagnostic]

    /// Clean all cached state and artifacts from a notebook.
    ///
    /// Removes the `cache/` and `state/` directories, returning the notebook
    /// to its virgin (never-executed) state.
    ///
    /// - Parameter package: The package to clean.
    public func clean(_ package: NotebookPackage) throws

    /// Freeze the notebook's current state for reproducibility.
    ///
    /// Creates a timestamped snapshot in `state/history/`.
    ///
    /// - Parameter package: The package to freeze.
    /// - Returns: The snapshot identifier.
    public func freeze(_ package: NotebookPackage) throws -> String
}

public struct NotebookDiagnostic: Sendable {
    public enum Severity: Sendable {
        case info, warning, error
    }

    public let severity: Severity
    public let message: String
    public let path: String?
}
```

## See Also

- <doc:ExpressionsGuide>
- <doc:InputBindingsGuide>
- <doc:ReactiveModelGuide>
- <doc:ExecutionEngine>
- <doc:APIReference>
