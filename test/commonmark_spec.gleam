import commonmark
import gleam/dict
import gleam/dynamic.{field, int as int_field, list, string}
import gleam/int
import gleam/json
import gleam/list
import simplifile
import startest.{describe, it}
import startest/expect

const spec_file = "./spec-0.31.2.json"

type Test {
  Test(example: Int, markdown: String, html: String, section: String)
}

pub fn commonmark_spec_tests() {
  let spec_decoder =
    list(dynamic.decode4(
      Test,
      field("example", of: int_field),
      field("markdown", of: string),
      field("html", of: string),
      field("section", of: string),
    ))

  let assert Ok(spec_json) = spec_file |> simplifile.read
  let assert Ok(specs) = spec_json |> json.decode(spec_decoder)

  describe(
    "CommonMark spec",
    specs
      |> list.group(fn(s) { s.section })
      |> dict.to_list
      |> list.map(run_section),
  )
}

fn run_section(ts: #(String, List(Test))) {
  describe(
    ts.0,
    ts.1
      |> list.reverse
      |> list.map(run_test),
  )
}

fn run_test(t: Test) {
  it("Example " <> int.to_string(t.example), fn() {
    t.markdown
    |> commonmark.parse
    |> commonmark.to_html
    |> expect.to_equal(t.html)
  })
}
