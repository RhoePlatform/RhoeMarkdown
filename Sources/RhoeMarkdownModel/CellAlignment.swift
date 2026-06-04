import Foundation

/// Alignment options for grid cells and slide layout content.
public enum CellAlignment: String, Sendable, Equatable {
    case topLeft = "top-left"
    case topCenter = "top-center"
    case topRight = "top-right"
    case centerLeft = "center-left"
    case center = "center"
    case centerRight = "center-right"
    case bottomLeft = "bottom-left"
    case bottomCenter = "bottom-center"
    case bottomRight = "bottom-right"

    public static let `default` = CellAlignment.topLeft

    public var cssProperties: (justifyContent: String, alignItems: String) {
        switch self {
        case .topLeft:
            return ("flex-start", "flex-start")
        case .topCenter:
            return ("center", "flex-start")
        case .topRight:
            return ("flex-end", "flex-start")
        case .centerLeft:
            return ("flex-start", "center")
        case .center:
            return ("center", "center")
        case .centerRight:
            return ("flex-end", "center")
        case .bottomLeft:
            return ("flex-start", "flex-end")
        case .bottomCenter:
            return ("center", "flex-end")
        case .bottomRight:
            return ("flex-end", "flex-end")
        }
    }
}
