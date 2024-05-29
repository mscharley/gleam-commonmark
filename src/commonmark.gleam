import commonmark/ast
import commonmark/internal/html
import commonmark/internal/parser
import gleam/list
import gleam/regex
import gleam/string

pub fn parse(document: String) -> ast.Document {
  let assert Ok(line_splitter) = regex.from_string("\r?\n|\r\n?")

  document
  // Security check [SPEC 2.3]
  |> string.replace("\u{0000}", "\u{FFFD}")
  |> regex.split(with: line_splitter)
  |> parser.parse_blocks
  |> ast.Document
}

pub fn to_html(document: ast.Document) -> String {
  document.blocks
  |> list.map(html.block_to_html)
  |> string.join("")
}

pub fn render_to_html(document: String) -> String {
  document |> parse |> to_html
}
