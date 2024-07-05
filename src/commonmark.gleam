//// CommonMark implementation for Gleam!
////
//// This package provides a simple interface to parse CommonMark and common extensions
//// into an AST.
////
//// There are multiple renderers available:
////
//// * HTML - via `commonmark/html` included in the `commonmark` package.
//// * CommonMark - via `commonmark/commonmark` included in the `commonmark` package.

import commonmark/ast
import commonmark/internal/definitions.{insecure_codepoints, replacement_char}
import commonmark/internal/parser/block.{parse_document}
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
