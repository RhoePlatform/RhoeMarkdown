# Releasing RhoeMarkdown

This staged repo must remain source-only and non-git until the release candidate
passes the local readiness gates.

## Release Candidate Checklist

```bash
swift package dump-package
swift build
swift build -c release --product rhoemd
swift test
bash Scripts/CI/validate-docs.sh
bash Scripts/CI/validate-language-reference.sh
bash Scripts/CI/validate-examples.sh
bash Scripts/CI/validate-external-conformance.sh
bash Scripts/CI/validate-homebrew-template.sh
bash Scripts/CI/verify-release-readiness.sh
bash Scripts/verify-cutover.sh
```

Optional cross-platform gates for release certification:

```bash
RHOE_MARKDOWN_LINUX_SDK_ID=swift-6.3.2-RELEASE_static-linux-0.1.0 \
  swiftly run bash Scripts/CI/build-linux-cli.sh +6.3.2
swiftly run bash Scripts/CI/build-wasm.sh +6.3.0
```

## Initial Commit Sequence

1. Confirm hygiene scans are clean.
2. Remove `.build`, `Package.resolved`, `.DS_Store`, and transient artifacts.
3. Initialize git in the staged repo.
4. Commit with `Initial RhoeMarkdown 0.1.0 public foundation release`.
5. Create `RhoePlatform/RhoeMarkdown` as a private GitHub repository.
6. Push `main`.
7. Run GitHub Actions while the repo remains private.
8. Switch public and tag `v0.1.0` only after final release certification.

## Homebrew

The formula template in `Packaging/Homebrew/` is validated before publication.
Bottle upload and tap updates are deferred until the `v0.1.0` tag exists.
