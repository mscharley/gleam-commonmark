# commonmark

[![Package Version](https://img.shields.io/hexpm/v/commonmark)](https://hex.pm/packages/commonmark)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/commonmark/)
![Erlang-compatible](https://img.shields.io/badge/target-erlang-b83998)
![JavaScript-compatible](https://img.shields.io/badge/target-javascript-f1e05a)

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

[You can view this README as an AST here.][readme-ast]

There is also an [interactive demo][demo] which you can use to test how this library interacts with your documents.

[readme-ast]: https://github.com/mscharley/gleam-commonmark/tree/main/birdie_snapshots/common_mark_readme.accepted
[demo]: https://mscharley.github.io/gleam-commonmark/

## Syntax support

> [!WARNING]
> 🚧 This package is still heavily under construction 🚧

### Legend

* ✅ - Completed
* 🚧 - In Progress
* ❌ - Unsupported

### CommonMark

The current version of CommonMark targetted is [0.31.2][commonmark].

* ✅ Thematic breaks
* ✅ ATX headings
* ✅ Setext headings
* ✅ Indented code blocks
* ✅ Fenced code blocks
* ❌ Link reference definitions
* ✅ Paragraphs
* ✅ Block quotes
* 🚧 Ordered lists
* 🚧 Unordered lists
* ✅ Code spans
* 🚧 Emphasis and strong emphasis
* 🚧 Links
* 🚧 Images
* ✅ Autolinks
* ✅ Hard line breaks
* ✅ Soft line breaks

Raw HTML features will be tackled last as the potential security issues around this need to be considered.

* ❌ HTML blocks
* ❌ Inline HTML

[commonmark]: https://spec.commonmark.org/0.31.2/

### Github Flavoured Markdown

The current version of GFM targetted is [0.29-gfm][gfm].

* ❌ Tables
* ✅ Strikethrough

[gfm]: https://github.github.com/gfm/

### Other extensions

* ❌ [Github alerts][github-alert]

[github-alert]: https://github.com/orgs/community/discussions/16925

## Development

```sh
gleam test              # Run the tests
gleam shell             # Run an Erlang shell
```

### Tools

```sh
cd tools/
gleam run -m benchmark  # Run the benchmarks
gleam run -m codegen    # Run the codegen tasks (these are committed in the repo)
```
