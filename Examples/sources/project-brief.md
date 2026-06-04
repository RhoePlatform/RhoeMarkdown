---
title: "Project Brief: Atlas Handoff Lane"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/project-brief.md -o Examples/outputs/project-brief.html --format html --css --pretty`

# Project Brief: Atlas Handoff Lane {#atlas-handoff .brief}

> Goal: turn a rough implementation brief into a certified workstream kickoff.

!!! tip "Why this is a good Markdown example"
Briefs combine prose, decisions, tables, checklists, and code snippets. They are
also the kind of document teams actually revise together.
!!!

## Scope

1. Ingest the briefing pack.
2. Normalize it into a stable kickoff document.
3. Register the implementation lane.
4. Track reports back to Control Tower.

## Decision Table

| Decision | Default | Why |
| --- | --- | --- |
| Branch naming | `codex/<lane>` | keeps sessions searchable |
| Reports | Markdown | easy to diff and archive |
| Closeout | required | prevents silent drift |

## Kickoff Shape

```yaml
lane: hero-lane
status: greenlit
owner: implementation-session
reports:
  cadence: sprint
  format: markdown
```

## Acceptance Criteria

- [ ] The workstream can start from the kickoff alone.
- [ ] The registry knows owner, status, and next report path.
- [ ] The closeout document states what shipped and what remains.

## Review Prompt

When the lane reports back, the control tower should ask three questions:

- Did the implementation match the kickoff intent?
- Did the report include evidence, not just summary?
- Is the next sprint greenlit, blocked, or redirected?
