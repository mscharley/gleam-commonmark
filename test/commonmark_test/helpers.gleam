// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark.{parse}
import commonmark/commonmark as renderer
import commonmark/html
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import simplifile
import startest.{describe, it, xit}
import startest/expect

pub type Test {
  Test(example: Int, markdown: String, html: String, section: String)
}

pub fn parse_json_spec(spec_path: String) -> List(Test) {
  let spec_decoder =
    decode.list({
      use example <- decode.field("example", decode.int)
      use markdown <- decode.field("markdown", decode.string)
      use html <- decode.field("html", decode.string)
      use section <- decode.field("section", decode.string)
      decode.success(Test(example:, markdown:, html:, section:))
    })

  let assert Ok(spec_json) = spec_path |> simplifile.read
  let assert Ok(specs) = spec_json |> json.parse(spec_decoder)

  specs
}

pub fn run_spec(
  spec: List(Test),
  blacklist: List(Int),
  invalid_tests: List(Int),
  ignore_roundtrip: List(Int),
  only: Option(Int),
) {
  spec
  |> list.group(fn(s) { s.section })
  |> dict.to_list
  |> list.map(run_section(_, blacklist, invalid_tests, ignore_roundtrip, only))
}

fn run_section(
  ts: #(String, List(Test)),
  blacklist: List(Int),
  invalid_tests: List(Int),
  ignore_roundtrip: List(Int),
  only: Option(Int),
) {
  let #(title, reversed_tests) = ts
  let tests = list.reverse(reversed_tests)

  describe(
    title,
    list.flatten([
      list.map(tests, run_safe_test(_, blacklist, only)),
      list.map(
        tests
          |> list.filter(fn(t) { !list.contains(ignore_roundtrip, t.example) }),
        run_roundtrip_test(_, blacklist, only),
      ),
      list.map(
        tests |> list.filter(fn(t) { !list.contains(invalid_tests, t.example) }),
        run_strict_test(_, blacklist, only),
      ),
    ]),
  )
}

fn run_safe_test(t: Test, blacklist: List(Int), only: Option(Int)) {
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
    |> html.render_to_html
    |> expect.to_equal(t.html)
  })
}

fn run_roundtrip_test(t: Test, blacklist: List(Int), only: Option(Int)) {
  let allowed =
    only
    |> option.map(fn(n) { n == t.example })
    |> option.lazy_unwrap(fn() { !list.contains(blacklist, t.example) })

  let f = case allowed {
    True -> it
    False -> xit
  }

  f("Example " <> int.to_string(t.example) <> " (roundtrip)", fn() {
    let ast = parse(t.markdown)

    ast
    |> renderer.to_commonmark
    |> parse
    |> expect.to_equal(ast)
  })
}

fn run_strict_test(t: Test, blacklist: List(Int), only: Option(Int)) {
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
    |> html.render_to_html_strict
    |> expect.to_equal(Ok(t.html))
  })
}
