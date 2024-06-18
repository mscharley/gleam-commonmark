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
import gleam/io
@target(erlang)
import gleam/json
@target(erlang)
import gleam/list
@target(erlang)
import gleam/order
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

import gleam/bit_array
import gleam/list
import gleam/string

pub fn match_html_entity(input: List(String)) {
  case input |> list.take(40) |> string.join(\"\") {
"

@target(erlang)
const entities_footer = "
    _ -> Error(Nil)
  }
}
"

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
fn is_relevant(entity: #(String, List(Int))) -> List(#(List(String), List(Int))) {
  case string.ends_with(entity.0, ";"), entity {
    True, #("&" <> rest, mapping) -> [#(string.to_graphemes(rest), mapping)]
    _, _ -> []
  }
}

@target(erlang)
fn format_lines(line) {
  case line {
    #(graphemes, mapping) ->
      "    \""
      <> string.join(graphemes, "")
      <> "\" <> _ -> Ok(#(list.drop(input, "
      <> { list.length(graphemes) |> int.to_string }
      <> "), \""
      <> {
        mapping
        |> list.map(fn(cp) { "\\u{" <> int.to_base16(cp) <> "}" })
        |> string.join("")
      }
      <> "\"))"
  }
}

@target(erlang)
pub fn main() {
  let entities = fetch_entities() |> list.flat_map(is_relevant)
  let assert Ok(max_length) =
    entities
    |> list.map(pair.first)
    |> list.map(list.length)
    |> list.sort(order.reverse(int.compare))
    |> list.first
  let case_statement = entities |> list.map(format_lines) |> string.join("\n")
  io.debug(max_length)

  let assert Ok(_) =
    simplifile.write(
      to: output_file,
      contents: entities_header <> case_statement <> entities_footer,
    )

  Nil
}
