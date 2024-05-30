//// CommonMark implementation for Gleam!
////
//// This package provides a simple interface to parse CommonMark and common extensions
//// into either an AST for further manipulation or directly to HTML.

import commonmark/ast
import commonmark/internal/html
import commonmark/internal/parser
import gleam/dict
import gleam/list
import gleam/regex
import gleam/string

/// Parse a CommonMark document into an AST.
pub fn parse(document: String) -> ast.Document {
  let assert Ok(line_splitter) = regex.from_string("\r?\n|\r\n?")

  document
  // Security check [SPEC 2.3]
  |> string.replace("\u{0000}", "\u{FFFD}")
  |> regex.split(with: line_splitter)
  |> parser.parse_blocks
  |> list.flat_map(parser.parse_block_state)
  |> ast.Document(dict.new())
}

/// Render an AST into a HTML string.
///
/// This version follows the advice in the CommonMark spec to silently resolve errors.
pub fn to_html(document: ast.Document) -> String {
  document.blocks
  |> list.map(html.block_to_html)
  |> string.join("")
}

/// Render an AST into a HTML string.
/// 
/// This uses a more strict rendered that won't attempt to fix issues in the document.
pub fn to_html_strict(document: ast.Document) -> Result(String, Nil) {
  document.blocks
  |> list.map(html.block_to_html)
  |> string.join("")
  |> Ok
}

/// Render a CommonMark document into a HTML string.
///
/// This version follows the advice in the CommonMark spec to silently resolve errors.
pub fn render_to_html(document: String) -> String {
  document |> parse |> to_html
}

/// Render a CommonMark document into a HTML string.
/// 
/// This uses a more strict rendered that won't attempt to fix issues in the document.
pub fn render_to_html_strict(document: String) -> Result(String, Nil) {
  document |> parse |> to_html_strict
}
