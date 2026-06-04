# Security Policy

## Supported Versions

The first supported public release line is `0.1.x` after the initial public tag.

## Reporting A Vulnerability

Please do not open public issues for suspected vulnerabilities. Email the
maintainers at `security@rhoe.dev` with:

- affected version or commit,
- reproduction steps,
- expected and observed behavior,
- any known impact or workaround.

We aim to acknowledge reports within five business days and coordinate fixes
before public disclosure.

## Security Scope

RhoeMarkdown compiles untrusted text into output formats. Security-sensitive
areas include HTML emission, file/project building, Liquid preprocessing,
preview server behavior, resource loading, and archive/document generation.
