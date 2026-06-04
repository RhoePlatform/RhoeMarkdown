import Foundation
import RhoeMarkdownRendering

public struct EPUBRenderer: Sendable {
    public let configuration: RhoeMarkdownKit.EPUBConfiguration

    public init(configuration: RhoeMarkdownKit.EPUBConfiguration = .default) {
        self.configuration = configuration
    }

    public func render(_ document: RhoeMarkdownKit.Document) -> Data {
        EPUBWriter(configuration: configuration).write(document)
    }
}
