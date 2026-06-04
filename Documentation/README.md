# RhoeMarkdown Documentation

This directory contains contributor-facing documentation that complements the
DocC catalog in `Sources/RhoeMarkdownKit/Documentation.docc`.

## Guides

- `Architecture.md`: public compiler package architecture.
- DocC `LanguageReference`: the authoritative `0.1.0` syntax and language reference.
- `CLI/README.md`: command-line usage and generated-artifact expectations.
- `Release/Homebrew.md`: Homebrew tap and bottle plan.
- `Release/ExternalConformance.md`: pinned CommonMark/GFM conformance evidence.
- `Release/LinuxCLIReadiness.md`: native and Static Linux CLI build gates.
- `Release/WebAssemblyReadiness.md`: WASI SDK build gate for `RhoeMarkdownWasm`.

## Local Site Build

```bash
bash Scripts/CI/build-docc-pages.sh
```
