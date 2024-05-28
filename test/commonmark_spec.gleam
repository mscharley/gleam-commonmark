import commonmark
import gleam/dynamic.{field, list, string}
import gleam/io
import gleam/json
import gleam/list
import simplifile

const spec_file = "./spec-0.31.2.json"

type Test {
  Test(markdown: String, html: String)
}

pub fn main() {
  io.println("Official CommonMark specs")
  let spec_decoder =
    list(dynamic.decode2(
      Test,
      field("markdown", of: string),
      field("html", of: string),
    ))

  let assert Ok(spec_json) = spec_file |> simplifile.read
  let assert Ok(specs) = spec_json |> json.decode(spec_decoder)
  specs |> list.map(run_test)
  io.println("")

  Nil
}

fn run_test(t: Test) {
  let result =
    t.markdown
    |> commonmark.parse
    |> commonmark.to_html

  case result == t.html {
    True -> io.print(".")
    False -> io.print("x")
  }
}
