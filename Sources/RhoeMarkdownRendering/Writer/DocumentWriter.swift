import Foundation
import RhoeMarkdownModel

/// Protocol for document output writers.
///
/// Writers transform a parsed `Document` into a specific output format.
/// String-based writers (HTML, LaTeX) produce synchronous output.
/// File-based writers (PPTX, PDF) may extend this with throwing APIs.
public protocol DocumentWriter: Sendable {
    associatedtype Output: Sendable

    /// Write the document to the output format.
    func write(_ document: RhoeMarkdownKit.Document) -> Output
}
