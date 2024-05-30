# commonmark

[![Package Version](https://img.shields.io/hexpm/v/commonmark)](https://hex.pm/packages/commonmark)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/commonmark/)

```sh
gleam add commonmark
```
```gleam
import commonmark
import gleam/io

pub fn main() {
  "# Hello, Gleam!

This is a test."
  |> commonmark.render_to_html
  |> io.println
  // -> "<h1>Hello, Gleam!</h1>\n<p>This is a test.</p>\n"
}
```

Further documentation can be found at <https://hexdocs.pm/commonmark>.

## Syntax support

🚧 This package is still heavily under construction 🚧

✅ - Completed | 🚧 - In Progress | ❌ - Unsupported

### CommonMark

The current version of CommonMark targetted is [0.31.2][commonmark].

* ✅ Thematic breaks
* ✅ ATX headings
* ✅ Setext headings
* ❌ Indented code blocks
* 🚧 Fenced code blocks
* ❌ Link reference definitions
* ✅ Paragraphs
* ❌ Block quotes
* ❌ Ordered lists
* ❌ Unordered lists
* ❌ Code spans
* ❌ Emphasis and strong emphasis
* ❌ Links
* ❌ Images
* ❌ Autolinks
* ✅ Hard line breaks
* ✅ Soft line breaks

Raw HTML features will be tackled last as the potential security issues around this need to be considered.

* ❌ HTML blocks
* ❌ Inline HTML

[commonmark]: https://spec.commonmark.org/0.31.2/

### Github Flavoured Markdown

The current version of GFM targetted is [0.29-gfm][gfm].

* ❌ Tables
* ❌ Strikethrough

[gfm]: https://github.github.com/gfm/

## Development

```sh
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

