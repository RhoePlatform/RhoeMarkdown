# rhoemd CLI

`rhoemd` compiles Markdown files through the RhoeMarkdown engine.

## Common Commands

```bash
rhoemd input.md -o output.html --format html --css
rhoemd input.md -o output.typ --format typst
rhoemd --version
rhoemd --help
```

## Supported Formats

Output format is selected with `--format` or inferred from the output path.
The public `rhoemd` CLI surface includes HTML, LaTeX, Typst, DOCX, PDF, and
EPUB. JSON serialization is available through Swift API and WebAssembly helpers,
but is not a `rhoemd --format` option in `0.1.0`.

## Generated Artifacts

Generated manual pages and shell completions are planned for the next CLI
hygiene sprint after the current hand-written parser is migrated to
`swift-argument-parser`.
