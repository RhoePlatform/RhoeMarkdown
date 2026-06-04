# Icon Libraries

Access 10,000+ professional icons from Fluent UI, Heroicons, and Font Awesome.

## Overview

RhoeMarkdownKit includes a comprehensive icon system with over 10,000 professional icons from three major providers. Icons can be embedded directly in markdown, styled dynamically, and optimized for performance with automatic caching and sprite generation.

## Icon Providers

### Microsoft Fluent UI Icons (4,000+ icons)

Professional icons designed by Microsoft for modern applications:

- **Categories**: Navigation, Actions, Objects, Status, Files, Communication
- **Styles**: Regular, Filled, Light
- **Sizes**: 16px, 20px, 24px, 28px, 32px, 48px optimized

```markdown
<icon set="fluent" name="home" style="filled" />
<icon set="fluent" name="settings" style="regular" />
<icon set="fluent" name="cloud" style="light" />
```

### Heroicons (300+ icons)

Beautiful hand-crafted SVG icons by the makers of Tailwind CSS:

- **Categories**: Actions, Navigation, UI, Media, Commerce
- **Styles**: Outline, Solid, Mini (20px), Micro (16px)
- **Philosophy**: Carefully designed, consistent, accessible

```markdown
<icon set="heroicons" name="arrow-right" style="outline" />
<icon set="heroicons" name="check" style="solid" />
<icon set="heroicons" name="x-mark" style="mini" />
```

### Font Awesome (6,000+ icons)

The web's most popular icon library:

- **Categories**: Solid, Regular, Light, Duotone, Brands
- **Coverage**: Social media, brands, UI, objects, symbols
- **Special**: Brand icons for 1,500+ companies

```markdown
<icon set="fontawesome" name="rocket" style="solid" />
<icon set="fontawesome" name="github" style="brands" />
<icon set="fontawesome" name="twitter" style="brands" />
```

## Icon Syntax

### Basic Usage

```markdown
<!-- Simple icon -->
<icon set="fluent" name="home" />

<!-- With size -->
<icon set="heroicons" name="chart-bar" size="32" />

<!-- With color -->
<icon set="fontawesome" name="heart" color="#e74c3c" />

<!-- With all attributes -->
<icon set="fluent" name="star" style="filled" size="24" color="gold" />
```

### Inline with Text

```markdown
<icon set="fluent" name="home" /> Home
<icon set="heroicons" name="user" /> Profile  
<icon set="fontawesome" name="cog" /> Settings

Click the <icon set="heroicons" name="arrow-right" /> button to continue.
```

## Icon Sizes

### Predefined Sizes

| Size | Pixels | Use Case |
|------|--------|----------|
| `micro` | 12px | Tiny inline icons |
| `mini` | 16px | Small UI elements |
| `small` | 20px | Buttons, navigation |
| `medium` | 24px | Default size |
| `large` | 32px | Headers, emphasis |
| `xlarge` | 48px | Feature highlights |
| `xxlarge` | 64px | Hero sections |

```markdown
<icon set="fluent" name="home" size="micro" />
<icon set="fluent" name="home" size="mini" />
<icon set="fluent" name="home" size="small" />
<icon set="fluent" name="home" size="medium" />
<icon set="fluent" name="home" size="large" />
<icon set="fluent" name="home" size="xlarge" />
<icon set="fluent" name="home" size="xxlarge" />
```

### Custom Sizes

```markdown
<!-- Custom pixel size -->
<icon set="heroicons" name="star" size="36" />
<icon set="heroicons" name="star" size="100" />
```

## Icon Styles

### Style Variants

Different visual treatments for icons:

```markdown
<!-- Fluent styles -->
<icon set="fluent" name="home" style="regular" />  <!-- Outline -->
<icon set="fluent" name="home" style="filled" />   <!-- Solid fill -->
<icon set="fluent" name="home" style="light" />    <!-- Thin lines -->

<!-- Heroicons styles -->  
<icon set="heroicons" name="bell" style="outline" />  <!-- Outline -->
<icon set="heroicons" name="bell" style="solid" />    <!-- Filled -->
<icon set="heroicons" name="bell" style="mini" />     <!-- 20px optimized -->
<icon set="heroicons" name="bell" style="micro" />    <!-- 16px optimized -->

<!-- Font Awesome styles -->
<icon set="fontawesome" name="star" style="regular" />   <!-- Outline -->
<icon set="fontawesome" name="star" style="solid" />     <!-- Filled -->
<icon set="fontawesome" name="star" style="light" />     <!-- Thin -->
<icon set="fontawesome" name="star" style="duotone" />   <!-- Two-tone -->
```

## Icon Colors

### Color Options

```markdown
<!-- Hex colors -->
<icon set="fluent" name="heart" color="#e74c3c" />

<!-- RGB/RGBA -->
<icon set="heroicons" name="star" color="rgb(241, 196, 15)" />
<icon set="heroicons" name="star" color="rgba(241, 196, 15, 0.5)" />

<!-- Named colors -->
<icon set="fontawesome" name="check" color="green" />
<icon set="fontawesome" name="times" color="red" />

<!-- Current color (inherits from text) -->
<icon set="fluent" name="arrow-right" color="currentColor" />
```

## Icon Categories

### Navigation Icons

```markdown
<icon set="fluent" name="home" /> Home
<icon set="fluent" name="arrow-left" /> Back
<icon set="fluent" name="arrow-right" /> Forward
<icon set="heroicons" name="menu" /> Menu
<icon set="heroicons" name="x-mark" /> Close
```

### Action Icons

```markdown
<icon set="fluent" name="add" /> Add
<icon set="fluent" name="delete" /> Delete
<icon set="fluent" name="edit" /> Edit
<icon set="heroicons" name="download" /> Download
<icon set="heroicons" name="upload" /> Upload
```

### Status Icons

```markdown
<icon set="fluent" name="checkmark-circle" color="green" /> Success
<icon set="fluent" name="warning" color="orange" /> Warning
<icon set="fluent" name="error-circle" color="red" /> Error
<icon set="heroicons" name="information-circle" color="blue" /> Info
```

### Social Media Icons

```markdown
<icon set="fontawesome" name="github" style="brands" /> GitHub
<icon set="fontawesome" name="twitter" style="brands" /> Twitter
<icon set="fontawesome" name="linkedin" style="brands" /> LinkedIn
<icon set="fontawesome" name="youtube" style="brands" /> YouTube
<icon set="fontawesome" name="facebook" style="brands" /> Facebook
```

## Using IconSystemManager

### Initialize the System

```swift
import RhoeMarkdownKit

let iconManager = IconSystemManager.shared
try await iconManager.initialize()

// Check statistics
let stats = await iconManager.getStatistics()
print("Total icons available: \(stats.totalIcons)")
```

### Get Specific Icons

```swift
// Request a specific icon
let request = IconSystemManager.IconRequest(
    provider: .fluent,
    name: "home",
    style: .filled,
    size: .large,
    color: "#3498db"
)

let iconSVG = try await iconManager.getIcon(request)
```

### Search for Icons

```swift
// Search by keyword
let results = await iconManager.searchIcons(keyword: "arrow")
for icon in results {
    print("\(icon.provider)/\(icon.name): \(icon.keywords.joined(separator: ", "))")
}

// Search within specific provider
let fluentResults = await iconManager.searchIcons(
    keyword: "settings",
    provider: .fluent
)
```

### Get Icons by Category

```swift
// Get all navigation icons
let navIcons = await iconManager.getIconsByCategory(
    "navigation",
    provider: .heroicons
)

// Get all brand icons
let brandIcons = await iconManager.getIconsByCategory(
    "brands",
    provider: .fontawesome
)
```

## Custom Icons

### Register Custom Icons

```swift
// Register single custom icon
let customIcon = IconSystemManager.IconDefinition(
    name: "my-logo",
    provider: "custom",
    svgPath: "M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z",
    viewBox: "0 0 24 24",
    keywords: ["logo", "brand", "company"]
)

iconManager.registerCustomIcon(customIcon)
```

### Bulk Registration

```swift
// Register multiple custom icons
let customIcons = [
    IconDefinition(name: "icon1", ...),
    IconDefinition(name: "icon2", ...),
    IconDefinition(name: "icon3", ...)
]

iconManager.registerCustomIcons(customIcons)
```

### Use Custom Icons

```markdown
<icon set="custom" name="my-logo" size="32" color="#2c3e50" />
```

## Icon Sprites

### Generate Sprite Sheet

For performance optimization with many icons:

```swift
// Define icons for sprite
let iconsToSprite = [
    IconRequest(provider: .fluent, name: "home"),
    IconRequest(provider: .fluent, name: "settings"),
    IconRequest(provider: .heroicons, name: "user"),
    IconRequest(provider: .fontawesome, name: "github")
]

// Generate sprite SVG
let sprite = try await iconManager.generateSprite(icons: iconsToSprite)

// Use in HTML
let html = """
\(sprite)
<svg><use href="#fluent-home"></use></svg>
<svg><use href="#heroicons-user"></use></svg>
"""
```

## Icon Animations

### CSS Animations

```markdown
<!-- Spinning icon -->
<icon set="fluent" name="sync" class="spin" />

<!-- Pulsing icon -->
<icon set="heroicons" name="heart" class="pulse" />

<!-- Custom animation -->
<icon set="fontawesome" name="bell" class="shake" />
```

```css
.spin { animation: spin 2s linear infinite; }
.pulse { animation: pulse 2s ease-in-out infinite; }
.shake { animation: shake 0.5s ease-in-out infinite; }

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}
```

## Accessibility

Icons automatically include accessibility features:

```html
<!-- Generated HTML includes ARIA -->
<svg role="img" aria-label="home">
    <!-- icon path -->
</svg>
```

### With Descriptive Text

```markdown
<!-- Screen reader friendly -->
<icon set="fluent" name="home" aria-label="Navigate to homepage" />

<!-- Hidden from screen readers (decorative) -->
<icon set="heroicons" name="star" aria-hidden="true" />
```

## Performance Optimization

### Icon Caching

Icons are automatically cached after first use:

```swift
// First request - fetches and caches
let icon1 = try await iconManager.getIcon(request)

// Subsequent requests - returns from cache
let icon2 = try await iconManager.getIcon(request) // Instant
```

### Lazy Loading

For large icon sets:

```swift
// Icons load on-demand
let icon = try await iconManager.getIcon(
    IconRequest(provider: .fontawesome, name: "rare-icon")
)
// Only loads this specific icon, not entire FontAwesome set
```

## Icon Patterns

### Navigation Bar

```markdown
<nav>
  <icon set="fluent" name="home" /> Home
  <icon set="fluent" name="search" /> Search
  <icon set="fluent" name="bell" /> Notifications
  <icon set="fluent" name="person" /> Profile
</nav>
```

### Feature List

```markdown
## Features

- <icon set="heroicons" name="lightning-bolt" color="yellow" /> Lightning Fast
- <icon set="heroicons" name="shield-check" color="green" /> Secure by Default
- <icon set="heroicons" name="cube-transparent" color="blue" /> Modular Architecture
- <icon set="heroicons" name="sparkles" color="purple" /> AI-Powered
```

### Status Indicators

```markdown
| Service | Status |
|---------|--------|
| API | <icon set="fluent" name="checkmark-circle" color="green" /> Operational |
| Database | <icon set="fluent" name="checkmark-circle" color="green" /> Operational |
| CDN | <icon set="fluent" name="warning" color="orange" /> Degraded |
| Email | <icon set="fluent" name="error-circle" color="red" /> Outage |
```

### Social Links

```markdown
Follow us:
[<icon set="fontawesome" name="github" style="brands" />](https://github.com)
[<icon set="fontawesome" name="twitter" style="brands" />](https://twitter.com)
[<icon set="fontawesome" name="linkedin" style="brands" />](https://linkedin.com)
```

## Export Options

### Export to JSON

```swift
// Export all icons
let allIconsJSON = try await iconManager.exportToJSON()

// Export specific provider
let fluentJSON = try await iconManager.exportToJSON(provider: .fluent)
```

## Best Practices

1. **Use semantic icons** - Choose icons that clearly represent their purpose
2. **Consistent sizing** - Maintain uniform icon sizes within sections
3. **Appropriate colors** - Use colors that match your design system
4. **Accessibility first** - Always include proper ARIA labels
5. **Optimize loading** - Use sprites for pages with many icons
6. **Cache effectively** - Leverage automatic caching
7. **Test icon availability** - Verify icons exist before deployment

## Troubleshooting

### Common Issues

- **Icon not found**: Verify provider and name are correct
- **Style not available**: Check if style exists for that icon set
- **Color not applying**: Ensure color format is valid
- **Size issues**: Use predefined sizes or valid pixel values

## Next Steps

- Explore <doc:ShapeSystem> for diagram elements
- Learn about <doc:GridLayouts> for icon tables
- See <doc:SlideSystem> for presentation icons
- Check <doc:Performance> for optimization tips