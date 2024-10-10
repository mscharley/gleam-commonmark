//// HTML renderer for CommonMark.
////
//// This is the built-in renderer that can render to a HTML string. This is the most
//// compliant option as it is directly tested against the specs with no regard to how
//// you would actually use the output or style it.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark.{parse}
import commonmark/ast
import commonmark/internal/renderer/html
import gleam/list
import gleam/result
import gleam/string

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
