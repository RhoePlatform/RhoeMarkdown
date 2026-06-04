# External Markdown Conformance

RhoeMarkdown includes a pinned external conformance lane for the official
CommonMark and GitHub Flavored Markdown example suites.

## Upstream Pins

| Suite | Version | Upstream ref | Extracted examples |
| --- | --- | --- | ---: |
| CommonMark | `0.31.2` | `9103e341a973013013bb1a80e13567007c5cef6f` | 652 |
| GitHub Flavored Markdown | `0.29.0.gfm.13` | `587a12bb54d95ac37241377e6ddc93ea0e45439b` | 648 |

Regenerate fixtures with:

```bash
bash Scripts/CI/fetch-external-conformance.sh
```

The fetch script verifies SHA-256 checksums before rewriting
`Tests/ExternalConformance/commonmark/spec.json` and
`Tests/ExternalConformance/gfm/spec.json`.

## Current Audit Baseline

As of the current staging sprint, the strict semantic conformance gate reports:

| Suite | Passes | Total | Pass rate |
| --- | ---: | ---: | ---: |
| CommonMark | 652 | 652 | 100.00% |
| GitHub Flavored Markdown | 648 | 648 | 100.00% |

Run the strict zero-failure gate with:

```bash
bash Scripts/CI/validate-external-conformance.sh
```

If a future upstream fixture refresh is intentionally being audited before it
becomes a release gate, maintainers can temporarily set a failure budget:

```bash
RHOE_MARKDOWN_EXTERNAL_CONFORMANCE_FAILURE_BUDGET=2000 \
  bash Scripts/CI/validate-external-conformance.sh
```

Reports are written to `.build/reports/external-conformance/`.

## Current Gap Clusters

There are no current residual clusters in the pinned semantic conformance lane.
The strict zero-failure gate passes for both upstream suites.

| Area | CommonMark residuals | GFM residuals | Current status |
| --- | ---: | ---: | --- |
| Pinned suites | 0 | 0 | CommonMark 0.31.2 and GFM 0.29.0.gfm.13 pass at 100% with semantic normalization. |

This sprint retired or reduced several targeted clusters:

| Area | Result |
| --- | --- |
| External conformance burn-down | Semantic conformance improved from 593/652 to 652/652 for CommonMark and from 589/648 to 648/648 for GFM during this staging sprint. |
| Links and references | CommonMark and GFM Links are now fully retired. Nested bracket labels, nested-link suppression, formatted reference-label parsing, code-span precedence, malformed-label rollback, literal emphasis delimiters inside destinations, escaped angle-destination closers, image alt text, and shortcut labels ending in delimiters are covered by focused regressions. |
| Raw inline HTML in failed links | Failed angle destinations now preserve valid inline HTML fallback for CommonMark examples such as `[a](<b>c)`, while escaped raw HTML and escaped angle-link closers remain protected by sentinel-aware parsing and rendering. |
| Multiline raw HTML attributes | Open tags with multiline quoted values, boolean attributes, and colon-bearing attributes now pass through as CommonMark raw HTML while known-invalid raw tags still fall back to escaped text. |
| Block quote container conformance | Unmarked paragraph continuation lines now remain inside open block quotes, repeated lazy lines preserve soft-break boundaries, equals-style setext-looking lazy lines remain literal, indented list-marker-looking continuation lines remain literal, empty block quote containers render canonically in strict and GitHub flavors, absolute marker depths render nested containers, mixed-depth marker lines lazily continue nested paragraphs, nested list-item blockquotes accept lazy continuation, quoted blank lines keep following partial markers inside the same quote, and unclosed fenced-code block quotes still stop before outside content. |
| Tab-column conformance | Leading tab indentation now preserves residual virtual columns as spaces when stripping indentation, list marker padding overflow preserves tab remainders, tabs immediately after quote markers preserve CommonMark's optional-marker-space remainder, and the pinned Tabs section no longer appears in CommonMark/GFM failure reports. |
| HTML blocks and raw HTML | CommonMark block-level tags now pass through until blank lines, `<pre>/<style>/<script>/<textarea>`-style blocks consume through opening-block closing tags, closing `</pre>`-family tags resume as inline HTML when Markdown continues inside an outer raw block, valid inline raw HTML passes through, invalid raw tags fall back to escaped text, unclosed math-like `$` text inside raw HTML no longer escapes the block-consumption line range, and CDATA/comment/declaration/processing-instruction tokens no longer overconsume following Markdown after their closing sequence. |
| Direct inline links | Parenthesized destinations now roll back on invalid input, reject bare destinations with spaces, percent-encode spaces in angle destinations, handle `)` inside angle destinations, unescape balanced bare parentheses, collect escaped destination/title tokens, preserve text after a closing parenthesis, and parse emphasized inline link labels. |
| Reference definitions | Forward references, duplicate-first-wins behavior, blockquote definitions, indented continuations, multiline labels, multiline titles, Unicode case folding, escaped opening-marker protection, explicit-label escape handling, blank-line title rejection, and malformed unescaped-label bracket rejection are covered. |
| Indented code basics | Tab and four-space top-level indented code examples now parse as code blocks. |
| Code spans | Matching backtick-run closure, multiline whitespace normalization, unmatched-token rollback, Setext-boundary precedence, and hidden delimiters inside escape/html/autolink-looking tokens are implemented; the Code spans section no longer appears in the current CommonMark/GFM failure reports. |
| Hard line breaks | Two-space and escaped-line-ending hard breaks now render canonically. |
| ATX headings | Empty ATX headings, tab separators, trailing-space trimming, optional closing hash markers, escaped closing hashes, and heading inline emphasis are implemented. |
| Fenced code | First-word language extraction, escaped punctuation normalization, character-reference decoding, opening-indent stripping, closing-fence indentation limits, trailing-text rejection, and backtick-info rejection are implemented. |
| Character references | Decimal/hex references, invalid-scalar replacement, overlong-reference literal preservation, and the named references exercised by the current leading official examples are implemented. |
| Autolinks and email autolinks | CommonMark scheme/email validation, whitespace rejection inside angle brackets, `mailto:` normalization, backtick/backslash/bracket href percent-encoding, invalid escaped-email fallback, and single-pass HTML attribute escaping are implemented. |
| Setext headings | Paragraph-plus-underline promotion now supports `=`/`-` levels, multiline heading content, escaped punctuation, trailing tab trimming, no promotion across blank lines, indented paragraph-continuation precedence, and precedence over multiline inline-code/raw-HTML-looking constructs. |
| Frontmatter boundary | YAML frontmatter is now explicit configuration: default Rhoe mode keeps it, while strict CommonMark and GFM modes treat document-start dashes as Markdown. |
| List marker, tightness, and paragraph-continuation basics | CommonMark one-to-four-space marker padding is stripped, empty `-` markers produce empty list items, ordered list markers are capped at nine digits, `.` and `)` ordered delimiters split into separate lists, ordered markers above `1` and empty markers no longer interrupt open paragraphs, sibling markers may be indented up to three columns, overindented marker-looking lines remain literal continuation text, list item terminal newlines no longer render as content, loose/tight list item rendering is tracked in the AST, tight-list section children render as flat CommonMark heading content, empty markers are preserved through normalization, leading empty marker lines stay tight, sibling blank gaps loosen lists, fenced-code blank lines no longer loosen siblings, nested-child blank lines no longer loosen ancestors, and multiple indented lines continue open paragraphs with canonical soft breaks. |

The conformance lane is a zero-failure release gate for the pinned fixture
versions. Upstream fixture refreshes should land only with updated pins,
regenerated reports, and any required compatibility fixes in the same release
candidate.
