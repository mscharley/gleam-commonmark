//// CommonMark implementation for Gleam!
////
//// This package provides a simple interface to parse CommonMark and common extensions
//// into either an AST for further manipulation or directly to HTML.

import commonmark/ast
import commonmark/internal/parser/block.{parse_document}
import commonmark/internal/parser/inline.{insecure_codepoints, replacement_char}
import commonmark/internal/renderer/html
import gleam/list
import gleam/regex
import gleam/result
import gleam/string

/// Parse a CommonMark document into an AST.
pub fn parse(document: String) -> ast.Document {
  let assert Ok(line_splitter) = regex.from_string("\r?\n|\r\n?")
  let assert Ok(replacement_string) =
    replacement_char
    |> string.utf_codepoint
    |> result.map(fn(x) { string.from_utf_codepoints([x]) })

  document
  // Security check [SPEC 2.3]
  |> list.fold(over: insecure_codepoints, with: fn(d, cp) {
    string.utf_codepoint(cp)
    |> result.map(fn(x) { string.from_utf_codepoints([x]) })
    |> result.map(string.replace(_, in: d, with: replacement_string))
    |> result.unwrap(d)
  })
  |> regex.split(with: line_splitter)
  |> parse_document
}

/// Render an AST into a HTML string.
///
/// This version follows the advice in the CommonMark spec to silently resolve errors.
pub fn to_html(document: ast.Document) -> String {
  document.blocks
  |> list.map(html.block_to_html_safe(_, document.references, False))
  |> string.join("")
}

/// Render an AST into a HTML string.
///
/// This uses a more strict rendered that won't attempt to fix issues in the document.
pub fn to_html_strict(document: ast.Document) -> Result(String, ast.RenderError) {
  document.blocks
  |> list.map(html.block_to_html(_, document.references, False))
  |> result.all
  |> result.map(string.join(_, ""))
}

/// Render a CommonMark document into a HTML string.
///
/// This version follows the advice in the CommonMark spec to silently resolve errors.
pub fn render_to_html(document: String) -> String {
  document |> parse |> to_html
}

/// Render a CommonMark document into a HTML string.
///
/// This uses a more strict rendering that won't attempt to fix issues in the document.
pub fn render_to_html_strict(
  document: String,
) -> Result(String, ast.RenderError) {
  document |> parse |> to_html_strict
}
