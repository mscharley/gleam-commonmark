import commonmark/ast.{type Document, Document}
import gleam/dict
import lustre/effect

pub const test_document = "Hello, Gleam! 🩷
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

pub fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  #(
    Model(Preview, "", ast.Document([], dict.from_list([])), ""),
    effect.from(fn(dispatch) { dispatch(UpdateInput(test_document)) }),
  )
}

pub type Tab {
  Preview
  AST
}

pub type Model {
  Model(tab: Tab, input: String, document: Document, html: String)
}

pub type Msg {
  SetTab(Tab)
  UpdateInput(String)
}
