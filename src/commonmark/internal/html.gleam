import commonmark/ast
import gleam/int
import gleam/list
import gleam/string

pub fn inline_to_html(inline: ast.InlineNode) -> String {
  case inline {
    ast.Text(contents) -> contents
    ast.HardLineBreak -> "<br />\n"
    ast.SoftLineBreak -> "\n"
    _ -> ""
  }
}

pub fn block_to_html(block: ast.BlockNode) -> String {
  case block {
    ast.Heading(level, contents) ->
      "<h"
      <> int.to_string(level)
      <> ">"
      <> { contents |> list.map(inline_to_html) |> string.join("") }
      <> "</h"
      <> int.to_string(level)
      <> ">\n"
    ast.HorizontalBreak -> "<hr />\n"
    ast.Paragraph(contents) ->
      "<p>"
      <> { contents |> list.map(inline_to_html) |> string.join("") }
      <> "</p>\n"
    _ -> ""
  }
}
