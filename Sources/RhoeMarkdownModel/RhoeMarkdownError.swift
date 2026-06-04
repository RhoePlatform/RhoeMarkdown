import Foundation

public enum RhoeMarkdownError: Error, LocalizedError, Sendable {
    case parsing(String)
    case invalidInput(String)
    case notFound(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .parsing(let message):
            return message
        case .invalidInput(let message):
            return message
        case .notFound(let message):
            return message
        case .unsupported(let message):
            return message
        }
    }
}
