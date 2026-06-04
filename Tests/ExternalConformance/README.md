# External Markdown Conformance Fixtures

This directory contains generated JSON fixtures extracted from pinned upstream
CommonMark and GitHub Flavored Markdown specifications.

Regenerate them with:

```bash
bash Scripts/CI/fetch-external-conformance.sh
```

The fetch script verifies immutable upstream refs and SHA-256 checksums before
rewriting the generated JSON files. License and attribution notes live in
`THIRD_PARTY_NOTICES.md`.
