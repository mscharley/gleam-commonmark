import commonmark
import commonmark/ast.{type Document, Document}

const initial_document = "Hello, Gleam!
=============

This is a handy little testing app for experimenting with CommonMark.

You can use this input to test how the [`commonmark`][hex] package for [Gleam](https://gleam.run/) processes your document.

[hex]: https://hexdocs.pm/commonmark/

```gleam extended-options
import gleam/io

fn main () {
  io.println(\"Hello world!\")
  Nil
}
```

## Examples

* List item 1
* List item 2

+ Loose list 1

+ Loose list 2

> Something someone once said
"

pub fn new() -> Model {
  let document = commonmark.parse(initial_document)
  let html = commonmark.to_html(document)

  Model(AST, initial_document, document, html)
}

pub type Tab {
  Preview
  AST
}

pub type Model {
  Model(tab: Tab, input: String, document: Document, html: String)
}
