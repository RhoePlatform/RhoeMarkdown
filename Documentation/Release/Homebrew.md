# Homebrew Release Plan

RhoeMarkdown will publish the `rhoemd` executable through the
`RhoePlatform/homebrew-rhoe` tap after the clean initial commit and `v0.1.0`
tag are certified.

## Formula

The template is `Packaging/Homebrew/rhoe-markdown.rb.template`.

## Bottles

Bottle upload should mirror the proven RhoeLiquid release bridge:

- Apple Silicon macOS bottle.
- Linux x86_64 bottle.
- single-hyphen and double-hyphen filename aliases for Homebrew compatibility.

## Deferred Publication

No bottle checksums are committed during staging. The formula template keeps
placeholders until the release workflow writes final URLs and checksums.
