import Foundation

// MARK: - World-Class CSS

extension RhoeHTMLRenderer {

    static let lightModeCSS = """
/* GitHub-inspired world-class styling - Light Mode */
.markdown-body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji';
    font-size: 16px;
    line-height: 1.6;
    word-wrap: break-word;
    color: #24292f;
    background-color: #ffffff;
    max-width: 980px;
    margin: 0 auto;
    padding: 45px;
}

@media (max-width: 767px) {
    .markdown-body {
        padding: 15px;
    }
}

/* Headings */
.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4,
.markdown-body h5,
.markdown-body h6 {
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
    line-height: 1.25;
}

.markdown-body h1 {
    font-size: 2em;
    padding-bottom: 0.3em;
    border-bottom: 1px solid #d1d9e0;
}

.markdown-body h2 {
    font-size: 1.5em;
    padding-bottom: 0.3em;
    border-bottom: 1px solid #d1d9e0;
}

.markdown-body h3 {
    font-size: 1.25em;
}

.markdown-body h4 {
    font-size: 1em;
}

.markdown-body h5 {
    font-size: 0.875em;
}

.markdown-body h6 {
    font-size: 0.85em;
    color: #57606a;
}

/* Paragraphs and text */
.markdown-body p {
    margin-top: 0;
    margin-bottom: 16px;
}

.markdown-body strong {
    font-weight: 600;
}

.markdown-body em {
    font-style: italic;
}

.markdown-body del {
    text-decoration: line-through;
}

/* Links */
.markdown-body a {
    color: #0969da;
    text-decoration: none;
    background-color: transparent;
}

.markdown-body a:hover {
    text-decoration: underline;
}

.markdown-body a:active {
    color: #0860ca;
}

/* Code */
.markdown-body code {
    padding: 0.2em 0.4em;
    margin: 0;
    font-size: 85%;
    white-space: normal;
    background-color: rgba(175, 184, 193, 0.2);
    border-radius: 6px;
    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace;
}

.markdown-body pre {
    margin-top: 0;
    margin-bottom: 16px;
    padding: 16px;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    background-color: #f6f8fa;
    border-radius: 6px;
}

.markdown-body pre code {
    display: inline;
    max-width: auto;
    padding: 0;
    margin: 0;
    overflow: visible;
    line-height: inherit;
    word-wrap: normal;
    background-color: transparent;
    border: 0;
}

/* Blockquotes */
.markdown-body blockquote {
    margin: 0 0 16px 0;
    padding: 0 1em;
    color: #57606a;
    border-left: 0.25em solid #d1d9e0;
}

.markdown-body blockquote > :first-child {
    margin-top: 0;
}

.markdown-body blockquote > :last-child {
    margin-bottom: 0;
}

/* Lists */
.markdown-body ul,
.markdown-body ol {
    margin-top: 0;
    margin-bottom: 16px;
    padding-left: 2em;
}

.markdown-body ul ul,
.markdown-body ul ol,
.markdown-body ol ol,
.markdown-body ol ul {
    margin-top: 0;
    margin-bottom: 0;
}

.markdown-body li {
    word-wrap: break-all;
}

.markdown-body li > p {
    margin-top: 16px;
}

.markdown-body li + li {
    margin-top: 0.25em;
}

/* Task lists */
.markdown-body .task-list-item {
    list-style-type: none;
}

.markdown-body .task-list-item + .task-list-item {
    margin-top: 3px;
}

.markdown-body .task-list-item-checkbox {
    margin: 0 0.2em 0.25em -1.6em;
    vertical-align: middle;
}

/* Tables */
.markdown-body table {
    display: block;
    width: 100%;
    width: max-content;
    max-width: 100%;
    overflow: auto;
    border-spacing: 0;
    border-collapse: collapse;
    margin-top: 0;
    margin-bottom: 16px;
}

.markdown-body table th {
    font-weight: 600;
}

.markdown-body table th,
.markdown-body table td {
    padding: 6px 13px;
    border: 1px solid #d1d9e0;
}

.markdown-body table tr {
    background-color: #ffffff;
    border-top: 1px solid #d1d9e0;
}

.markdown-body table tr:nth-child(2n) {
    background-color: #f6f8fa;
}

/* Definition lists */
.markdown-body dl {
    margin-top: 0;
    margin-bottom: 16px;
}

.markdown-body dt {
    margin-top: 16px;
    font-weight: 600;
    font-style: italic;
}

.markdown-body dd {
    margin-bottom: 16px;
    margin-left: 0;
    padding-left: 16px;
}

/* Horizontal rules */
.markdown-body hr {
    height: 0.25em;
    padding: 0;
    margin: 24px 0;
    background-color: #d1d9e0;
    border: 0;
}

/* Images */
.markdown-body img {
    max-width: 100%;
    box-sizing: content-box;
    background-color: #ffffff;
}

.markdown-body img[align=right] {
    padding-left: 20px;
}

.markdown-body img[align=left] {
    padding-right: 20px;
}

/* Syntax highlighting base colors */
.language-swift .keyword { color: #cf222e; }
.language-swift .string { color: #0a3069; }
.language-swift .comment { color: #57606a; }
.language-swift .function { color: #8250df; }
.language-swift .number { color: #0550ae; }

.language-javascript .keyword { color: #cf222e; }
.language-javascript .string { color: #0a3069; }
.language-javascript .comment { color: #57606a; }
.language-javascript .function { color: #8250df; }
.language-javascript .number { color: #0550ae; }

/* Admonitions - SSG-Standard Styling */
.admonition {
    margin: 1.5em 0;
    padding: 0;
    border-left: 4px solid;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
    overflow: hidden;
}

.admonition-title {
    margin: 0;
    padding: 0.75em 1em;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 0.5em;
}

.admonition-icon {
    font-size: 1.2em;
    line-height: 1;
}

.admonition-content {
    padding: 0.75em 1em;
}

.admonition-content > :first-child {
    margin-top: 0;
}

.admonition-content > :last-child {
    margin-bottom: 0;
}

/* Note/Info - Blue */
.admonition-note, .admonition-info {
    border-color: #2196f3;
    background-color: #e3f2fd;
}

.admonition-note .admonition-title, .admonition-info .admonition-title {
    background-color: #2196f3;
    color: white;
}

/* Tip/Hint - Green */
.admonition-tip, .admonition-hint {
    border-color: #4caf50;
    background-color: #e8f5e9;
}

.admonition-tip .admonition-title, .admonition-hint .admonition-title {
    background-color: #4caf50;
    color: white;
}

/* Success/Check - Green */
.admonition-success, .admonition-check {
    border-color: #4caf50;
    background-color: #e8f5e9;
}

.admonition-success .admonition-title, .admonition-check .admonition-title {
    background-color: #4caf50;
    color: white;
}

/* Warning/Caution - Orange */
.admonition-warning, .admonition-caution {
    border-color: #ff9800;
    background-color: #fff3e0;
}

.admonition-warning .admonition-title, .admonition-caution .admonition-title {
    background-color: #ff9800;
    color: white;
}

/* Danger/Error - Red */
.admonition-danger, .admonition-error {
    border-color: #f44336;
    background-color: #ffebee;
}

.admonition-danger .admonition-title, .admonition-error .admonition-title {
    background-color: #f44336;
    color: white;
}

/* Important - Purple */
.admonition-important {
    border-color: #9c27b0;
    background-color: #f3e5f5;
}

.admonition-important .admonition-title {
    background-color: #9c27b0;
    color: white;
}

/* Question/Help/FAQ - Light Blue */
.admonition-question, .admonition-help, .admonition-faq {
    border-color: #00bcd4;
    background-color: #e0f7fa;
}

.admonition-question .admonition-title, .admonition-help .admonition-title, .admonition-faq .admonition-title {
    background-color: #00bcd4;
    color: white;
}

/* Quote/Cite - Gray */
.admonition-quote, .admonition-cite {
    border-color: #607d8b;
    background-color: #eceff1;
}

.admonition-quote .admonition-title, .admonition-cite .admonition-title {
    background-color: #607d8b;
    color: white;
}

/* Example - Indigo */
.admonition-example {
    border-color: #3f51b5;
    background-color: #e8eaf6;
}

.admonition-example .admonition-title {
    background-color: #3f51b5;
    color: white;
}

/* Abstract/Summary/TLDR - Deep Purple */
.admonition-abstract, .admonition-summary, .admonition-tldr {
    border-color: #673ab7;
    background-color: #ede7f6;
}

.admonition-abstract .admonition-title, .admonition-summary .admonition-title, .admonition-tldr .admonition-title {
    background-color: #673ab7;
    color: white;
}

/* Bug - Pink */
.admonition-bug {
    border-color: #e91e63;
    background-color: #fce4ec;
}

.admonition-bug .admonition-title {
    background-color: #e91e63;
    color: white;
}

/* Failure/Fail/Missing - Red */
.admonition-failure, .admonition-fail, .admonition-missing {
    border-color: #f44336;
    background-color: #ffebee;
}

.admonition-failure .admonition-title, .admonition-fail .admonition-title, .admonition-missing .admonition-title {
    background-color: #f44336;
    color: white;
}

/* Collapsible admonitions */
details.admonition summary {
    cursor: pointer;
    user-select: none;
}

details.admonition summary::-webkit-details-marker {
    display: none;
}

details.admonition summary::before {
    content: "\u{25B6}";
    margin-right: 0.5em;
    transition: transform 0.2s;
}

details.admonition[open] summary::before {
    transform: rotate(90deg);
}
"""

    static let darkModeCSS = """
/* GitHub-inspired world-class styling - Dark Mode */
.markdown-body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji';
    font-size: 16px;
    line-height: 1.6;
    word-wrap: break-word;
    color: #c9d1d9;
    background-color: #0d1117;
    max-width: 980px;
    margin: 0 auto;
    padding: 45px;
}

@media (max-width: 767px) {
    .markdown-body {
        padding: 15px;
    }
}

/* Headings */
.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4,
.markdown-body h5,
.markdown-body h6 {
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
    line-height: 1.25;
    color: #f0f6fc;
}

.markdown-body h1 {
    font-size: 2em;
    padding-bottom: 0.3em;
    border-bottom: 1px solid #30363d;
}

.markdown-body h2 {
    font-size: 1.5em;
    padding-bottom: 0.3em;
    border-bottom: 1px solid #30363d;
}

.markdown-body h3 {
    font-size: 1.25em;
}

.markdown-body h4 {
    font-size: 1em;
}

.markdown-body h5 {
    font-size: 0.875em;
}

.markdown-body h6 {
    font-size: 0.85em;
    color: #8b949e;
}

/* Paragraphs and text */
.markdown-body p {
    margin-top: 0;
    margin-bottom: 16px;
}

.markdown-body strong {
    font-weight: 600;
}

.markdown-body em {
    font-style: italic;
}

.markdown-body del {
    text-decoration: line-through;
}

/* Links */
.markdown-body a {
    color: #58a6ff;
    text-decoration: none;
    background-color: transparent;
}

.markdown-body a:hover {
    text-decoration: underline;
}

.markdown-body a:active {
    color: #79c0ff;
}

/* Code */
.markdown-body code {
    padding: 0.2em 0.4em;
    margin: 0;
    font-size: 85%;
    white-space: normal;
    background-color: rgba(110, 118, 129, 0.4);
    border-radius: 6px;
    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace;
}

.markdown-body pre {
    margin-top: 0;
    margin-bottom: 16px;
    padding: 16px;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    background-color: #161b22;
    border-radius: 6px;
}

.markdown-body pre code {
    display: inline;
    max-width: auto;
    padding: 0;
    margin: 0;
    overflow: visible;
    line-height: inherit;
    word-wrap: normal;
    background-color: transparent;
    border: 0;
}

/* Blockquotes */
.markdown-body blockquote {
    margin: 0 0 16px 0;
    padding: 0 1em;
    color: #8b949e;
    border-left: 0.25em solid #30363d;
}

.markdown-body blockquote > :first-child {
    margin-top: 0;
}

.markdown-body blockquote > :last-child {
    margin-bottom: 0;
}

/* Lists */
.markdown-body ul,
.markdown-body ol {
    margin-top: 0;
    margin-bottom: 16px;
    padding-left: 2em;
}

.markdown-body ul ul,
.markdown-body ul ol,
.markdown-body ol ol,
.markdown-body ol ul {
    margin-top: 0;
    margin-bottom: 0;
}

.markdown-body li {
    word-wrap: break-all;
}

.markdown-body li > p {
    margin-top: 16px;
}

.markdown-body li + li {
    margin-top: 0.25em;
}

/* Task lists */
.markdown-body .task-list-item {
    list-style-type: none;
}

.markdown-body .task-list-item + .task-list-item {
    margin-top: 3px;
}

.markdown-body .task-list-item-checkbox {
    margin: 0 0.2em 0.25em -1.6em;
    vertical-align: middle;
}

/* Tables */
.markdown-body table {
    display: block;
    width: 100%;
    width: max-content;
    max-width: 100%;
    overflow: auto;
    border-spacing: 0;
    border-collapse: collapse;
    margin-top: 0;
    margin-bottom: 16px;
}

.markdown-body table th {
    font-weight: 600;
}

.markdown-body table th,
.markdown-body table td {
    padding: 6px 13px;
    border: 1px solid #30363d;
}

.markdown-body table tr {
    background-color: #0d1117;
    border-top: 1px solid #30363d;
}

.markdown-body table tr:nth-child(2n) {
    background-color: #161b22;
}

/* Definition lists */
.markdown-body dl {
    margin-top: 0;
    margin-bottom: 16px;
}

.markdown-body dt {
    margin-top: 16px;
    font-weight: 600;
    font-style: italic;
    color: #f0f6fc;
}

.markdown-body dd {
    margin-bottom: 16px;
    margin-left: 0;
    padding-left: 16px;
}

/* Horizontal rules */
.markdown-body hr {
    height: 0.25em;
    padding: 0;
    margin: 24px 0;
    background-color: #30363d;
    border: 0;
}

/* Images */
.markdown-body img {
    max-width: 100%;
    box-sizing: content-box;
    background-color: #0d1117;
}

.markdown-body img[align=right] {
    padding-left: 20px;
}

.markdown-body img[align=left] {
    padding-right: 20px;
}

/* Syntax highlighting dark mode colors */
.language-swift .keyword { color: #ff7b72; }
.language-swift .string { color: #a5d6ff; }
.language-swift .comment { color: #8b949e; }
.language-swift .function { color: #d2a8ff; }
.language-swift .number { color: #79c0ff; }

.language-javascript .keyword { color: #ff7b72; }
.language-javascript .string { color: #a5d6ff; }
.language-javascript .comment { color: #8b949e; }
.language-javascript .function { color: #d2a8ff; }
.language-javascript .number { color: #79c0ff; }
"""
}
