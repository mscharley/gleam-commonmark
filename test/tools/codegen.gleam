import gleam/dict
import gleam/dynamic
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
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

pub fn match_html_entity(input: List(String)) {
  case input {
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
fn fetch_entities() {
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
  |> list.take(50)
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
      "    ["
      <> {
        graphemes |> list.map(fn(g) { "\"" <> g <> "\"" }) |> string.join(", ")
      }
      <> ", ..rest] -> Ok(#(rest, \""
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
  let case_statement =
    fetch_entities()
    |> list.flat_map(is_relevant)
    |> list.map(format_lines)
    |> string.join("\n")

  let assert Ok(_) =
    simplifile.write(
      to: output_file,
      contents: entities_header <> case_statement <> entities_footer,
    )

  Nil
}
