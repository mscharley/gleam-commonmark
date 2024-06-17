import commonmark
import commonmark/ast.{type Document, Document}
import lustre/effect

const initial_document = "Hello, Gleam! 🩷
================

This is a handy little testing app for experimenting with CommonMark.

You can use this input to test how the [`commonmark`][hex] package for [Gleam](https://gleam.run/) processes your document.

You can find the library powering this demo on [Github][commonmark-github], along with the [code for this demo][demo-github].

[hex]: https://hexdocs.pm/commonmark/
[commonmark-github]: https://github.com/mscharley/gleam-commonmark
[demo-github]: https://github.com/mscharley/gleam-commonmark/tree/main/demo

```gleam extended-options
import gleam/io

fn main () {
  io.println(\"🚀 Hello world!\")
  Nil
}
```

 --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

## Examples

* List item 1
* List item 2

+ Loose list 1

+ Loose list 2

> Something someone once said

Math is fake: [1, 2, 3] &Element; &Zopf;
"

pub fn init(_flags) -> #(Model, effect.Effect(a)) {
  let document = commonmark.parse(initial_document)
  let html = commonmark.to_html(document)

  #(Model(Preview, initial_document, document, html), effect.none())
}

pub type Tab {
  Preview
  AST
}

pub type Model {
  Model(tab: Tab, input: String, document: Document, html: String)
}
