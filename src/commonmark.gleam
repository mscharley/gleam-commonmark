import commonmark/ast
import gleam/list
import gleam/string

fn parse_paragraph(lines: List(String)) -> ast.Node {
  ast.Paragraph(string.join(lines, "\n"))
}

pub fn parse(document: String) -> ast.Node {
  document
  // Security check [SPEC 2.3]
  |> string.replace("\u{0000}", "\u{FFFD}")
  |> string.split("\n")
  |> list.chunk(fn(line) { line |> string.trim == "" })
  |> list.filter(fn(line) { line != [""] })
  |> list.map(parse_paragraph)
  |> ast.Document
}
