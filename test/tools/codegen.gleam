@target(erlang)
import gleam/dict
@target(erlang)
import gleam/dynamic
@target(erlang)
import gleam/http/request
@target(erlang)
import gleam/http/response
@target(erlang)
import gleam/httpc
@target(erlang)
import gleam/int
@target(erlang)
import gleam/json
@target(erlang)
import gleam/list
@target(erlang)
import gleam/pair
@target(erlang)
import gleam/result
@target(erlang)
import gleam/string
@target(erlang)
import gleam/uri
@target(erlang)
import simplifile

@target(erlang)
const entities_list_url = "https://html.spec.whatwg.org/entities.json"

@target(erlang)
const output_file = "./src/commonmark/internal/parser/entity.gleam"

@target(erlang)
const entities_header = "////
//// WARNING: This file is autogenerated. Modifications to this file will not persist.
////
//// You can run `gleam run -m codegen` to update it if you think there are entities missing.
////
//// Data sourced from https://html.spec.whatwg.org/entities.json
////

import gleam/list
import gleam/string
"

@target(erlang)
const entities_footer = ""

@target(erlang)
type EntityEntry {
  EntityEntry(characters: String, codepoints: List(Int))
}

@target(erlang)
fn fetch_entities() -> List(#(String, List(Int))) {
  let assert Ok(response.Response(_, _, body)) =
    entities_list_url
    |> uri.parse
    |> result.try(request.from_uri)
    |> result.map_error(dynamic.from)
    |> result.try(httpc.send)

  let entity_decoder =
    dynamic.dict(
      of: dynamic.string,
      to: dynamic.decode2(
        EntityEntry,
        dynamic.field("characters", dynamic.string),
        dynamic.field("codepoints", dynamic.list(dynamic.int)),
      ),
    )

  let assert Ok(results) = json.decode(from: body, using: entity_decoder)

  results
  |> dict.map_values(fn(_, x) { x.codepoints })
  |> dict.to_list
}

@target(erlang)
fn is_relevant(entity: #(String, List(Int))) -> List(#(String, List(Int))) {
  case string.ends_with(entity.0, ";"), entity {
    True, #("&" <> rest, mapping) -> [#(rest, mapping)]
    _, _ -> []
  }
}

@target(erlang)
fn format_lines(line) {
  case line {
    #(graphemes, mapping) ->
      "    \""
      <> graphemes
      <> "\" <> _ -> Ok(#(list.drop(input, "
      <> { string.length(graphemes) |> int.to_string }
      <> "), \""
      <> graphemes
      <> "\", \""
      <> {
        mapping
        |> list.map(fn(cp) { "\\u{" <> int.to_base16(cp) <> "}" })
        |> string.join("")
      }
      <> "\"))"
  }
}

@target(erlang)
pub fn safe_prefix(prefix: String) {
  let lcase = string.lowercase(prefix)
  case prefix == lcase {
    True -> prefix
    False -> "upper_" <> lcase
  }
}

@target(erlang)
pub fn main() {
  let entities =
    fetch_entities()
    |> list.flat_map(is_relevant)
    |> list.group(fn(x) {
      let assert Ok(c) = string.first(x.0)
      c
    })
    |> dict.to_list
  let functions =
    entities
    |> list.sort(fn(l, r) { string.compare(l.0, r.0) })
    |> list.map(fn(pair) {
      let #(prefix, es) = pair
      let case_statements =
        es
        |> list.sort(fn(l, r) { string.compare(l.0, r.0) })
        |> list.map(format_lines)
        |> string.join("\n")

      #(
        prefix,
        "\nfn match_"
          <> safe_prefix(prefix)
          <> "(entity: String, input: List(String)) {\n  case entity {\n"
          <> case_statements
          <> "\n    _ -> Error(Nil)\n  }\n}\n",
      )
    })

  let entry = "
pub fn match_html_entity(input: List(String)) -> Result(#(List(String), String, String), Nil) {
  let entity = input |> list.take(40) |> string.join(\"\")
  case list.first(input) {
" <> {
      functions
      |> list.map(pair.first)
      |> list.map(fn(s) {
        "    Ok(\"" <> s <> "\") -> match_" <> safe_prefix(s)
      })
      |> string.join("\n")
    } <> "
    _ -> fn(_, _) { Error(Nil) }
  }(entity, input)
}
"

  let contents =
    entities_header
    <> entry
    <> { functions |> list.map(pair.second) |> string.join("") }
    <> entities_footer

  let assert Ok(_) = simplifile.write(to: output_file, contents: contents)

  Nil
}
