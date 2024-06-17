import commonmark
import gleam/dict
import gleam/dynamic.{field, int as int_field, list, string}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None}
import simplifile
import startest.{describe, it, xit}
import startest/expect

const spec_file = "./test/commonmark_test/spec-0.29-gfm.json"

/// A list of tests involving invalid markdown that won't parse in strict mode
const invalid_tests = []

const html_tests = []

/// This is a list of expected failures
const blacklist = []

/// Run only this test
const only = None

type Test {
  Test(example: Int, markdown: String, html: String, section: String)
}

pub fn gfm_spec_tests() {
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
    "GFM spec",
    specs
      |> list.filter(fn(s) { !list.contains(html_tests, s.example) })
      |> list.group(fn(s) { s.section })
      |> dict.to_list
      |> list.map(run_section),
  )
}

fn run_section(ts: #(String, List(Test))) {
  let #(title, reversed_tests) = ts
  let tests = list.reverse(reversed_tests)

  describe(
    title,
    list.concat([
      list.map(tests, run_safe_test),
      list.map(
        tests |> list.filter(fn(t) { !list.contains(invalid_tests, t) }),
        run_strict_test,
      ),
    ]),
  )
}

fn run_safe_test(t: Test) {
  let allowed =
    only
    |> option.map(fn(n) { n == t.example })
    |> option.lazy_unwrap(fn() { !list.contains(blacklist, t.example) })

  let f = case allowed {
    True -> it
    False -> xit
  }

  f("Example " <> int.to_string(t.example), fn() {
    t.markdown
    |> commonmark.render_to_html
    |> expect.to_equal(t.html)
  })
}

fn run_strict_test(t: Test) {
  let allowed =
    only
    |> option.map(fn(n) { n == t.example })
    |> option.lazy_unwrap(fn() { !list.contains(blacklist, t.example) })

  let f = case allowed {
    True -> it
    False -> xit
  }

  f("Example " <> int.to_string(t.example) <> " (strict)", fn() {
    t.markdown
    |> commonmark.render_to_html_strict
    |> expect.to_equal(Ok(t.html))
  })
}
