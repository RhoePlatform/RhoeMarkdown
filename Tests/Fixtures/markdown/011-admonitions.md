# Admonitions Test Suite

## Basic Admonitions

!!! note
This is a simple note admonition.
!!!

!!! warning
This is a warning message that should catch attention.
!!!

!!! danger
This is a danger/error admonition for critical information.
!!!

!!! tip
This is a helpful tip for users.
!!!

!!! info
This is an informational admonition with additional context.
!!!

## Custom Titles

!!! note "Custom Note Title"
This note has a custom title instead of the default.
!!!

!!! warning "⚠️ Important Warning"
Custom titles can include emojis and special characters.
!!!

## Collapsible Admonitions

!!!? note
This is a collapsible note that starts closed.
!!!

!!!?+ warning "Expanded by Default"
This collapsible admonition starts in an expanded state.
!!!

## Nested Content in Admonitions

!!! example "Complex Example"
Admonitions can contain multiple block elements:

- Lists work fine
- Including nested items
  - Like this one

```python
# Code blocks are supported
def example():
    return "Hello from admonition!"
```

> Even blockquotes work inside admonitions

And **formatted** *text* with `inline code`.
!!!

## Multiple Paragraphs

!!! info "Multi-paragraph Info"
This is the first paragraph of the admonition.

This is the second paragraph, separated by a blank line.

And a third paragraph with a [link](https://example.com).
!!!

## Nested Admonitions

!!! warning "Outer Warning"
This is the outer admonition.

!!! danger "Nested Danger"
This is a nested admonition inside another one.

!!! tip "Deeply Nested"
Admonitions can be nested multiple levels deep.
!!!
!!!
!!!

## Admonitions with Attributes

!!! note {#special-note .custom-class data-priority="high"}
This admonition has Pandoc-style attributes.
!!!

## Edge Cases

!!! 
Admonition without a type (should default to note).
!!!

!!! note ""
Admonition with empty title.
!!!

!!! note "Title Only"
!!!

!!! success "Success Message"
✅ Operation completed successfully!
!!!

!!! question "FAQ"
What happens when we use a question type?
!!!

!!! quote "Famous Quote"
> "The only way to do great work is to love what you do."
> — Steve Jobs
!!!

## Combined Features

!!!?+ example "Advanced Collapsible Example" {.highlight #advanced-example}
This combines:
- Collapsible state (expanded)
- Custom title
- Pandoc attributes
- Complex content

```javascript
// With syntax highlighting
const greeting = (name) => {
    return `Hello, ${name}!`;
};
```

| Feature | Support |
|---------|---------|
| Nesting | ✅ Yes  |
| Code    | ✅ Yes  |
| Tables  | ✅ Yes  |
!!!