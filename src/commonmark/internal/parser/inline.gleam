import commonmark/ast
import commonmark/internal/parser/entity
import commonmark/internal/parser/helpers.{parse_autolink}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/regex
import gleam/result
import gleam/string

type InlineState {
  TextAccumulator(List(String))
  AutolinkAccumulator(List(String))
}

const ascii_punctuation = [
  "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/",
  ":", ";", "<", "=", ">", "?", "@", "[", "]", "\\", "^", "_", "`", "{", "|",
  "}", "~",
]

fn replace_null_byte(n) {
  case n {
    0 -> 0xfffd
    _ -> n
  }
}

fn finalise_plain_text(
  graphemes: List(String),
  trim_end: Bool,
  trim_start: Bool,
) {
  graphemes
  |> list.drop_while(fn(g) { trim_end && { g == " " || g == "\t" } })
  |> list.reverse
  |> list.drop_while(fn(g) { trim_start && { g == " " || g == "\t" } })
  |> string.join("")
}

fn translate_numerical_entity(
  codepoint: Result(Int, Nil),
  rest: List(String),
) -> Result(#(List(String), String), Nil) {
  codepoint
  |> result.map(replace_null_byte)
  |> result.try(string.utf_codepoint)
  |> result.map(fn(cp) { #(rest, string.from_utf_codepoints([cp])) })
}

fn match_entity(input: List(String)) -> Result(#(List(String), String), Nil) {
  entity.match_html_entity(input)
  |> result.try_recover(fn(_) {
    let assert Ok(dec_entity) = regex.from_string("^#([0-9]{1,7});")
    let assert Ok(hex_entity) = regex.from_string("^#[xX]([0-9a-fA-F]{1,6});")
    let potential = list.take(input, 9) |> string.join("")

    case regex.scan(dec_entity, potential), regex.scan(hex_entity, potential) {
      [regex.Match(full, [Some(n)])], _ ->
        n
        |> int.parse
        |> translate_numerical_entity(list.drop(input, string.length(full)))
      _, [regex.Match(full, [Some(n)])] ->
        n
        |> int.base_parse(16)
        |> translate_numerical_entity(list.drop(input, string.length(full)))
      _, _ -> Error(Nil)
    }
  })
}

fn do_parse_text(
  text: List(String),
  state: InlineState,
  acc: List(ast.InlineNode),
) -> List(ast.InlineNode) {
  case state, text {
    AutolinkAccumulator(ts), [] -> [
      ast.PlainText(["<", ..list.reverse(ts)] |> string.join("")),
      ..acc
    ]
    TextAccumulator(ts), [] ->
      [ast.PlainText(finalise_plain_text(ts, True, True)), ..acc]
      |> list.reverse
    TextAccumulator(ts), [" ", " ", "\n", ..gs]
    | TextAccumulator(ts), ["\\", "\n", ..gs]
    ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.HardLineBreak,
        ast.PlainText(finalise_plain_text(ts, True, True)),
        ..acc
      ])
    AutolinkAccumulator(ts), [" ", " ", "\n", ..gs]
    | AutolinkAccumulator(ts), ["\\", "\n", ..gs]
    ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.HardLineBreak,
        ast.PlainText(list.reverse(["<", ..ts]) |> string.join("")),
        ..acc
      ])
    TextAccumulator(ts), ["\n", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.SoftLineBreak,
        ast.PlainText(finalise_plain_text(ts, True, True)),
        ..acc
      ])
    AutolinkAccumulator(ts), ["\n", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.SoftLineBreak,
        ast.PlainText(list.reverse(["<", ..ts]) |> string.join("")),
        ..acc
      ])
    TextAccumulator(ts), ["\\", g, ..gs] ->
      case list.contains(ascii_punctuation, g) {
        True -> do_parse_text(gs, TextAccumulator([g, ..ts]), acc)
        False -> do_parse_text(gs, TextAccumulator([g, "\\", ..ts]), acc)
      }
    TextAccumulator(ts), ["&", ..gs] -> {
      case match_entity(gs) {
        Ok(#(rest, replacement)) ->
          do_parse_text(rest, TextAccumulator([replacement, ..ts]), acc)
        Error(_) -> do_parse_text(gs, TextAccumulator(["&", ..ts]), acc)
      }
    }
    TextAccumulator(ts), ["<", ..gs] ->
      do_parse_text(gs, AutolinkAccumulator([]), [
        ast.PlainText(finalise_plain_text(ts, False, False)),
        ..acc
      ])
    AutolinkAccumulator(ts), ["\t" as space, ..gs]
    | AutolinkAccumulator(ts), [" " as space, ..gs]
    ->
      do_parse_text(gs, TextAccumulator([space, ..list.append(ts, ["<"])]), acc)
    AutolinkAccumulator(ts), [">", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        parse_autolink(finalise_plain_text(ts, False, False)),
        ..acc
      ])
    AutolinkAccumulator(ts), [g, ..gs] ->
      do_parse_text(gs, AutolinkAccumulator([g, ..ts]), acc)
    TextAccumulator(ts), [g, ..gs] ->
      do_parse_text(gs, TextAccumulator([g, ..ts]), acc)
  }
}

pub fn parse_text(text: String) -> List(ast.InlineNode) {
  text |> string.to_graphemes |> do_parse_text(TextAccumulator([]), [])
}
