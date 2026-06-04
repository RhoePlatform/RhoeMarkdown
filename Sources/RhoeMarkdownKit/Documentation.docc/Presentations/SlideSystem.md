# Slide System

Create professional presentations directly in markdown with revolutionary features.

## Overview

The RhoeMarkdownKit slide system introduces a revolutionary syntax for creating presentations using simple markdown delimiters. With support for transitions, layouts, animations, and speaker notes, it's the most powerful markdown-based presentation system available.

## Slide Delimiters

RhoeMarkdownKit uses three special delimiters for slides:

- `%%%` - Title slide (main section divider)
- `%%` - Content slide (regular slide)
- `%` - Speaker notes (presenter-only content)

## Basic Syntax

### Simple Presentation

```markdown
%%% Welcome
# My Presentation
## Subtitle Here

%% Introduction
This is the first content slide.

- Point 1
- Point 2
- Point 3

% Speaker notes for this slide
Remember to mention the background context

%% Conclusion
Thank you for your attention!
```

### Advanced Features

```markdown
%%% Title Slide {transition=zoom duration=30 auto=true}
# Advanced Presentation
## With Enhanced Features

%% Two Column Layout {layout=two-column}
### Left Column
- Feature A
- Feature B
- Feature C

### Right Column
- Benefit 1
- Benefit 2
- Benefit 3

%% Grid Layout {layout=grid}
|[1,1] **Q1** |[1,2] **Q2** |[1,3] **Q3** |[1,4] **Q4** |
|[2,1] $100K |[2,2] $150K |[2,3] $200K |[2,4] $250K |

% Notes about the quarterly performance
```

## Slide Transitions

Available transition effects:

| Transition | Description |
|------------|-------------|
| `none` | No transition |
| `fade` | Fade in/out |
| `slide` | Slide from side |
| `zoom` | Zoom in/out |
| `flip` | 3D flip effect |
| `cube` | 3D cube rotation |
| `morph` | Smooth morphing |
| `dissolve` | Pixel dissolve |
| `parallax` | Parallax layers |

### Usage

```markdown
%%% Slide Title {transition=zoom}
# Content with zoom transition

%% Next Slide {transition=flip duration=2}
# Content with flip transition (2 seconds)
```

## Slide Layouts

Pre-defined layout templates:

| Layout | Description |
|--------|-------------|
| `title` | Title slide layout |
| `title-content` | Title with content below |
| `two-column` | Two equal columns |
| `three-column` | Three equal columns |
| `comparison` | Side-by-side comparison |
| `image-left` | Image on left, text on right |
| `image-right` | Text on left, image on right |
| `full-image` | Full background image |
| `grid` | Grid-based layout |
| `timeline` | Timeline visualization |
| `dashboard` | Dashboard-style metrics |

### Layout Examples

```markdown
%% Comparison Slide {layout=comparison}
### Option A
- Pro: Fast
- Pro: Simple
- Con: Limited features

### Option B
- Pro: Feature-rich
- Pro: Extensible
- Con: Complex

%% Timeline {layout=timeline}
### 2024 Q1
Project kickoff

### 2024 Q2
Development phase

### 2024 Q3
Beta testing

### 2024 Q4
Production release
```

## Slide Animations

Animate individual elements:

```markdown
%%% Animated Slide {animate="h1:fadeIn:0.5,p:slideIn:1.0"}
# This heading fades in
This paragraph slides in after

%% Build Animation {animate="li:fadeIn:0.5:stagger"}
- First item appears
- Then this one
- Finally this one
```

Animation types:
- `fadeIn` - Fade in effect
- `slideIn` - Slide from edge
- `zoomIn` - Zoom in effect
- `bounceIn` - Bounce entrance
- `flipIn` - Flip entrance
- `typewriter` - Typing effect
- `highlight` - Highlight effect
- `pulse` - Pulsing effect

## Slide Backgrounds

Set custom backgrounds:

```markdown
%%% Hero Slide {background=gradient(#667eea,#764ba2,45)}
# Gradient Background

%% Image Background {background=image(hero.jpg,0.5)}
# Semi-transparent image background

%% Video Background {background=video(intro.mp4,loop)}
# Looping video background
```

## Speaker Notes

Add presenter-only notes:

```markdown
%% Main Content
This is what the audience sees

% Speaker Notes
- Remember to make eye contact
- Mention the case study
- Allow time for questions
- Transition smoothly to next topic
```

## Auto-Advance

Configure automatic progression:

```markdown
%%% Auto Slides {auto=true duration=10}
# This slide auto-advances after 10 seconds

%% Next Slide {duration=15}
# This one after 15 seconds
```

## Using the Slide Parser

### Basic Usage

```swift
import RhoeMarkdownKit

let slideMarkdown = """
%%% Welcome
# My Presentation

%% Content
- Point 1
- Point 2

% Notes
Remember key points
"""

let parser = SlideEnhancedParser()
let presentation = try await parser.parseEnhanced(slideMarkdown)

// Access slides
for slide in presentation.slides {
    print("Slide \(slide.index): \(slide.metadata.title ?? "Untitled")")
    if let notes = slide.metadata.speakerNotes {
        print("Speaker notes: \(notes)")
    }
}
```

### Advanced Configuration

```swift
// Parse with custom settings
let slide = try await parser.parseSlideChunk(slideContent, index: 0)

// Access metadata
let transition = slide.metadata.transition
let layout = slide.metadata.layout
let animations = slide.metadata.animations

// Render to HTML
let htmlRenderer = SlideHTMLRenderer()
let html = htmlRenderer.renderPresentation(presentation)
```

## Presentation Metadata

Add YAML frontmatter for presentation-wide settings:

```markdown
---
title: Quarterly Review
author: John Doe
date: 2024-03-15
theme: corporate
aspectRatio: 16:9
---

%%% Opening Slide
# Q1 2024 Review
```

## Export Options

### HTML Presentation

```swift
let html = presentationRenderer.renderHTML(
    presentation,
    options: .init(
        includeNavigation: true,
        includeProgressBar: true,
        includeSpeakerNotes: false,
        theme: .modern
    )
)
```

### PDF Export

```swift
let pdf = presentationRenderer.renderPDF(
    presentation,
    options: .init(
        pageSize: .letter,
        orientation: .landscape,
        includeNotes: true
    )
)
```

## Presentation Themes

Built-in themes:
- `default` - Clean, minimal design
- `corporate` - Professional business style
- `academic` - Scholarly presentation
- `creative` - Artistic and colorful
- `dark` - Dark mode optimized
- `liquid-glass` - RhoeSuite signature style

## Best Practices

1. **Keep slides focused** - One main idea per slide
2. **Use consistent transitions** - Don't overuse effects
3. **Structure with sections** - Use `%%%` for logical divisions
4. **Add speaker notes** - Help yourself or other presenters
5. **Test animations** - Ensure timing feels natural
6. **Consider accessibility** - Provide alt text for images
7. **Use layouts wisely** - Match layout to content type

## Integration with Shapes & Icons

Combine with other RhoeMarkdownKit features:

```markdown
%% Architecture Diagram
<shape type="cloud" label="AWS" />
<shape type="arrow-right" />
<shape type="server" label="API" />
<shape type="arrow-right" />
<shape type="database" label="PostgreSQL" />

%% Feature Icons
- <icon set="fluent" name="home" /> Dashboard
- <icon set="heroicons" name="chart-bar" /> Analytics
- <icon set="fontawesome" name="rocket" /> Performance
```

## Performance Considerations

- Slides are parsed on-demand for large presentations
- Animations are GPU-accelerated where possible
- Images are lazy-loaded for faster initial render
- Speaker notes are loaded separately from content

## Next Steps

- Explore <doc:GridLayouts> for data presentations
- Learn about <doc:ShapeSystem> for diagrams
- See <doc:IconLibraries> for visual elements
- Check <doc:Performance> for optimization tips