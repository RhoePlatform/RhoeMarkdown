# Code Tests

## Inline Code

This is `inline code` in a sentence.

Use the `printf()` function.

``Code with `backticks` inside``

`Multiple words in code`

## Code Blocks

### Indented Code Block

    function hello() {
        console.log("Hello, World!");
    }

### Fenced Code Block

```
function hello() {
    console.log("Hello, World!");
}
```

### With Language

```javascript
function hello() {
    console.log("Hello, World!");
}
```

```python
def hello():
    print("Hello, World!")
```

```swift
func hello() {
    print("Hello, World!")
}
```

### With Tilde Fences

~~~
Code block with tildes
~~~

~~~ruby
puts "Hello, World!"
~~~

## Edge Cases

Empty code block:
```
```

Code block with special characters:
```html
<div class="test">
    <p>Hello & "World"</p>
</div>
```