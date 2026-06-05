# Homebrew Release Plan

RhoeMarkdown will publish the `rhoemd` executable through the
`RhoePlatform/homebrew-rhoe` tap after the clean release commit and `v0.1.1`
tag are certified. The formula installs `rhoemd` plus the `markdown` symlink so
users can choose either the canonical RhoePlatform command or the full language
name.

## Formula

The template is `Packaging/Homebrew/rhoe-markdown.rb.template`.

Installed commands:

- `rhoemd`: canonical RhoeMarkdown compiler command.
- `markdown`: Homebrew-installed alias pointing to `rhoemd`.
- `rhoemd-preview-menu`: macOS-only menu bar companion for the preview daemon.

## Bottles

Bottle upload should mirror the proven RhoeLiquid release bridge:

- Apple Silicon macOS bottle with `rhoemd`, `markdown`, and
  `rhoemd-preview-menu`.
- Linux x86_64 bottle with `rhoemd` and `markdown` only.
- single-hyphen and double-hyphen filename aliases for Homebrew compatibility.

The unsigned `.app` bundle can be assembled locally with
`Scripts/Packaging/build-preview-menu-app.sh`. Signed and notarized app
distribution is deferred; the first bottle lane installs the companion
executable directly.

## Deferred Publication

No bottle checksums are committed during staging. The formula template keeps
placeholders until the release workflow writes final URLs and checksums.
