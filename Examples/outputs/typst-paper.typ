#set document(title: "Compact Compiler Notes", author: "RhoePlatform")
#set page(paper: "a4")
#set text(size: 11pt)

// RhoeMarkdown AST-near function definitions
#let rhoe-section(level: 1, body) = heading(level: level, body)
#let rhoe-paragraph(body) = [#body]
#let rhoe-block-quote(body) = quote(block: true, body)
#let rhoe-admonition(kind: "note", title: none, body) = block(fill: luma(230), inset: 8pt, radius: 4pt)[#if title != none [*#title*\ ] #body]
#let rhoe-theorem(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Theorem.* #if title != none [(#title) ] #body]
#let rhoe-lemma(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Lemma.* #if title != none [(#title) ] #body]
#let rhoe-definition(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Definition.* #if title != none [(#title) ] #body]
#let rhoe-corollary(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Corollary.* #if title != none [(#title) ] #body]
#let rhoe-proposition(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Proposition.* #if title != none [(#title) ] #body]
#let rhoe-example(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Example.* #if title != none [(#title) ] #body]
#let rhoe-remark(title: none, body) = block(inset: 8pt)[*Remark.* #if title != none [(#title) ] #body]
#let rhoe-proof(of: none, body) = [_Proof._ #body #h(1fr) $square$]
#let rhoe-list(ordered: false, body) = body
#let rhoe-list-item(body) = [- #body]
#let rhoe-code(language: "text", body) = raw(body, lang: language, block: true)
#let rhoe-visual-block(name: "", body) = block[#body]
#let rhoe-div(body) = block[#body]
#let rhoe-line-block(body) = block[#body]
#let rhoe-thematic-break() = line(length: 100%)

#rhoe-block-quote[#rhoe-paragraph[Run: `rhoemd Examples/sources/typst-paper.md -o Examples/outputs/typst-paper.typ --format typst`]]

#rhoe-section(level: 1)[
  Compact Compiler Notes <compiler-notes>
#rhoe-section(level: 2)[
  Abstract
#rhoe-paragraph[RhoeMarkdown demonstrates how a plain-text document can become a structured compiler input without losing readability for human authors. This example is rendered to Typst so users can inspect the publication-oriented output.]

]

#rhoe-section(level: 2)[
  Method
#rhoe-paragraph[The pipeline separates parsing, normalization, rendering, and projection. This makes it possible to add output targets without changing the authoring surface.]

#rhoe-admonition(kind: "theorem", title: "Renderer Independence")[#rhoe-paragraph[If two renderers consume the same normalized document, any output-specific differences should be local to the writer, not the authoring syntax. ]]

#rhoe-paragraph[The result follows directly from @thm-renderer-independence and the compiler contract documented in the public API.]

]

#rhoe-section(level: 2)[
  Result
#table(
  columns: 3,
  [*Target*],  [*Use case*],  [*Artifact*],
  [HTML],  [review and web publishing],  [`.html`],
  [Typst],  [modern publication pipelines],  [`.typ`],
  [LaTeX],  [academic publishing],  [`.tex`],
  [WASM],  [editor and browser integrations],  [`.wasm`],
)

#rhoe-paragraph[Inline math remains readable: $quality = structure / ceremony$.]

]

#rhoe-section(level: 2)[
  Citation Note
#rhoe-paragraph[The source can carry citations such as #cite(<rhoe2026>) without forcing authors to leave Markdown while drafting.]

]

]

