import Foundation

// MARK: - Page Size Types (Available on all platforms)

/// PDF page size options.
public enum PDFPageSize: Sendable, Equatable {
    case a4
    case letter
    case landscape16x9
    case custom(width: Double, height: Double)

    /// Width in points (1 point = 1/72 inch).
    public var width: Double {
        switch self {
        case .a4: return 595.28
        case .letter: return 612.0
        case .landscape16x9: return 1024.0
        case .custom(let w, _): return w
        }
    }

    /// Height in points.
    public var height: Double {
        switch self {
        case .a4: return 841.89
        case .letter: return 792.0
        case .landscape16x9: return 768.0
        case .custom(_, let h): return h
        }
    }

    /// Initialize from a string name.
    public init?(name: String) {
        switch name.lowercased() {
        case "a4": self = .a4
        case "letter": self = .letter
        case "landscape", "16x9", "landscape16x9": self = .landscape16x9
        default: return nil
        }
    }
}

/// PDF page orientation.
public enum PDFPageOrientation: String, Sendable, Equatable {
    case portrait
    case landscape
}

/// PDF page margins in points.
public struct PDFPageMargins: Sendable, Equatable {
    public let top: Double
    public let right: Double
    public let bottom: Double
    public let left: Double

    public init(top: Double, right: Double, bottom: Double, left: Double) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    /// 1-inch margins (72 points each side).
    public static let `default` = PDFPageMargins(top: 72, right: 72, bottom: 72, left: 72)
    /// No margins.
    public static let none = PDFPageMargins(top: 0, right: 0, bottom: 0, left: 0)
    /// Narrow margins (0.5 inch).
    public static let narrow = PDFPageMargins(top: 36, right: 36, bottom: 36, left: 36)
}

// MARK: - Print CSS

/// CSS rules for print/PDF rendering.
public struct RhoePrintCSS: Sendable {

    /// Document print CSS (paginated A4/Letter).
    public static func documentCSS(pageSize: PDFPageSize, orientation: PDFPageOrientation) -> String {
        let sizeName = pageSize == .letter ? "letter" : "A4"
        let orientName = orientation == .landscape ? "landscape" : "portrait"
        return """
        @page {
            size: \(sizeName) \(orientName);
            margin: 1in;
        }
        @media print {
            body { margin: 0; padding: 0; }
            .rhoe-document { max-width: none; padding: 0; margin: 0; }
            h1, h2, h3, h4 { page-break-after: avoid; }
            pre, blockquote, table, figure { page-break-inside: avoid; }
            img { max-width: 100%; }
        }
        """
    }

    /// Slide print CSS (one slide per page, landscape).
    public static let slideCSS: String = """
    @page { size: landscape; margin: 0; }
    * { box-sizing: border-box; }
    body { margin: 0; padding: 0; }
    .rhoe-slide-page {
        width: 100vw;
        height: 100vh;
        page-break-after: always;
        display: flex;
        flex-direction: column;
        justify-content: center;
        padding: 2rem 3rem;
        font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
        font-size: 1.5rem;
        line-height: 1.4;
    }
    .rhoe-slide-page:last-child { page-break-after: auto; }
    .rhoe-slide-page h1 { font-size: 2.5rem; margin: 0 0 1rem; }
    .rhoe-slide-page h2 { font-size: 2rem; margin: 0 0 0.75rem; }
    .rhoe-slide-page h3 { font-size: 1.75rem; margin: 0 0 0.5rem; }
    .rhoe-slide-page ul, .rhoe-slide-page ol { margin: 0.5rem 0; padding-left: 1.5em; }
    .rhoe-slide-page pre { font-size: 1rem; padding: 1rem; background: #f3f4f6; border-radius: 0.5rem; }
    .rhoe-slide-page code { font-size: 0.875em; }
    .rhoe-slide-page img { max-width: 100%; max-height: 60vh; }
    """
}

// MARK: - WebKit PDF Renderer (Apple Platforms Only)

#if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))

import WebKit

/// Renders HTML content to paginated PDF using WebKit's native PDF generation.
///
/// Uses WKWebView's `pdf(configuration:)` for high-fidelity rendering
/// with full CSS support including `@page` rules, media queries, and print styles.
@MainActor
public final class WebKitPDFRenderer: NSObject {

    public override init() {
        super.init()
    }

    /// Render an HTML string to PDF data.
    public func renderPDF(
        html: String,
        pageSize: PDFPageSize = .a4,
        orientation: PDFPageOrientation = .portrait,
        margins: PDFPageMargins = .default,
        baseURL: URL? = nil
    ) async throws -> Data {
        let effectiveWidth: Double
        let effectiveHeight: Double
        switch orientation {
        case .portrait:
            effectiveWidth = pageSize.width
            effectiveHeight = pageSize.height
        case .landscape:
            effectiveWidth = pageSize.height
            effectiveHeight = pageSize.width
        }

        let frame = CGRect(x: 0, y: 0, width: effectiveWidth, height: effectiveHeight)
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(frame: frame, configuration: config)

        // Load HTML
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = PDFNavigationDelegate(continuation: continuation)
            webView.navigationDelegate = delegate
            objc_setAssociatedObject(webView, "pdfNavDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        // Brief delay for CSS layout
        try await Task.sleep(for: .milliseconds(150))

        // Generate PDF
        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = CGRect(x: 0, y: 0, width: effectiveWidth, height: effectiveHeight)

        return try await webView.pdf(configuration: pdfConfig)
    }
}

/// Navigation delegate for WebKit PDF rendering.
private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, any Error>?

    init(continuation: CheckedContinuation<Void, any Error>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

#endif
