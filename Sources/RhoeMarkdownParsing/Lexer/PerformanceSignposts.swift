import Foundation
#if canImport(os)
import os.signpost
#endif

// MARK: - Performance Signposts for Instruments

/// Zero-cost signpost instrumentation for the RhoeMarkdown compiler pipeline.
///
/// On Apple platforms with os.signpost, signpost intervals appear as named regions
/// in Instruments. On other platforms (including Wasm), all methods are no-ops.
public enum Signposts {

    #if canImport(os)
    // MARK: - Signpost Logs (Apple platforms)

    @usableFromInline static let lexerLog = OSLog(subsystem: "com.rhoe.markdown", category: "Lexer")
    @usableFromInline static let parserLog = OSLog(subsystem: "com.rhoe.markdown", category: "Parser")
    @usableFromInline static let pipelineLog = OSLog(subsystem: "com.rhoe.markdown", category: "Pipeline")
    @usableFromInline static let renderLog = OSLog(subsystem: "com.rhoe.markdown", category: "Renderer")
    @usableFromInline static let projectLog = OSLog(subsystem: "com.rhoe.markdown", category: "Project")

    @inlinable @inline(__always)
    public static func beginLexing(_ log: StaticString = "Tokenize", id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: lexerLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func endLexing(_ log: StaticString = "Tokenize", id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: lexerLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func beginParsing(_ log: StaticString = "Parse", id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: parserLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func endParsing(_ log: StaticString = "Parse", id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: parserLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func beginPass(_ log: StaticString = "Pass", id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: pipelineLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func endPass(_ log: StaticString = "Pass", id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: pipelineLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func beginRendering(_ log: StaticString = "Render", id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: renderLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func endRendering(_ log: StaticString = "Render", id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: renderLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func beginBuild(_ log: StaticString = "Build", id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: projectLog, name: log, signpostID: id)
    }
    @inlinable @inline(__always)
    public static func endBuild(_ log: StaticString = "Build", id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: projectLog, name: log, signpostID: id)
    }

    @inlinable
    public static func measure<T>(_ name: StaticString, log: OSLog = pipelineLog, body: () throws -> T) rethrows -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        defer { os_signpost(.end, log: log, name: name, signpostID: id) }
        return try body()
    }

    @inlinable
    public static func measureAsync<T>(_ name: StaticString, log: OSLog = pipelineLog, body: () async throws -> T) async rethrows -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        defer { os_signpost(.end, log: log, name: name, signpostID: id) }
        return try await body()
    }

    #else
    // MARK: - No-op Stubs (Wasm / non-Apple platforms)

    @inlinable @inline(__always) public static func beginLexing(_ log: StaticString = "Tokenize") {}
    @inlinable @inline(__always) public static func endLexing(_ log: StaticString = "Tokenize") {}
    @inlinable @inline(__always) public static func beginParsing(_ log: StaticString = "Parse") {}
    @inlinable @inline(__always) public static func endParsing(_ log: StaticString = "Parse") {}
    @inlinable @inline(__always) public static func beginPass(_ log: StaticString = "Pass") {}
    @inlinable @inline(__always) public static func endPass(_ log: StaticString = "Pass") {}
    @inlinable @inline(__always) public static func beginRendering(_ log: StaticString = "Render") {}
    @inlinable @inline(__always) public static func endRendering(_ log: StaticString = "Render") {}
    @inlinable @inline(__always) public static func beginBuild(_ log: StaticString = "Build") {}
    @inlinable @inline(__always) public static func endBuild(_ log: StaticString = "Build") {}

    @inlinable
    public static func measure<T>(_ name: StaticString, body: () throws -> T) rethrows -> T {
        return try body()
    }
    @inlinable
    public static func measureAsync<T>(_ name: StaticString, body: () async throws -> T) async rethrows -> T {
        return try await body()
    }
    #endif
}
