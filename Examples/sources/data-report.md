---
title: "Ops Report: Compiler Throughput"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/data-report.md -o Examples/outputs/data-report.html --format html --css --pretty`

# Ops Report: Compiler Throughput {#ops-throughput}

## Executive Signal

The compiler lane is healthy. Median render time stayed below the target budget
while the example gallery expanded from six to ten documents.

| Metric | Current | Target | Status |
| --- | ---: | ---: | --- |
| Median HTML render | 42 ms | 100 ms | green |
| Largest source file | 6.4 KB | 20 KB | green |
| Gallery examples | 10 | 10 | green |
| Cross-target scripts | 2 | 2 | green |

The normalized budget ratio is $r = observed / target$. Values below `1.0`
remain inside the release envelope.

!!! success "Operational takeaway"
The gallery is large enough to teach the surface, but still small enough to run
as part of release-readiness validation.
!!!

## Trend Notes

- HTML examples emphasize visual inspection.
- Typst output proves the publication route.
- The language showcase keeps the syntax surface discoverable.

## Follow-Up

Add a future benchmark gallery only after the public examples stabilize. The
current folder should stay friendly for first-time users, not become a lab.
