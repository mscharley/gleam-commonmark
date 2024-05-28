import commonmark/ast
import gleam/list
import gleam/string

pub fn parse_text(text: String) -> List(ast.InlineNode) {
  [ast.Text(text)]
}

pub fn parse_paragraph(lines: List(String)) -> ast.BlockNode {
  lines
  |> string.join("\n")
  |> parse_text
  |> ast.Paragraph
}

pub fn parse_blocks(lines: List(String)) -> List(ast.BlockNode) {
  lines
  |> list.chunk(fn(line) { line |> string.trim == "" })
  |> list.filter(fn(line) { line != [""] })
  |> list.map(parse_paragraph)
}
