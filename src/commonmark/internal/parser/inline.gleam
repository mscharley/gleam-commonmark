import commonmark/ast
import commonmark/internal/parser/helpers.{parse_autolink}
import gleam/list
import gleam/string

type InlineState {
  TextAccumulator(List(String))
  AutolinkAccumulator(List(String))
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
      [
        ast.PlainText(ts |> list.reverse |> string.join("") |> string.trim),
        ..acc
      ]
      |> list.reverse
    TextAccumulator(ts), [" ", " ", "\n", ..gs]
    | TextAccumulator(ts), ["\\", "\n", ..gs]
    ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.HardLineBreak,
        ast.PlainText(ts |> list.reverse |> string.join("") |> string.trim),
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
        ast.PlainText(ts |> list.reverse |> string.join("") |> string.trim),
        ..acc
      ])
    AutolinkAccumulator(ts), ["\n", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.SoftLineBreak,
        ast.PlainText(list.reverse(["<", ..ts]) |> string.join("")),
        ..acc
      ])
    TextAccumulator(ts), ["<", ..gs] ->
      do_parse_text(gs, AutolinkAccumulator([]), [
        ast.PlainText(ts |> list.reverse |> string.join("")),
        ..acc
      ])
    AutolinkAccumulator(ts), ["\t" as space, ..gs]
    | AutolinkAccumulator(ts), [" " as space, ..gs]
    ->
      do_parse_text(gs, TextAccumulator([space, ..list.append(ts, ["<"])]), acc)
    AutolinkAccumulator(ts), [">", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        parse_autolink(ts |> list.reverse |> string.join("")),
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
