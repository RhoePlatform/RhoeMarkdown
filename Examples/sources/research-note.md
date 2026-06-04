---
title: "Field Note: Meadow Signal"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/research-note.md -o Examples/outputs/research-note.html --format html --css --pretty`

# Meadow Signal {#meadow-signal .field-note}

!!! note "Observation"
The north ridge showed a repeating pattern: short bursts of activity followed by
long quiet intervals. The team used RhoeMarkdown so the same note can become
HTML for review, Typst for publication, or structured JSON for downstream tools.
!!!

## Measurement Window

| Window | Signal | Confidence | Field note |
| --- | ---: | ---: | --- |
| Dawn | 0.72 | 94% | ridge fog, clean baseline |
| Noon | 0.38 | 71% | thermal noise, partial occlusion |
| Dusk | 0.81 | 97% | stable wind, high coherence |

The working hypothesis is **phase-sensitive recovery**: the system appears to
gain coherence when the ambient load falls below the ridge threshold.

Inline math stays readable in source: $S_{normalized} = signal / threshold$.

!!! theorem "Recovery Threshold" {#thm-recovery}
When ambient load remains below the ridge threshold for three consecutive
sampling windows, the normalized signal should increase in the next window.
!!!

The planned verification checks @thm-recovery against the dusk measurement.

## Next Step

- Repeat the run with a 15-minute sampling cadence.
- Compare with the western ridge control group.
- Export the note to HTML for review and Typst for the archive.

The raw notebook remains plain text, while the compiler preserves semantic
structure for future automation.[^field-note]

[^field-note]: This is a synthetic example, but the workflow mirrors a real field-note pipeline.
