import Foundation

/// Default CSS stylesheet for RhoeMarkdown HTML output.
///
/// Uses CSS custom properties for theming. All styles target `.rhoe-*` classes
/// and `[data-rhoe-node]` selectors, ensuring zero conflict with host page styles.
public struct RhoeDefaultCSS: Sendable {

    public static let stylesheet: String = """
    /* RhoeMarkdown Default Stylesheet */

    :root {
        --rhoe-space-xs: 0.25rem;
        --rhoe-space-sm: 0.5rem;
        --rhoe-space-md: 1rem;
        --rhoe-space-lg: 1.5rem;
        --rhoe-space-xl: 2rem;

        --rhoe-color-text: #1a1a1a;
        --rhoe-color-bg: #ffffff;
        --rhoe-color-accent: #2563eb;
        --rhoe-color-border: #e5e7eb;
        --rhoe-color-muted: #6b7280;

        --rhoe-color-note: #3b82f6;
        --rhoe-color-tip: #10b981;
        --rhoe-color-warning: #f59e0b;
        --rhoe-color-danger: #ef4444;
        --rhoe-color-important: #8b5cf6;

        --rhoe-font-body: system-ui, -apple-system, 'Segoe UI', sans-serif;
        --rhoe-font-mono: ui-monospace, 'SF Mono', 'Cascadia Code', monospace;
        --rhoe-font-size-base: 1rem;
        --rhoe-line-height: 1.6;

        --rhoe-radius-sm: 0.25rem;
        --rhoe-radius-md: 0.5rem;
    }

    /* Document */
    .rhoe-document {
        font-family: var(--rhoe-font-body);
        font-size: var(--rhoe-font-size-base);
        line-height: var(--rhoe-line-height);
        color: var(--rhoe-color-text);
        max-width: 48rem;
        margin: 0 auto;
        padding: var(--rhoe-space-lg);
    }

    /* Headings */
    [data-rhoe-node="heading"] {
        margin-top: var(--rhoe-space-xl);
        margin-bottom: var(--rhoe-space-md);
        line-height: 1.25;
    }

    /* Paragraphs */
    [data-rhoe-node="paragraph"] {
        margin-bottom: var(--rhoe-space-md);
    }

    /* Block Quotes */
    [data-rhoe-node="blockquote"] {
        border-left: 4px solid var(--rhoe-color-border);
        padding-left: var(--rhoe-space-md);
        margin: var(--rhoe-space-md) 0;
        color: var(--rhoe-color-muted);
    }

    /* Code Blocks */
    [data-rhoe-node="code"] {
        font-family: var(--rhoe-font-mono);
        background: #f3f4f6;
        padding: var(--rhoe-space-md);
        border-radius: var(--rhoe-radius-md);
        overflow-x: auto;
        font-size: 0.875em;
    }

    /* Inline Code */
    code:not([data-rhoe-node]) {
        font-family: var(--rhoe-font-mono);
        background: #f3f4f6;
        padding: 0.15rem 0.35rem;
        border-radius: var(--rhoe-radius-sm);
        font-size: 0.875em;
    }

    /* Admonitions */
    .rhoe-admonition {
        border-left: 4px solid var(--rhoe-color-note);
        background: #f0f7ff;
        padding: var(--rhoe-space-md);
        margin: var(--rhoe-space-md) 0;
        border-radius: 0 var(--rhoe-radius-md) var(--rhoe-radius-md) 0;
    }
    .rhoe-admonition.rhoe-tip { border-color: var(--rhoe-color-tip); background: #f0fdf4; }
    .rhoe-admonition.rhoe-warning { border-color: var(--rhoe-color-warning); background: #fffbeb; }
    .rhoe-admonition.rhoe-danger { border-color: var(--rhoe-color-danger); background: #fef2f2; }
    .rhoe-admonition.rhoe-important { border-color: var(--rhoe-color-important); background: #f5f3ff; }

    .rhoe-admonition-title {
        font-weight: 600;
        margin-bottom: var(--rhoe-space-sm);
    }

    /* Theorem Environments */
    .rhoe-theorem {
        border: 1px solid var(--rhoe-color-border);
        padding: var(--rhoe-space-md);
        margin: var(--rhoe-space-md) 0;
        border-radius: var(--rhoe-radius-md);
    }
    .rhoe-theorem-header {
        font-weight: 600;
        margin-bottom: var(--rhoe-space-sm);
    }
    .rhoe-theorem-label { margin-right: var(--rhoe-space-xs); }
    .rhoe-theorem-title { font-style: italic; }
    .rhoe-proof .rhoe-theorem-header { font-style: italic; font-weight: 400; }

    /* Tables */
    .rhoe-table-container { margin: var(--rhoe-space-md) 0; overflow-x: auto; }
    .rhoe-table {
        border-collapse: collapse;
        width: 100%;
    }
    .rhoe-table th, .rhoe-table td {
        border: 1px solid var(--rhoe-color-border);
        padding: var(--rhoe-space-sm) var(--rhoe-space-md);
        text-align: left;
    }
    .rhoe-table thead th {
        background: #f9fafb;
        font-weight: 600;
    }

    /* Figures */
    .rhoe-figure {
        margin: var(--rhoe-space-lg) 0;
        text-align: center;
    }
    .rhoe-figure img { max-width: 100%; height: auto; }
    .rhoe-figure figcaption {
        font-size: 0.875em;
        color: var(--rhoe-color-muted);
        margin-top: var(--rhoe-space-sm);
    }

    /* Lists */
    [data-rhoe-node="list"] { margin: var(--rhoe-space-md) 0; }

    /* Horizontal Rule */
    hr { border: none; border-top: 1px solid var(--rhoe-color-border); margin: var(--rhoe-space-xl) 0; }

    /* Visual Blocks */
    .rhoe-visual-block {
        margin: var(--rhoe-space-md) 0;
        padding: var(--rhoe-space-md);
        border: 1px dashed var(--rhoe-color-border);
        border-radius: var(--rhoe-radius-md);
    }

    /* Placeholders */
    .rhoe-placeholder {
        display: inline-block;
        background: #fef3c7;
        border: 1px solid #fcd34d;
        padding: 0.15rem 0.5rem;
        border-radius: var(--rhoe-radius-sm);
        font-style: italic;
        font-size: 0.875em;
    }

    /* Expressions */
    .rhoe-expression {
        font-family: var(--rhoe-font-mono);
        background: #fef3c7;
        padding: 0.1rem 0.3rem;
        border-radius: var(--rhoe-radius-sm);
        font-size: 0.875em;
    }

    /* Input Fields */
    .rhoe-field {
        margin: var(--rhoe-space-md) 0;
    }
    .rhoe-field label {
        display: block;
        font-weight: 600;
        margin-bottom: var(--rhoe-space-xs);
    }
    .rhoe-field input,
    .rhoe-field select,
    .rhoe-field textarea {
        width: 100%;
        padding: var(--rhoe-space-sm);
        border: 1px solid var(--rhoe-color-border);
        border-radius: var(--rhoe-radius-sm);
        font-family: inherit;
        font-size: inherit;
    }

    /* Forms */
    .rhoe-form {
        margin: var(--rhoe-space-lg) 0;
        padding: var(--rhoe-space-md);
        border: 1px solid var(--rhoe-color-border);
        border-radius: var(--rhoe-radius-md);
    }

    /* Dark Mode */
    @media (prefers-color-scheme: dark) {
        :root {
            --rhoe-color-text: #e5e7eb;
            --rhoe-color-bg: #111827;
            --rhoe-color-border: #374151;
            --rhoe-color-muted: #9ca3af;
        }
        .rhoe-admonition { background: #1e293b; }
        .rhoe-admonition.rhoe-tip { background: #064e3b; }
        .rhoe-admonition.rhoe-warning { background: #451a03; }
        .rhoe-admonition.rhoe-danger { background: #450a0a; }
        [data-rhoe-node="code"], code:not([data-rhoe-node]) { background: #1f2937; }
        .rhoe-table thead th { background: #1f2937; }
    }
    """
}
