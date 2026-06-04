# RhoeMarkdown Language Reference Artifacts

This directory contains machine-readable language-reference artifacts that
support the DocC language reference in
`Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/`.

- `rhoemarkdown-language-surface.json`: public `0.1.0` surface manifest for
  block elements, inline elements, pipeline phases, delimiter families, output
  surfaces, and compatibility labels.

The manifest is maintained as documentation and validation data. Future editor
completion, syntax highlighting, and conformance tooling can consume it without
parsing Swift source.
