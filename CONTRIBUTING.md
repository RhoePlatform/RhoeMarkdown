# Contributing to RhoeMarkdown

Thank you for helping improve RhoeMarkdown.

This repository is the public Apache 2.0 compiler package for semantic
Markdown. The first release focuses on parser, model, renderer, presentation
projection, CLI, server, WebAssembly, docs, examples, tests, and release
tooling.

## Before Opening A Pull Request

1. Keep changes focused on the compiler package surface.
2. Update docs and examples when behavior changes.
3. Run the release-readiness gate:

```bash
bash Scripts/CI/verify-release-readiness.sh
```

4. Call out any public API, CLI, or output-format behavior change in the PR.

## Good First Contributions

- Documentation fixes.
- Reproducible parser or renderer test cases.
- Example improvements.
- CLI help and diagnostics polish.
- Compatibility notes for Markdown edge cases.

## Out Of Scope For This Repo

- Premium studio applications.
- Native preview app productization.
- Unrelated platform services.
- Repository visibility, release tag, or Homebrew publication changes without maintainer approval.
