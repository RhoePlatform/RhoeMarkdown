# Shape System

Create professional diagrams with 70+ semantic shapes, animations, and advanced styling.

## Overview

The RhoeMarkdownKit Shape System provides a comprehensive library of semantic shapes for creating flowcharts, network diagrams, business graphics, and technical illustrations directly in markdown. With 70+ shape types, customizable styles, and animation support, it's the most powerful diagramming system for markdown.

## Shape Categories

### Basic Shapes (10 types)

| Shape | Syntax | Use Case |
|-------|--------|----------|
| `rectangle` | `<shape type="rectangle" />` | General containers |
| `square` | `<shape type="square" />` | Equal-sided boxes |
| `circle` | `<shape type="circle" />` | Nodes, states |
| `ellipse` | `<shape type="ellipse" />` | Ovals, highlights |
| `triangle` | `<shape type="triangle" />` | Warnings, hierarchies |
| `diamond` | `<shape type="diamond" />` | Decisions, branches |
| `pentagon` | `<shape type="pentagon" />` | 5-sided polygons |
| `hexagon` | `<shape type="hexagon" />` | 6-sided cells, hives |
| `octagon` | `<shape type="octagon" />` | Stop signs, emphasis |
| `star` | `<shape type="star" />` | Favorites, ratings |

### Arrows & Connectors (10 types)

| Shape | Syntax | Use Case |
|-------|--------|----------|
| `arrow-right` | `<shape type="arrow-right" />` | Direction flow |
| `arrow-left` | `<shape type="arrow-left" />` | Backward flow |
| `arrow-up` | `<shape type="arrow-up" />` | Upward movement |
| `arrow-down` | `<shape type="arrow-down" />` | Downward movement |
| `arrow-bidirectional` | `<shape type="arrow-bidirectional" />` | Two-way flow |
| `arrow-curved` | `<shape type="arrow-curved" />` | Curved paths |
| `arrow-dashed` | `<shape type="arrow-dashed" />` | Optional flow |
| `connector` | `<shape type="connector" />` | Simple lines |
| `connector-elbow` | `<shape type="connector-elbow" />` | Right-angle connections |
| `connector-curved` | `<shape type="connector-curved" />` | Smooth curves |

### Flowchart Shapes (21 types)

| Shape | Syntax | Use Case |
|-------|--------|----------|
| `process` | `<shape type="process" />` | Processing step |
| `decision` | `<shape type="decision" />` | Conditional branch |
| `terminator` | `<shape type="terminator" />` | Start/End points |
| `data` | `<shape type="data" />` | Data input/output |
| `document` | `<shape type="document" />` | Document representation |
| `multi-document` | `<shape type="multi-document" />` | Multiple documents |
| `preparation` | `<shape type="preparation" />` | Setup steps |
| `manual-input` | `<shape type="manual-input" />` | User input |
| `manual-operation` | `<shape type="manual-operation" />` | Manual process |
| `display` | `<shape type="display" />` | Display output |
| `stored-data` | `<shape type="stored-data" />` | Database storage |
| `database` | `<shape type="database" />` | Database cylinder |
| `internal-storage` | `<shape type="internal-storage" />` | Internal memory |
| `predefined-process` | `<shape type="predefined-process" />` | Subroutine |
| `delay` | `<shape type="delay" />` | Wait state |
| `or` | `<shape type="or" />` | OR gate |
| `summing-junction` | `<shape type="summing-junction" />` | Merge point |
| `collate` | `<shape type="collate" />` | Collation |
| `sort` | `<shape type="sort" />` | Sorting operation |
| `merge` | `<shape type="merge" />` | Merge operation |
| `extract` | `<shape type="extract" />` | Extract operation |

### Cloud & Network (14 types)

| Shape | Syntax | Use Case |
|-------|--------|----------|
| `cloud` | `<shape type="cloud" />` | Cloud services |
| `server` | `<shape type="server" />` | Server hardware |
| `workstation` | `<shape type="workstation" />` | Desktop computer |
| `laptop` | `<shape type="laptop" />` | Laptop device |
| `mobile` | `<shape type="mobile" />` | Mobile phone |
| `tablet` | `<shape type="tablet" />` | Tablet device |
| `router` | `<shape type="router" />` | Network router |
| `switch` | `<shape type="switch" />` | Network switch |
| `firewall` | `<shape type="firewall" />` | Security firewall |
| `load-balancer` | `<shape type="load-balancer" />` | Load balancer |
| `internet` | `<shape type="internet" />` | Internet/WWW |
| `network` | `<shape type="network" />` | Network segment |
| `wireless` | `<shape type="wireless" />` | WiFi/wireless |
| `ethernet` | `<shape type="ethernet" />` | Wired connection |

### Business & People (8 types)

| Shape | Syntax | Use Case |
|-------|--------|----------|
| `person` | `<shape type="person" />` | Individual user |
| `group` | `<shape type="group" />` | Team/group |
| `building` | `<shape type="building" />` | Office building |
| `store` | `<shape type="store" />` | Retail location |
| `factory` | `<shape type="factory" />` | Manufacturing |
| `warehouse` | `<shape type="warehouse" />` | Storage facility |
| `office` | `<shape type="office" />` | Office space |
| `home` | `<shape type="home" />` | Residential |

### Special Shapes (17 types)

| Shape | Syntax | Use Case |
|-------|--------|----------|
| `gear` | `<shape type="gear" />` | Settings, config |
| `shield` | `<shape type="shield" />` | Security, protection |
| `lock` | `<shape type="lock" />` | Locked, secure |
| `key` | `<shape type="key" />` | Access, authentication |
| `flag` | `<shape type="flag" />` | Milestone, marker |
| `bookmark` | `<shape type="bookmark" />` | Save, bookmark |
| `tag` | `<shape type="tag" />` | Label, category |
| `note` | `<shape type="note" />` | Annotation |
| `callout` | `<shape type="callout" />` | Emphasis |
| `speech-bubble` | `<shape type="speech-bubble" />` | Dialog, chat |
| `thought-bubble` | `<shape type="thought-bubble" />` | Thinking, idea |
| `explosion` | `<shape type="explosion" />` | Impact, burst |
| `lightning` | `<shape type="lightning" />` | Speed, energy |
| `heart` | `<shape type="heart" />` | Like, favorite |
| `checkmark` | `<shape type="checkmark" />` | Complete, success |
| `cross` | `<shape type="cross" />` | Error, cancel |
| `warning` | `<shape type="warning" />` | Warning alert |

## Shape Attributes

### Basic Attributes

```markdown
<shape 
  type="rectangle"      # Shape type (required)
  label="Process"       # Text label
  size="large"          # Size: tiny, small, medium, large, xlarge
  color="#3498db"       # Fill color
  stroke="#2c3e50"      # Border color
/>
```

### Positioning

```markdown
<shape 
  type="circle"
  x="100"              # X coordinate
  y="50"               # Y coordinate  
  z="2"                # Z-index layer
/>
```

### Advanced Styling

```markdown
<shape 
  type="diamond"
  label="Decision"
  fill="#e74c3c"
  stroke="#c0392b"
  stroke-width="3"
  stroke-style="dashed"  # solid, dashed, dotted, dash-dot
  opacity="0.8"
/>
```

## Animations

### Animation Types

```markdown
<!-- Pulsing shape -->
<shape type="heart" animate="pulse" />

<!-- Rotating gear -->
<shape type="gear" animate="rotate" />

<!-- Bouncing ball -->
<shape type="circle" animate="bounce" />

<!-- Fading in/out -->
<shape type="star" animate="fade" />

<!-- Sliding motion -->
<shape type="arrow-right" animate="slide" />

<!-- Scaling effect -->
<shape type="diamond" animate="scale" />
```

### Animation Configuration

```markdown
<shape 
  type="gear"
  animate="rotate"
  animation-duration="2"      # Duration in seconds
  animation-repeat="true"     # Loop animation
  animation-easing="ease-in"  # Easing function
/>
```

## Gradients and Patterns

### Gradient Fills

```markdown
<shape 
  type="rectangle"
  gradient="linear(#667eea,#764ba2,45)"  # Linear gradient
/>

<shape 
  type="circle"
  gradient="radial(#ffeaa7,#fab1a0)"     # Radial gradient
/>
```

### Pattern Fills

```markdown
<shape 
  type="hexagon"
  pattern="dots"        # dots, lines, grid, crosses, zigzag
  pattern-scale="1.5"
  pattern-color="#95a5a6"
/>
```

## Shadows and Effects

```markdown
<shape 
  type="cloud"
  label="AWS"
  shadow="true"
  shadow-offset-x="2"
  shadow-offset-y="2"
  shadow-blur="4"
  shadow-color="rgba(0,0,0,0.3)"
/>
```

## Creating Diagrams

### Simple Flow Diagram

```markdown
<shape type="terminator" label="Start" />
<shape type="arrow-down" />
<shape type="process" label="Initialize" />
<shape type="arrow-down" />
<shape type="decision" label="Valid?" />
<shape type="arrow-right" label="Yes" />
<shape type="process" label="Execute" />
<shape type="arrow-down" />
<shape type="terminator" label="End" />
```

### Network Architecture

```markdown
<shape type="cloud" label="Internet" color="#3498db" />
<shape type="arrow-down" />
<shape type="firewall" label="WAF" color="#e74c3c" />
<shape type="arrow-down" />
<shape type="load-balancer" label="ELB" color="#f39c12" />
<shape type="arrow-bidirectional" />
<shape type="server" label="Web Server 1" />
<shape type="server" label="Web Server 2" />
<shape type="arrow-down" />
<shape type="database" label="PostgreSQL" color="#336791" />
```

### Business Process

```markdown
<shape type="person" label="Customer" />
<shape type="arrow-right" />
<shape type="store" label="Retail Store" />
<shape type="arrow-right" />
<shape type="warehouse" label="Fulfillment" />
<shape type="arrow-right" />
<shape type="truck" label="Delivery" />
<shape type="arrow-right" />
<shape type="home" label="Customer Home" />
```

## Using ShapeSystemRenderer

### Basic Usage

```swift
import RhoeMarkdownKit

let renderer = ShapeSystemRenderer()

// Parse single shape
let shapeMarkdown = """
<shape type="cloud" label="AWS" color="#FF9900" size="large" />
"""

let shape = try await renderer.parseShape(shapeMarkdown)
let svg = renderer.renderSVG(shape)
```

### Composing Diagrams

```swift
// Create multiple shapes
let shapes = [
    Shape(type: .cloud, label: "Cloud", position: ShapePosition(x: 0, y: 0)),
    Shape(type: .server, label: "Server", position: ShapePosition(x: 0, y: 100)),
    Shape(type: .database, label: "DB", position: ShapePosition(x: 0, y: 200))
]

// Add connections
shapes[0].connections.append(
    ShapeConnection(
        targetId: shapes[1].id,
        connectionType: .straight,
        label: "HTTPS"
    )
)

// Compose into diagram
let diagram = renderer.composeDiagram(shapes)
```

### Custom Shapes

```swift
// Register custom shape
let customShape = Shape(
    type: .custom,
    label: "My Shape",
    style: ShapeStyle(
        fillColor: "#9b59b6",
        strokeColor: "#8e44ad",
        strokeWidth: 3,
        gradient: ShapeStyle.GradientStyle(
            type: .linear(angle: 45),
            colors: [
                (color: "#9b59b6", stop: 0),
                (color: "#8e44ad", stop: 1)
            ]
        )
    )
)
```

## Shape Connections

### Connection Types

```swift
// Straight line
ShapeConnection(
    targetId: targetShape.id,
    connectionType: .straight
)

// Curved connection
ShapeConnection(
    targetId: targetShape.id,
    connectionType: .curved,
    style: ConnectionStyle(
        color: "#3498db",
        width: 2,
        style: .dashed
    )
)

// Elbow (right-angle)
ShapeConnection(
    targetId: targetShape.id,
    connectionType: .elbow,
    label: "Data Flow"
)

// Bezier curve
ShapeConnection(
    targetId: targetShape.id,
    connectionType: .bezier,
    style: ConnectionStyle(
        startMarker: .circle,
        endMarker: .arrow
    )
)
```

## Performance Tips

### Optimize SVG Output

```swift
// Use shape caching for repeated shapes
let cache = ShapeCache()
let cachedShape = cache.getOrCreate(shapeDefinition)

// Batch render multiple shapes
let shapes = loadShapes()
let optimizedSVG = renderer.batchRender(shapes)
```

### Reduce Complexity

- Limit animations to essential elements
- Use simple gradients over complex patterns
- Minimize shadow effects for better performance
- Group related shapes to reduce DOM elements

## Accessibility

Shapes automatically include:

- ARIA labels from shape labels
- Role attributes for semantic meaning
- Keyboard navigation support
- High contrast mode compatibility

## Integration Examples

### With Grid Layouts

```markdown
|[1,1] **Stage** |[1,2] **Shape** |[1,3] **Status** |
|[2,1] Input |[2,2] <shape type="circle" label="Start" color="green" /> |[2,3] Active |
|[3,1] Process |[3,2] <shape type="gear" label="Processing" animate="rotate" /> |[3,3] Running |
|[4,1] Output |[4,2] <shape type="checkmark" label="Complete" color="green" /> |[4,3] Done |
```

### With Slides

```markdown
%% System Architecture
<shape type="cloud" label="AWS" x="50" y="50" />
<shape type="arrow-down" x="75" y="100" />
<shape type="server" label="EC2" x="50" y="150" />
<shape type="arrow-bidirectional" x="150" y="175" />
<shape type="database" label="RDS" x="200" y="150" />
```

### With Icons

```markdown
<shape type="rectangle" label="Dashboard" />
<icon set="fluent" name="home" /> Dashboard

<shape type="circle" label="Settings" />
<icon set="heroicons" name="cog" /> Configuration
```

## Best Practices

1. **Use semantic shapes** - Choose shapes that convey meaning
2. **Consistent styling** - Maintain uniform colors and sizes
3. **Clear labels** - Make shapes self-explanatory
4. **Logical flow** - Arrange shapes in reading order
5. **Moderate animations** - Use sparingly for emphasis
6. **Test accessibility** - Ensure shapes work with screen readers
7. **Optimize for mobile** - Consider small screen layouts

## Troubleshooting

### Common Issues

- **Shape not rendering**: Check type is valid
- **Animation not working**: Verify browser support
- **Connection misaligned**: Check target IDs match
- **Performance issues**: Reduce shape count or complexity

## Next Steps

- Explore <doc:IconLibraries> for icon integration
- Learn about <doc:GridLayouts> for structured layouts
- See <doc:SlideSystem> for presentation diagrams
- Check <doc:Performance> for optimization strategies