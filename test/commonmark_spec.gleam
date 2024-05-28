import commonmark
import gleam/dict
import gleam/dynamic.{field, list, string}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import simplifile

const spec_file = "./spec-0.31.2.json"

const red = "\u{1B}[0;31m"

const green = "\u{1B}[0;32m"

const reset = "\u{1B}[0m"

type Test {
  Test(markdown: String, html: String, section: String)
}

pub fn main() {
  io.println("Official CommonMark specs")
  io.println("-------------------------")
  io.println("")

  let spec_decoder =
    list(dynamic.decode3(
      Test,
      field("markdown", of: string),
      field("html", of: string),
      field("section", of: string),
    ))

  let assert Ok(spec_json) = spec_file |> simplifile.read
  let assert Ok(specs) = spec_json |> json.decode(spec_decoder)

  let #(pass, fail) =
    specs
    |> list.group(fn(s) { s.section })
    |> dict.to_list
    |> list.map(run_section)
    |> list.fold(from: #(0, 0), with: fn(acc, v) { #(acc.0 + v.0, acc.1 + v.1) })

  io.println("Overall:")
  summarise_tests(pass, fail)

  Nil
}

fn summarise_tests(pass: Int, fail: Int) {
  io.println(
    green
    <> int.to_string(pass + fail)
    <> " tests, "
    <> int.to_string(fail)
    <> " failures"
    <> reset
    <> "\n",
  )
}

fn run_section(ts: #(String, List(Test))) {
  io.println(ts.0)

  let #(pass, fail) =
    ts.1
    |> list.reverse
    |> list.map(run_test)
    |> list.fold(from: #(0, 0), with: fn(acc, v) {
      case v {
        Ok(_) -> #(acc.0 + 1, acc.1)
        Error(_) -> #(acc.0, acc.1 + 1)
      }
    })

  io.println("")
  summarise_tests(pass, fail)

  #(pass, fail)
}

fn run_test(t: Test) {
  let result =
    t.markdown
    |> commonmark.parse
    |> commonmark.to_html

  case result == t.html {
    True -> {
      io.print(green <> "." <> reset)
      Ok(Nil)
    }
    False -> {
      io.print(red <> "F" <> reset)
      Error(Nil)
    }
  }
}
