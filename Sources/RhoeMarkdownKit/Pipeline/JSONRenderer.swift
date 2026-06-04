import Foundation
import RhoeMarkdownRendering

public struct JSONRenderer: Sendable {
    public init() {}

    public func render(_ document: RhoeMarkdownKit.Document) -> Data {
        JSONWriter().write(document)
    }
}
